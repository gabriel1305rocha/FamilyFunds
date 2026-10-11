import { query } from '../db/pool.js';
import { accountsWithBalances, round } from './balances.js';
import { addMonths, currentMonth, monthRange } from './dates.js';

const pct = (part, total) => (total > 0 ? round(part / total, 4) : 0);

/** Resumo do mês: receitas x despesas, por categoria, por membro e por tipo de conta. */
export async function monthlySummary(familyId, month = currentMonth()) {
  const { start, end } = monthRange(month);
  const params = [familyId, start, end];

  const [totals, byCategory, byMember, byAccountType, budgets] = await Promise.all([
    query(
      `SELECT COALESCE(SUM(amount) FILTER (WHERE type = 'income'), 0) AS income,
              COALESCE(SUM(amount) FILTER (WHERE type = 'expense'), 0) AS expense
         FROM transactions WHERE family_id = $1 AND date BETWEEN $2 AND $3`,
      params,
    ),
    query(
      `SELECT c.id, COALESCE(c.name, 'Sem categoria') AS name, c.color, c.icon, c.essential, t.type,
              SUM(t.amount) AS total, COUNT(*)::int AS count
         FROM transactions t LEFT JOIN categories c ON c.id = t.category_id
        WHERE t.family_id = $1 AND t.date BETWEEN $2 AND $3 AND t.type <> 'transfer'
        GROUP BY c.id, c.name, c.color, c.icon, c.essential, t.type
        ORDER BY total DESC`,
      params,
    ),
    query(
      `SELECT m.id, m.name, m.color,
              COALESCE(SUM(t.amount) FILTER (WHERE t.type = 'income'), 0) AS income,
              COALESCE(SUM(t.amount) FILTER (WHERE t.type = 'expense'), 0) AS expense
         FROM members m
         LEFT JOIN transactions t ON t.member_id = m.id AND t.date BETWEEN $2 AND $3
        WHERE m.family_id = $1
        GROUP BY m.id ORDER BY m.id`,
      params,
    ),
    query(
      `SELECT a.type AS account_type, SUM(t.amount) AS expense
         FROM transactions t JOIN accounts a ON a.id = t.account_id
        WHERE t.family_id = $1 AND t.date BETWEEN $2 AND $3 AND t.type = 'expense'
        GROUP BY a.type`,
      params,
    ),
    budgetStatus(familyId, month),
  ]);

  const income = totals.rows[0].income;
  const expense = totals.rows[0].expense;
  const prev = await query(
    `SELECT COALESCE(SUM(amount) FILTER (WHERE type = 'income'), 0) AS income,
            COALESCE(SUM(amount) FILTER (WHERE type = 'expense'), 0) AS expense
       FROM transactions WHERE family_id = $1 AND date BETWEEN $2 AND $3`,
    [familyId, monthRange(addMonths(month, -1)).start, monthRange(addMonths(month, -1)).end],
  );

  return {
    month,
    income,
    expense,
    balance: round(income - expense),
    savings_rate: pct(income - expense, income),
    previous: { ...prev.rows[0], balance: round(prev.rows[0].income - prev.rows[0].expense) },
    expense_by_category: byCategory.rows
      .filter((r) => r.type === 'expense')
      .map((r) => ({ ...r, share: pct(r.total, expense) })),
    income_by_category: byCategory.rows
      .filter((r) => r.type === 'income')
      .map((r) => ({ ...r, share: pct(r.total, income) })),
    by_member: byMember.rows.map((r) => ({ ...r, balance: round(r.income - r.expense), expense_share: pct(r.expense, expense) })),
    expense_by_account_type: byAccountType.rows.map((r) => ({ ...r, share: pct(r.expense, expense) })),
    budgets,
  };
}

