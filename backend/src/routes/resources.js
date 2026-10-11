import { z } from 'zod';
import { crudRouter } from './crud.js';
import { accountsWithBalances } from '../services/balances.js';

const hexColor = z.string().regex(/^#[0-9A-Fa-f]{6}$/, 'Cor deve estar no formato #RRGGBB');
// O Postgres arredonda para 2 casas (NUMERIC(14,2)).
const money = z.number().finite().max(1e11);
const isoDate = z.iso.date();
const month = z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/, 'Mês deve estar no formato YYYY-MM');
const day = z.number().int().min(1).max(31);

export const accountsRouter = crudRouter({
  table: 'accounts',
  schema: z.object({
    name: z.string().trim().min(1).max(80),
    type: z.enum(['checking', 'savings', 'credit_card', 'cash', 'investment']),
    owner_id: z.number().int().positive().nullish(),
    institution: z.string().trim().max(80).nullish(),
    initial_balance: money.optional(),
    credit_limit: money.nonnegative().nullish(),
    closing_day: day.nullish(),
    due_day: day.nullish(),
    color: hexColor.optional(),
    archived: z.boolean().optional(),
  }),
  refs: { owner_id: 'members' },
  list: (req) => accountsWithBalances(req.user.familyId, { includeArchived: req.query.archived === 'true' }),
});

export const categoriesRouter = crudRouter({
  table: 'categories',
  schema: z.object({
    name: z.string().trim().min(1).max(60),
    kind: z.enum(['income', 'expense']),
    essential: z.boolean().optional(),
    icon: z.string().trim().min(1).max(40).optional(),
    color: hexColor.optional(),
  }),
  orderBy: 'kind DESC, name',
});

export const budgetsRouter = crudRouter({
  table: 'budgets',
  schema: z.object({
    category_id: z.number().int().positive(),
    month,
    amount: money.nonnegative(),
  }),
  refs: { category_id: 'categories' },
  orderBy: 'month DESC, category_id',
});

export const investmentsRouter = crudRouter({
  table: 'investments',
  schema: z.object({
    name: z.string().trim().min(1).max(80),
    type: z.enum(['fixed_income', 'treasury', 'stocks', 'reits', 'funds', 'crypto', 'pension', 'other']),
    member_id: z.number().int().positive().nullish(),
    institution: z.string().trim().max(80).nullish(),
    liquidity: z.enum(['daily', 'monthly', 'maturity']).optional(),
    invested_amount: money.nonnegative(),
    current_value: money.nonnegative(),
  }),
  refs: { member_id: 'members' },
  orderBy: 'current_value DESC',
});

export const goalsRouter = crudRouter({
  table: 'goals',
  schema: z.object({
    name: z.string().trim().min(1).max(80),
    target_amount: money.positive(),
    current_amount: money.nonnegative().optional(),
    deadline: isoDate.nullish(),
    color: hexColor.optional(),
  }),
  orderBy: 'deadline NULLS LAST, id',
});
