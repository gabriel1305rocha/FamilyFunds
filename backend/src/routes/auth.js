import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { query, withTransaction } from '../db/pool.js';
import { requireAuth, signToken } from '../middleware/auth.js';
import { HttpError } from '../middleware/errors.js';
import { createDefaultCategories } from '../services/defaults.js';

const router = Router();

const registerSchema = z.object({
  familyName: z.string().trim().min(1).max(80),
  name: z.string().trim().min(1).max(80),
  email: z.email().transform((e) => e.toLowerCase()),
  password: z.string().min(8, 'A senha deve ter pelo menos 8 caracteres').max(128),
});

const loginSchema = z.object({
  email: z.email().transform((e) => e.toLowerCase()),
  password: z.string().min(1),
});

export const publicMember = ({ password_hash, ...m }) => ({ ...m, has_login: Boolean(password_hash) });

router.post('/register', async (req, res) => {
  const data = registerSchema.parse(req.body);
  const passwordHash = await bcrypt.hash(data.password, 10);
  const member = await withTransaction(async (db) => {
    const { rows: fam } = await db.query('INSERT INTO families (name) VALUES ($1) RETURNING *', [data.familyName]);
    const familyId = fam[0].id;
    const { rows } = await db.query(
      `INSERT INTO members (family_id, name, email, password_hash, role, color)
       VALUES ($1, $2, $3, $4, 'owner', '#00A86B') RETURNING *`,
      [familyId, data.name, data.email, passwordHash],
    );
    await createDefaultCategories(db, familyId);
    return rows[0];
  });
  res.status(201).json({ token: signToken(member), member: publicMember(member) });
});

router.post('/login', async (req, res) => {
  const data = loginSchema.parse(req.body);
  const { rows } = await query('SELECT * FROM members WHERE email = $1', [data.email]);
  const member = rows[0];
  if (!member?.password_hash || !(await bcrypt.compare(data.password, member.password_hash))) {
    throw new HttpError(401, 'E-mail ou senha incorretos');
  }
  res.json({ token: signToken(member), member: publicMember(member) });
});

router.get('/me', requireAuth, async (req, res) => {
  const { rows } = await query(
    `SELECT m.*, f.name AS family_name, f.currency
       FROM members m JOIN families f ON f.id = m.family_id
      WHERE m.id = $1`,
    [req.user.id],
  );
  if (!rows.length) throw new HttpError(401, 'Usuário não encontrado');
  res.json(publicMember(rows[0]));
});

export default router;
