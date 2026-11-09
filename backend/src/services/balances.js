import { query } from '../db/pool.js';
import { billingPeriod, today } from './dates.js';

/**
 * Saldo de cada conta até uma data:
 *   saldo inicial + receitas - despesas - transferências enviadas + transferências recebidas.
 * Para cartões de crédito o saldo fica negativo quando há fatura em aberto
 * (compras são despesas, pagamentos são transferências recebidas).
 */
export async function accountsWithBalances(familyId, { asOf = today(), includeArchived = true } = {}) {
  const { rows } = await query(
    `SELECT a.*,
            a.initial_balance
              + COALESCE((SELECT SUM(CASE t.type WHEN 'income' THEN t.amount ELSE -t.amount END)
                            FROM transactions t
                           WHERE t.account_id = a.id AND t.date <= $2), 0)
              + COALESCE((SELECT SUM(t.amount)
                            FROM transactions t
                           WHERE t.transfer_account_id = a.id AND t.date <= $2), 0) AS balance,
            COALESCE((SELECT SUM(t.amount)
                        FROM transactions t
                       WHERE t.account_id = a.id AND t.type = 'expense' AND t.date > $2), 0) AS future_expenses
       FROM accounts a
      WHERE a.family_id = $1 AND ($3 OR NOT a.archived)
      ORDER BY a.archived, a.type, a.name`,
    [familyId, asOf, includeArchived],
  );

  for (const acc of rows) {
    if (acc.type !== 'credit_card') continue;
    const debt = Math.max(0, -acc.balance);
    acc.used_limit = round(debt + acc.future_expenses);
    acc.available_limit = acc.credit_limit == null ? null : round(acc.credit_limit - acc.used_limit);
    acc.utilization = acc.credit_limit ? round(acc.used_limit / acc.credit_limit, 4) : null;
    if (acc.closing_day) {
      const period = billingPeriod(acc.closing_day, asOf);
      const { rows: bill } = await query(
        `SELECT COALESCE(SUM(amount), 0) AS total FROM transactions
          WHERE account_id = $1 AND type = 'expense' AND date BETWEEN $2 AND $3`,
        [acc.id, period.start, period.end],
      );
      acc.current_bill = { ...period, total: bill[0].total };
    }
  }
  return rows;
}

export const round = (n, digits = 2) => {
  const f = 10 ** digits;
  return Math.round((n + Number.EPSILON) * f) / f;
};
