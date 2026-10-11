import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { query } from '../db/pool.js';
import { requireOwner } from '../middleware/auth.js';
import { HttpError } from '../middleware/errors.js';
import { idParam } from './crud.js';
import { publicMember } from './auth.js';

const router = Router();

const hexColor = z.string().regex(/^#[0-9A-Fa-f]{6}$/);

const memberSchema = z.object({
  name: z.string().trim().min(1).max(80),
  email: z.email().transform((e) => e.toLowerCase()).nullish(),
  password: z.string().min(8).max(128).nullish(),
  color: hexColor.optional(),
});

router.get('/', async (req, res) => {
  const { rows } = await query('SELECT * FROM members WHERE family_id = $1 ORDER BY id', [req.user.familyId]);
  res.json(rows.map(publicMember));
});

router.post('/', requireOwner, async (req, res) => {
  const data = memberSchema.parse(req.body);
  if (data.password && !data.email) throw new HttpError(400, 'Informe um e-mail para criar o acesso');
  const hash = data.password ? await bcrypt.hash(data.password, 10) : null;
  const { rows } = await query(
    `INSERT INTO members (family_id, name, email, password_hash, color)
     VALUES ($1, $2, $3, $4, COALESCE($5, '#1E88E5')) RETURNING *`,
    [req.user.familyId, data.name, data.email ?? null, hash, data.color ?? null],
  );
  res.status(201).json(publicMember(rows[0]));
});

router.patch('/:id', async (req, res) => {
  const id = idParam.parse(req.params.id);
  if (req.user.role !== 'owner' && req.user.id !== id) {
    throw new HttpError(403, 'Você só pode editar o seu próprio perfil');
  }
  const data = memberSchema.partial().parse(req.body);
  const fields = {};
  if (data.name !== undefined) fields.name = data.name;
  if (data.email !== undefined) fields.email = data.email;
  if (data.color !== undefined) fields.color = data.color;
  if (data.password) fields.password_hash = await bcrypt.hash(data.password, 10);
  const keys = Object.keys(fields);
  if (!keys.length) throw new HttpError(400, 'Nada para atualizar');
  const { rows } = await query(
    `UPDATE members SET ${keys.map((k, i) => `${k} = $${i + 3}`).join(', ')}
      WHERE id = $1 AND family_id = $2 RETURNING *`,
    [id, req.user.familyId, ...keys.map((k) => fields[k])],
  );
  if (!rows.length) throw new HttpError(404, 'Membro não encontrado');
  res.json(publicMember(rows[0]));
});

router.delete('/:id', requireOwner, async (req, res) => {
  const id = idParam.parse(req.params.id);
  if (id === req.user.id) throw new HttpError(400, 'Você não pode remover a si mesmo');
  const { rowCount } = await query('DELETE FROM members WHERE id = $1 AND family_id = $2', [id, req.user.familyId]);
  if (!rowCount) throw new HttpError(404, 'Membro não encontrado');
  res.status(204).end();
});

export default router;
