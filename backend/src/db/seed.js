// Cria uma família de demonstração com 3 meses de dados.
// Login: demo@familyfunds.app / familia123
import bcrypt from 'bcryptjs';
import { pool, withTransaction } from './pool.js';
import { migrate } from './migrate.js';
import { createDefaultCategories } from '../services/defaults.js';
import { addMonths, currentMonth } from '../services/dates.js';

const EMAIL = 'demo@familyfunds.app';

await migrate();
await withTransaction(async (db) => {
  await db.query('DELETE FROM families WHERE id IN (SELECT family_id FROM members WHERE email = $1)', [EMAIL]);
  const { rows: [family] } = await db.query("INSERT INTO families (name) VALUES ('Família Rocha') RETURNING id");
  const fid = family.id;
  const hash = await bcrypt.hash('familia123', 10);
  const { rows: [{ id: me }] } = await db.query(
    `INSERT INTO members (family_id, name, email, password_hash, role, color)
     VALUES ($1, 'Gabriel', $2, $3, 'owner', '#00A86B') RETURNING id`,
    [fid, EMAIL, hash],
  );
  const { rows: [{ id: wife }] } = await db.query(
    "INSERT INTO members (family_id, name, color) VALUES ($1, 'Esposa', '#1E88E5') RETURNING id",
    [fid],
  );
  await createDefaultCategories(db, fid);
  const { rows: cats } = await db.query('SELECT id, name FROM categories WHERE family_id = $1', [fid]);
  const cat = Object.fromEntries(cats.map((c) => [c.name, c.id]));

  const account = async (name, type, extra = {}) => {
    const { rows } = await db.query(
      `INSERT INTO accounts (family_id, owner_id, name, type, institution, initial_balance, credit_limit, closing_day, due_day, color)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING id`,
      [fid, extra.owner ?? null, name, type, extra.institution ?? null, extra.initial ?? 0,
        extra.limit ?? null, extra.closing ?? null, extra.due ?? null, extra.color ?? '#00A86B'],
    );
    return rows[0].id;
  };
  const checking = await account('Conta conjunta', 'checking', { institution: 'Banco Azul', initial: 4200, color: '#1565C0' });
  const savings = await account('Poupança', 'savings', { institution: 'Banco Azul', initial: 8000, color: '#00897B' });
  const myCard = await account('Cartão Gabriel', 'credit_card', { owner: me, institution: 'Banco Verde', limit: 8000, closing: 5, due: 12, color: '#2E7D32' });
  const wifeCard = await account('Cartão Esposa', 'credit_card', { owner: wife, institution: 'Banco Azul', limit: 6000, closing: 10, due: 17, color: '#0288D1' });

  const tx = (date, type, amount, description, accountId, memberId, category, transferTo = null) =>
    db.query(
      `INSERT INTO transactions (family_id, account_id, member_id, category_id, type, amount, description, date, transfer_account_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
      [fid, accountId, memberId, category ? cat[category] : null, type, amount, description, date, transferTo],
    );

  const month = currentMonth();
  for (let i = -2; i <= 0; i++) {
    const m = addMonths(month, i);
    const jitter = (v) => Math.round(v * (0.9 + Math.random() * 0.2) * 100) / 100;
    await tx(`${m}-05`, 'income', 7500, 'Salário', checking, me, 'Salário');
    await tx(`${m}-05`, 'income', 6200, 'Salário', checking, wife, 'Salário');
    await tx(`${m}-08`, 'expense', 2800, 'Aluguel', checking, me, 'Moradia');
    await tx(`${m}-10`, 'expense', jitter(420), 'Energia + água + internet', checking, wife, 'Contas e serviços');
    await tx(`${m}-03`, 'expense', jitter(1350), 'Supermercado', wifeCard, wife, 'Mercado');
    await tx(`${m}-17`, 'expense', jitter(620), 'Feira e hortifruti', checking, wife, 'Mercado');
    await tx(`${m}-06`, 'expense', jitter(480), 'Combustível', myCard, me, 'Transporte');
    await tx(`${m}-12`, 'expense', jitter(310), 'Restaurante', myCard, me, 'Restaurantes');
    await tx(`${m}-14`, 'expense', jitter(260), 'Farmácia', wifeCard, wife, 'Saúde');
    await tx(`${m}-15`, 'expense', 89.9, 'Streaming', myCard, me, 'Assinaturas');
    await tx(`${m}-20`, 'expense', jitter(540), 'Roupas', wifeCard, wife, 'Compras');
    await tx(`${m}-22`, 'expense', jitter(380), 'Cinema e passeio', myCard, me, 'Lazer');
    await tx(`${m}-12`, 'transfer', 1200, 'Pagamento fatura', checking, me, null, myCard);
    await tx(`${m}-17`, 'transfer', 2000, 'Pagamento fatura', checking, wife, null, wifeCard);
    await tx(`${m}-25`, 'transfer', 1500, 'Guardar na poupança', checking, me, null, savings);
    for (const [name, amount] of [['Mercado', 2200], ['Restaurantes', 300], ['Lazer', 400], ['Compras', 500]]) {
      await db.query('INSERT INTO budgets (family_id, category_id, month, amount) VALUES ($1, $2, $3, $4)', [fid, cat[name], m, amount]);
    }
  }

  const inv = (name, type, invested, current, liquidity, memberId) =>
    db.query(
      `INSERT INTO investments (family_id, member_id, name, type, institution, liquidity, invested_amount, current_value)
       VALUES ($1, $2, $3, $4, 'Corretora', $5, $6, $7)`,
      [fid, memberId, name, type, liquidity, invested, current],
    );
  await inv('Tesouro Selic 2029', 'treasury', 15000, 16420.35, 'daily', me);
  await inv('CDB 110% CDI', 'fixed_income', 10000, 10890.12, 'maturity', wife);
  await inv('Fundos imobiliários', 'reits', 6000, 6310.5, 'daily', me);
  await inv('ETF Ibovespa', 'stocks', 4000, 4380.0, 'daily', wife);

  await db.query(
    `INSERT INTO goals (family_id, name, target_amount, current_amount, deadline, color) VALUES
       ($1, 'Viagem de férias', 12000, 4500, $2, '#00A86B'),
       ($1, 'Reserva de emergência', 60000, 32000, NULL, '#1E88E5')`,
    [fid, `${addMonths(month, 10)}-01`],
  );
});
console.log(`Família demo criada. Login: ${EMAIL} / familia123`);
await pool.end();
