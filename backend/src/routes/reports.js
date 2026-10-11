import { Router } from 'express';
import { z } from 'zod';
import { accountsWithBalances } from '../services/balances.js';
import { currentMonth } from '../services/dates.js';
import { cashflow, financialHealth, investmentSummary, monthlySummary } from '../services/reports.js';

const router = Router();

const monthQuery = z.object({
  month: z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/).default(() => currentMonth()),
});

router.get('/summary', async (req, res) => {
  const { month } = monthQuery.parse(req.query);
  res.json(await monthlySummary(req.user.familyId, month));
});

router.get('/cashflow', async (req, res) => {
  const { month } = monthQuery.parse(req.query);
  const months = z.coerce.number().int().min(1).max(24).default(6).parse(req.query.months);
  res.json(await cashflow(req.user.familyId, months, month));
});

router.get('/health', async (req, res) => {
  const { month } = monthQuery.parse(req.query);
  res.json(await financialHealth(req.user.familyId, month));
});

router.get('/investments', async (req, res) => {
  res.json(await investmentSummary(req.user.familyId));
});

// Tudo que a tela inicial do app precisa em uma única chamada.
router.get('/dashboard', async (req, res) => {
  const { month } = monthQuery.parse(req.query);
  const familyId = req.user.familyId;
  const [summary, flow, health, accounts, investments] = await Promise.all([
    monthlySummary(familyId, month),
    cashflow(familyId, 6, month),
    financialHealth(familyId, month),
    accountsWithBalances(familyId, { includeArchived: false }),
    investmentSummary(familyId),
  ]);
  res.json({ summary, cashflow: flow, health, accounts, investments });
});

export default router;
