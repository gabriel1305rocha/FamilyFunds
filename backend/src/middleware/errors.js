import { ZodError } from 'zod';

export class HttpError extends Error {
  constructor(status, message, details) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

export function notFound(_req, _res, next) {
  next(new HttpError(404, 'Rota não encontrada'));
}

// eslint-disable-next-line no-unused-vars
export function errorHandler(err, _req, res, _next) {
  if (err instanceof ZodError) {
    return res.status(400).json({
      error: 'Dados inválidos',
      details: err.issues.map((i) => ({ path: i.path.join('.'), message: i.message })),
    });
  }
  if (err instanceof HttpError) {
    return res.status(err.status).json({ error: err.message, details: err.details });
  }
  // Violações de integridade do Postgres
  if (err.code === '23505') return res.status(409).json({ error: 'Registro duplicado' });
  if (err.code === '23503') return res.status(400).json({ error: 'Referência inválida' });
  if (err.code === '23514') return res.status(400).json({ error: 'Valor fora das regras permitidas' });
  if (err.type === 'entity.parse.failed') return res.status(400).json({ error: 'JSON inválido' });

  console.error(err);
  return res.status(500).json({ error: 'Erro interno do servidor' });
}
