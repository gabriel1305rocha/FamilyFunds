import { Router } from 'express';
import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import { query, withTransaction } from '../db/pool.js';
import { HttpError } from '../middleware/errors.js';
import { assertFamilyRefs } from '../services/refs.js';
import { addMonthsToDate, monthRange } from '../services/dates.js';
import { round } from '../services/balances.js';
import { idParam } from './crud.js';

const router = Router();

const REFS = { account_id: 'accounts', transfer_account_id: 'accounts', member_id: 'members', category_id: 'categories' };

const baseSchema = z.object({
  type: z.enum(['income', 'expense', 'transfer']),
  account_id: z.number().int().positive(),
  transfer_account_id: z.number().int().positive().nullish(),
  member_id: z.number().int().positive().nullish(),
  category_id: z.number().int().positive().nullish(),
  amount: z.number().finite().positive().max(1e11),
  description: z.string().trim().max(200).optional(),
  date: z.iso.date(),
});

const createSchema = baseSchema
  .extend({ installments: z.number().int().min(1).max(72).optional() })
  .refine((t) => t.type !== 'transfer' || t.transfer_account_id, {
    message: 'Transferências precisam de uma conta de destino',
    path: ['transfer_account_id'],
  })
  .refine((t) => t.type === 'transfer' || !t.transfer_account_id, {
    message: 'Conta de destino só é usada em transferências',
    path: ['transfer_account_id'],
  })
  .refine((t) => !t.installments || t.installments === 1 || t.type === 'expense', {
    message: 'Parcelamento só é permitido para despesas',
    path: ['installments'],
  });

const listSchema = z.object({
  month: z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/).optional(),
  from: z.iso.date().optional(),
  to: z.iso.date().optional(),
  type: z.enum(['income', 'expense', 'transfer']).optional(),
  account_id: z.coerce.number().int().positive().optional(),
  member_id: z.coerce.number().int().positive().optional(),
  category_id: z.coerce.number().int().positive().optional(),
  search: z.string().trim().max(100).optional(),
  limit: z.coerce.number().int().min(1).max(500).default(100),
  offset: z.coerce.number().int().min(0).default(0),
});

const SELECT = `
  SELECT t.*, a.name AS account_name, a.type AS account_type, ta.name AS transfer_account_name,
         c.name AS category_name, c.icon AS category_icon, c.color AS category_color,
         m.name AS member_name, m.color AS member_color
    FROM transactions t
    JOIN accounts a ON a.id = t.account_id
    LEFT JOIN accounts ta ON ta.id = t.transfer_account_id
    LEFT JOIN categories c ON c.id = t.category_id
    LEFT JOIN members m ON m.id = t.member_id`;