export async function budgetStatus(familyId, month = currentMonth()) {
  const { start, end } = monthRange(month);
  const { rows } = await query(
    `SELECT b.id, b.category_id, c.name AS category_name, c.color, c.icon, b.amount AS budget,
            COALESCE((SELECT SUM(t.amount) FROM transactions t
                       WHERE t.category_id = b.category_id AND t.type = 'expense'
                         AND t.date BETWEEN $3 AND $4), 0) AS spent
       FROM budgets b JOIN categories c ON c.id = b.category_id
      WHERE b.family_id = $1 AND b.month = $2
      ORDER BY c.name`,
    [familyId, month, start, end],
  );
  return rows.map((r) => ({ ...r, remaining: round(r.budget - r.spent), usage: pct(r.spent, r.budget) }));
}

/** Receitas e despesas dos últimos N meses (inclui o mês de referência). */
export async function cashflow(familyId, months = 6, until = currentMonth()) {
  const first = addMonths(until, -(months - 1));
  const { rows } = await query(
    `SELECT to_char(date, 'YYYY-MM') AS month,
            COALESCE(SUM(amount) FILTER (WHERE type = 'income'), 0) AS income,
            COALESCE(SUM(amount) FILTER (WHERE type = 'expense'), 0) AS expense
       FROM transactions
      WHERE family_id = $1 AND date BETWEEN $2 AND $3
      GROUP BY 1`,
    [familyId, monthRange(first).start, monthRange(until).end],
  );
  const byMonth = new Map(rows.map((r) => [r.month, r]));
  return Array.from({ length: months }, (_, i) => {
    const month = addMonths(first, i);
    const r = byMonth.get(month) ?? { income: 0, expense: 0 };
    return { month, income: r.income, expense: r.expense, balance: round(r.income - r.expense) };
  });
}

export const INVESTMENT_LABELS = {
  fixed_income: 'Renda fixa (CDB, LCI, LCA)',
  treasury: 'Tesouro Direto',
  stocks: 'Ações',
  reits: 'Fundos imobiliários',
  funds: 'Fundos de investimento',
  crypto: 'Criptoativos',
  pension: 'Previdência',
  other: 'Outros',
};

const VARIABLE_INCOME = new Set(['stocks', 'reits', 'crypto']);

export async function investmentSummary(familyId) {
  const { rows } = await query(
    `SELECT type, SUM(invested_amount) AS invested, SUM(current_value) AS current,
            SUM(current_value) FILTER (WHERE liquidity = 'daily') AS liquid
       FROM investments WHERE family_id = $1 GROUP BY type ORDER BY current DESC`,
    [familyId],
  );
  const invested = round(rows.reduce((s, r) => s + r.invested, 0));
  const current = round(rows.reduce((s, r) => s + r.current, 0));
  const liquid = round(rows.reduce((s, r) => s + (r.liquid ?? 0), 0));
  const variable = round(rows.filter((r) => VARIABLE_INCOME.has(r.type)).reduce((s, r) => s + r.current, 0));
  return {
    invested,
    current,
    liquid,
    profit: round(current - invested),
    return_rate: pct(current - invested, invested),
    variable_income_share: pct(variable, current),
    allocation: rows.map((r) => ({
      type: r.type,
      label: INVESTMENT_LABELS[r.type],
      invested: r.invested,
      current: r.current,
      share: pct(r.current, current),
      return_rate: pct(r.current - r.invested, r.invested),
    })),
  };
}

/**
 * Saúde financeira da família (0 a 100), composta por 5 indicadores:
 *  - Taxa de poupança (média dos últimos 3 meses)       meta: >= 20% da renda
 *  - Reserva de emergência (meses de despesas cobertos) meta: >= 6 meses
 *  - Uso do limite do cartão                            meta: <= 30%
 *  - Comprometimento da renda com faturas               meta: <= 30% da renda
 *  - Aderência ao orçamento do mês                      meta: 100% das categorias dentro do limite
 */
