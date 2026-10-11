import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { requireAuth } from './middleware/auth.js';
import { errorHandler, notFound } from './middleware/errors.js';
import authRouter from './routes/auth.js';
import membersRouter from './routes/members.js';
import transactionsRouter from './routes/transactions.js';
import reportsRouter from './routes/reports.js';
import { accountsRouter, budgetsRouter, categoriesRouter, goalsRouter, investmentsRouter } from './routes/resources.js';

export function createApp() {
  const app = express();
  app.use(helmet());
  app.use(cors());
  app.use(express.json({ limit: '1mb' }));

  app.get('/health', (_req, res) => res.json({ status: 'ok' }));

  const api = express.Router();
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