router.get('/', async (req, res) => {
  const f = listSchema.parse(req.query);
  const where = ['t.family_id = $1'];
  const params = [req.user.familyId];
  const add = (sql, value) => {
    params.push(value);
    where.push(sql.replace('?', `$${params.length}`));
  };
  if (f.month) {
    const r = monthRange(f.month);
    add('t.date >= ?', r.start);
    add('t.date <= ?', r.end);
  }
  if (f.from) add('t.date >= ?', f.from);
  if (f.to) add('t.date <= ?', f.to);
  if (f.type) add('t.type = ?', f.type);
  if (f.account_id) add('? IN (t.account_id, t.transfer_account_id)', f.account_id);
  if (f.member_id) add('t.member_id = ?', f.member_id);
  if (f.category_id) add('t.category_id = ?', f.category_id);
  if (f.search) add('t.description ILIKE ?', `%${f.search.replace(/[%_\\]/g, '\\$&')}%`);

  params.push(f.limit, f.offset);
  const { rows } = await query(
    `${SELECT} WHERE ${where.join(' AND ')}
     ORDER BY t.date DESC, t.id DESC LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params,
  );
  res.json(rows);
});

router.get('/:id', async (req, res) => {
  const { rows } = await query(`${SELECT} WHERE t.id = $1 AND t.family_id = $2`, [
    idParam.parse(req.params.id),
    req.user.familyId,
  ]);
  if (!rows.length) throw new HttpError(404, 'Lançamento não encontrado');
  res.json(rows[0]);
});

async function assertCategoryKind(familyId, categoryId, type) {
  if (!categoryId) return;
  if (type === 'transfer') throw new HttpError(400, 'Transferências não usam categoria');
  const { rows } = await query('SELECT kind FROM categories WHERE id = $1 AND family_id = $2', [categoryId, familyId]);
  if (rows[0] && rows[0].kind !== type) {
    throw new HttpError(400, `A categoria escolhida é de ${rows[0].kind === 'income' ? 'receita' : 'despesa'}`);
  }
}

router.post('/', async (req, res) => {
  const data = createSchema.parse(req.body);
  const familyId = req.user.familyId;
  await assertFamilyRefs({ query }, familyId, data, REFS);
  await assertCategoryKind(familyId, data.category_id, data.type);

  const installments = data.installments ?? 1;
  const memberId = data.member_id === undefined ? req.user.id : data.member_id;
  // Divide o valor em parcelas; a primeira absorve a diferença de centavos.
  const cents = Math.round(data.amount * 100);
  const base = Math.floor(cents / installments);
  const group = installments > 1 ? randomUUID() : null;

  const created = await withTransaction(async (db) => {
    const out = [];
    for (let i = 0; i < installments; i++) {
      const value = (i === 0 ? cents - base * (installments - 1) : base) / 100;
      const description = installments > 1 ? `${data.description ?? ''} (${i + 1}/${installments})`.trim() : data.description ?? '';
      const { rows } = await db.query(
        `INSERT INTO transactions (family_id, account_id, member_id, category_id, type, amount, description, date,
                                   transfer_account_id, installment_number, installment_total, installment_group)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12) RETURNING *`,
        [
          familyId, data.account_id, memberId, data.category_id ?? null, data.type, round(value), description,
          addMonthsToDate(data.date, i), data.transfer_account_id ?? null,
          group ? i + 1 : null, group ? installments : null, group,
        ],
      );
      out.push(rows[0]);
    }
    return out;
  });
  res.status(201).json(installments > 1 ? created : created[0]);
});

router.patch('/:id', async (req, res) => {
  const id = idParam.parse(req.params.id);
  const familyId = req.user.familyId;
  const data = baseSchema.partial().parse(req.body);
  const { rows: current } = await query('SELECT * FROM transactions WHERE id = $1 AND family_id = $2', [id, familyId]);
  if (!current.length) throw new HttpError(404, 'Lançamento não encontrado');

  const merged = { ...current[0], ...data };
  if (merged.type === 'transfer' && !merged.transfer_account_id) {
    throw new HttpError(400, 'Transferências precisam de uma conta de destino');
  }
  if (merged.type !== 'transfer') merged.transfer_account_id = null;
  if (merged.type === 'transfer') merged.category_id = null;
  await assertFamilyRefs({ query }, familyId, data, REFS);
  await assertCategoryKind(familyId, merged.category_id, merged.type);

  const { rows } = await query(
    `UPDATE transactions
        SET type = $3, account_id = $4, transfer_account_id = $5, member_id = $6, category_id = $7,
            amount = $8, description = $9, date = $10
      WHERE id = $1 AND family_id = $2 RETURNING *`,
    [id, familyId, merged.type, merged.account_id, merged.transfer_account_id, merged.member_id,
      merged.category_id, merged.amount, merged.description, merged.date],
  );
  res.json(rows[0]);
});

// ?scope=all remove todas as parcelas do mesmo parcelamento
router.delete('/:id', async (req, res) => {
  const id = idParam.parse(req.params.id);
  const familyId = req.user.familyId;
  const { rows } = await query('SELECT installment_group FROM transactions WHERE id = $1 AND family_id = $2', [id, familyId]);
  if (!rows.length) throw new HttpError(404, 'Lançamento não encontrado');
  if (req.query.scope === 'all' && rows[0].installment_group) {
    await query('DELETE FROM transactions WHERE installment_group = $1 AND family_id = $2', [rows[0].installment_group, familyId]);
  } else {
    await query('DELETE FROM transactions WHERE id = $1 AND family_id = $2', [id, familyId]);
  }
  res.status(204).end();
});

export default router;