export async function financialHealth(familyId, month = currentMonth()) {
  const flow = await cashflow(familyId, 3, month);
  const months = flow.filter((m) => m.income > 0 || m.expense > 0);
  const avgIncome = avg(months.map((m) => m.income));
  const avgExpense = avg(months.map((m) => m.expense));

  const accounts = await accountsWithBalances(familyId, { includeArchived: false });
  const investments = await investmentSummary(familyId);
  const budgets = await budgetStatus(familyId, month);

  const cash = accounts
    .filter((a) => ['checking', 'savings', 'cash'].includes(a.type))
    .reduce((s, a) => s + Math.max(0, a.balance), 0);
  const liquidAssets = round(cash + investments.liquid);
  const cards = accounts.filter((a) => a.type === 'credit_card');
  const cardDebt = round(cards.reduce((s, a) => s + Math.max(0, -a.balance), 0));
  const cardUsed = cards.reduce((s, a) => s + (a.used_limit ?? 0), 0);
  const cardLimit = cards.reduce((s, a) => s + (a.credit_limit ?? 0), 0);
  const netWorth = round(
    accounts.filter((a) => a.type !== 'investment').reduce((s, a) => s + a.balance, 0) + investments.current,
  );

  const savingsRate = avgIncome > 0 ? (avgIncome - avgExpense) / avgIncome : 0;
  const emergencyMonths = avgExpense > 0 ? liquidAssets / avgExpense : liquidAssets > 0 ? 12 : 0;
  const utilization = cardLimit > 0 ? cardUsed / cardLimit : 0;
  const billToIncome = avgIncome > 0 ? cardDebt / avgIncome : cardDebt > 0 ? 1 : 0;
  const withinBudget = budgets.length ? budgets.filter((b) => b.spent <= b.budget).length / budgets.length : null;

  const indicators = [
    {
      key: 'savings_rate',
      label: 'Taxa de poupança',
      value: round(savingsRate, 4),
      target: 0.2,
      weight: 30,
      score: clamp(savingsRate / 0.2),
    },
    {
      key: 'emergency_fund',
      label: 'Reserva de emergência (meses)',
      value: round(emergencyMonths, 1),
      target: 6,
      weight: 25,
      score: clamp(emergencyMonths / 6),
    },
    {
      key: 'credit_utilization',
      label: 'Uso do limite do cartão',
      value: round(utilization, 4),
      target: 0.3,
      weight: 15,
      score: utilization <= 0.3 ? 1 : clamp(1 - (utilization - 0.3) / 0.7),
    },
    {
      key: 'debt_to_income',
      label: 'Fatura em aberto / renda',
      value: round(billToIncome, 4),
      target: 0.3,
      weight: 15,
      score: billToIncome <= 0.3 ? 1 : clamp(1 - (billToIncome - 0.3) / 0.7),
    },
    {
      key: 'budget_adherence',
      label: 'Categorias dentro do orçamento',
      value: withinBudget === null ? null : round(withinBudget, 4),
      target: 1,
      weight: 15,
      score: withinBudget,
    },
  ];

  // Indicadores sem dados (ex.: nenhum orçamento definido) não entram no cálculo.
  const scored = indicators.filter((i) => i.score !== null);
  const totalWeight = scored.reduce((s, i) => s + i.weight, 0);
  const score = Math.round((scored.reduce((s, i) => s + i.score * i.weight, 0) / totalWeight) * 100);
  for (const i of indicators) i.score = i.score === null ? null : Math.round(i.score * 100);

  return {
    month,
    score: months.length ? score : null,
    level: months.length ? level(score) : 'sem_dados',
    indicators,
    figures: {
      avg_income: round(avgIncome),
      avg_expense: round(avgExpense),
      liquid_assets: liquidAssets,
      card_debt: cardDebt,
      card_limit: round(cardLimit),
      invested: investments.current,
      net_worth: netWorth,
    },
    recommendations: recommendations({ savingsRate, emergencyMonths, utilization, billToIncome, budgets, avgExpense, liquidAssets, investments, hasData: months.length > 0 }),
  };
}

