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

export function createApp() {
  const app = express();

  app.set('trust proxy', config.trustProxy);
  app.use(helmet());
  app.use(cors({ origin: config.corsOrigin }));
  app.use(express.json({ limit: '1mb' }));

  app.get('/health', async (_req, res) => {
    try {
      await query('SELECT 1');
      res.json({ status: 'ok', database: 'ok' });
    } catch {
      res.status(503).json({ status: 'error', database: 'unavailable' });
    }
  });

  // Limita tentativas de login/cadastro para dificultar ataques de força bruta.
  const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: config.authRateLimit,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    message: { error: 'Muitas tentativas. Aguarde alguns minutos e tente novamente.' },
  });

  const api = express.Router();
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
