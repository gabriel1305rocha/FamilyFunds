import jwt from 'jsonwebtoken';
import { config } from '../config.js';
import { HttpError } from './errors.js';

export function signToken(member) {
  return jwt.sign({ sub: member.id, familyId: member.family_id, role: member.role }, config.jwtSecret, {
    expiresIn: config.jwtExpiresIn,
  });
}

export function requireAuth(req, _res, next) {
  const header = req.get('authorization') ?? '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) throw new HttpError(401, 'Token de acesso ausente');
  try {
    const payload = jwt.verify(token, config.jwtSecret);
    req.user = { id: Number(payload.sub), familyId: payload.familyId, role: payload.role };
  } catch {
    throw new HttpError(401, 'Token inválido ou expirado');
  }
  next();
}

export function requireOwner(req, _res, next) {
  if (req.user.role !== 'owner') throw new HttpError(403, 'Apenas o responsável pela família pode fazer isso');
  next();
}
