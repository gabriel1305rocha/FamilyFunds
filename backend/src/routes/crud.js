import { Router } from 'express';
import { z } from 'zod';
import { query } from '../db/pool.js';
import { HttpError } from '../middleware/errors.js';
import { assertFamilyRefs } from '../services/refs.js';

export const idParam = z.coerce.number().int().positive();

/**
 * Cria um router CRUD simples escopado por família.
 * - table: nome da tabela
 * - schema: zod object para criação (o update usa schema.partial())
 * - refs: campos que referenciam outras tabelas da família
 * - orderBy: ordenação da listagem
 * - list: função opcional para substituir a listagem padrão
 */
export function crudRouter({ table, schema, refs = {}, orderBy = 'id', list, beforeWrite }) {
  const router = Router();
  const updateSchema = schema.partial();

  router.get('/', async (req, res) => {
    if (list) return res.json(await list(req));
    const { rows } = await query(`SELECT * FROM ${table} WHERE family_id = $1 ORDER BY ${orderBy}`, [req.user.familyId]);
    res.json(rows);
  });

  router.get('/:id', async (req, res) => {
    const { rows } = await query(`SELECT * FROM ${table} WHERE id = $1 AND family_id = $2`, [
      idParam.parse(req.params.id),
      req.user.familyId,
    ]);
    if (!rows.length) throw new HttpError(404, 'Registro não encontrado');
    res.json(rows[0]);
  });

  router.post('/', async (req, res) => {
    const data = schema.parse(req.body);
    await assertFamilyRefs({ query }, req.user.familyId, data, refs);
    if (beforeWrite) await beforeWrite(data, req);
    const keys = Object.keys(data);
    const cols = ['family_id', ...keys];
    const values = [req.user.familyId, ...keys.map((k) => data[k])];
    const { rows } = await query(
      `INSERT INTO ${table} (${cols.join(', ')}) VALUES (${cols.map((_, i) => `$${i + 1}`).join(', ')}) RETURNING *`,
      values,
    );
    res.status(201).json(rows[0]);
  });

  router.patch('/:id', async (req, res) => {
    const id = idParam.parse(req.params.id);
    const data = updateSchema.parse(req.body);
    const keys = Object.keys(data);
    if (!keys.length) throw new HttpError(400, 'Nada para atualizar');
    await assertFamilyRefs({ query }, req.user.familyId, data, refs);
    if (beforeWrite) await beforeWrite(data, req);
    const sets = keys.map((k, i) => `${k} = $${i + 3}`);
    if (table === 'investments') sets.push('updated_at = now()');
    const { rows } = await query(
      `UPDATE ${table} SET ${sets.join(', ')} WHERE id = $1 AND family_id = $2 RETURNING *`,
      [id, req.user.familyId, ...keys.map((k) => data[k])],
    );
    if (!rows.length) throw new HttpError(404, 'Registro não encontrado');
    res.json(rows[0]);
  });

  router.delete('/:id', async (req, res) => {
    const { rowCount } = await query(`DELETE FROM ${table} WHERE id = $1 AND family_id = $2`, [
      idParam.parse(req.params.id),
      req.user.familyId,
    ]);
    if (!rowCount) throw new HttpError(404, 'Registro não encontrado');
    res.status(204).end();
  });

  return router;
}