function recommendations(ctx) {
  const out = [];
  if (!ctx.hasData) {
    return [{ priority: 'info', title: 'Comece registrando seus lançamentos', message: 'Cadastre suas receitas e despesas para calcularmos a saúde financeira da família.' }];
  }
  if (ctx.savingsRate < 0) {
    out.push({ priority: 'high', title: 'Gastos acima da renda', message: 'Nos últimos meses a família gastou mais do que ganhou. Revise as despesas não essenciais e evite novas parcelas.' });
  } else if (ctx.savingsRate < 0.1) {
    out.push({ priority: 'medium', title: 'Aumente a taxa de poupança', message: 'Tente guardar ao menos 10% a 20% da renda logo que o salário cair ("pague-se primeiro").' });
  }
  if (ctx.billToIncome > 0.5) {
    out.push({ priority: 'high', title: 'Fatura do cartão pesada', message: 'A fatura em aberto passa de 50% da renda mensal. Evite o rotativo: os juros do cartão estão entre os mais altos do mercado.' });
  }
  if (ctx.utilization > 0.7) {
    out.push({ priority: 'medium', title: 'Limite do cartão quase no fim', message: 'Usar mais de 70% do limite reduz sua margem para imprevistos. Concentre as compras na conta corrente por um tempo.' });
  }
  const over = ctx.budgets.filter((b) => b.spent > b.budget);
  if (over.length) {
    out.push({ priority: 'medium', title: 'Orçamento estourado', message: `Categorias acima do limite: ${over.map((b) => b.category_name).join(', ')}.` });
  }
  if (ctx.emergencyMonths < 6) {
    const missing = round(Math.max(0, ctx.avgExpense * 6 - ctx.liquidAssets));
    out.push({
      priority: ctx.emergencyMonths < 3 ? 'high' : 'medium',
      title: 'Monte a reserva de emergência',
      message: `A reserva cobre ${round(ctx.emergencyMonths, 1)} meses de despesas. Faltam cerca de R$ ${missing.toLocaleString('pt-BR', { minimumFractionDigits: 2 })} para 6 meses, em investimentos de liquidez diária (Tesouro Selic, CDB com liquidez diária).`,
    });
  }
  out.push(...investmentInsights(ctx));
  if (!out.length) {
    out.push({ priority: 'info', title: 'Finanças em dia!', message: 'A família está poupando, com reserva formada e crédito sob controle. Continue assim.' });
  }
  return out;
}

function investmentInsights({ emergencyMonths, savingsRate, investments }) {
  const out = [];
  if (emergencyMonths >= 6 && savingsRate > 0 && investments.current === 0) {
    out.push({ priority: 'info', title: 'Hora de investir', message: 'A reserva de emergência está completa. Considere direcionar a sobra mensal para objetivos de médio e longo prazo (Tesouro IPCA+, CDBs, fundos imobiliários, ações).' });
  }
  if (investments.current > 0) {
    if (emergencyMonths < 3 && investments.variable_income_share > 0.3) {
      out.push({ priority: 'medium', title: 'Prioridade: liquidez', message: 'Boa parte dos investimentos está em renda variável enquanto a reserva de emergência ainda é pequena. Priorize completar a reserva em renda fixa de liquidez diária.' });
    }
    const top = investments.allocation[0];
    if (investments.allocation.length && top.share > 0.8 && investments.current > 10000) {
      out.push({ priority: 'info', title: 'Diversifique a carteira', message: `${Math.round(top.share * 100)}% do patrimônio investido está em ${top.label}. Diversificar reduz o risco.` });
    }
    const crypto = investments.allocation.find((a) => a.type === 'crypto');
    if (crypto && crypto.share > 0.1) {
      out.push({ priority: 'medium', title: 'Exposição alta a cripto', message: `Criptoativos representam ${Math.round(crypto.share * 100)}% da carteira. É comum limitar ativos muito voláteis a até 5–10%.` });
    }
  }
  return out;
}

const avg = (xs) => (xs.length ? xs.reduce((s, x) => s + x, 0) / xs.length : 0);
const clamp = (x) => Math.max(0, Math.min(1, x));

function level(score) {
  if (score >= 80) return 'excelente';
  if (score >= 60) return 'boa';
  if (score >= 40) return 'atencao';
  return 'critica';
}
