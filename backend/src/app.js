import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { config } from './config.js';
import { query } from './db/pool.js';
import { requireAuth } from './middleware/auth.js';
import { errorHandler, notFound } from './middleware/errors.js';
import authRouter from './routes/auth.js';
import membersRouter from './routes/members.js';
import transactionsRouter from './routes/transactions.js';
import reportsRouter from './routes/reports.js';
import { accountsRouter, budgetsRouter, categoriesRouter, goalsRouter, investmentsRouter } from './routes/resources.js';

const LOCAL_ORIGIN = /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;

/** Libera CORS apenas para as origens configuradas (e localhost fora de produção). */
export function isAllowedOrigin(origin, { env = config.env, allowed = config.corsOrigins } = {}) {
  if (allowed.includes(origin)) return true;
  return env !== 'production' && LOCAL_ORIGIN.test(origin);
}

export function createApp(options = {}) {
  const settings = { ...config, ...options };
  const app = express();

  app.set('trust proxy', settings.trustProxy);
  app.use(helmet());
  app.use(
    cors({
      // Requisições sem Origin (app mobile, curl) não passam pelo CORS.
      origin: (origin, callback) =>
        callback(null, !origin || isAllowedOrigin(origin, { env: settings.env, allowed: settings.corsOrigins })),
    }),
  );
  app.use(express.json({ limit: '1mb' }));

  app.get('/health', async (_req, res) => {
    try {
      await query('SELECT 1');
      res.json({ status: 'ok', database: 'ok' });
    } catch {
      res.status(503).json({ status: 'error', database: 'unavailable' });
    }
  });

  // Limite geral por IP, para evitar abuso da API.
  const apiLimiter = rateLimit({
    windowMs: 60 * 1000,
    limit: settings.apiRateLimit,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    message: { error: 'Muitas requisições. Aguarde um instante e tente novamente.' },
  });

  // Limite mais rígido para login/cadastro, contra ataques de força bruta.
  const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: settings.authRateLimit,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    message: { error: 'Muitas tentativas. Aguarde alguns minutos e tente novamente.' },
  });

  const api = express.Router();
  api.use(apiLimiter);
  api.use('/auth/login', authLimiter);
  api.use('/auth/register', authLimiter);
  api.use('/auth', authRouter);
  api.use(requireAuth);
  api.use('/members', membersRouter);
  api.use('/accounts', accountsRouter);
  api.use('/categories', categoriesRouter);
  api.use('/transactions', transactionsRouter);
  api.use('/budgets', budgetsRouter);
  api.use('/investments', investmentsRouter);
  api.use('/goals', goalsRouter);
  api.use('/reports', reportsRouter);
  app.use('/api', api);

  app.use(notFound);
  app.use(errorHandler);
  return app;
}
