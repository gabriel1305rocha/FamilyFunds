// Utilitários de data trabalhando com strings 'YYYY-MM-DD' / 'YYYY-MM' (sem fuso horário).

const pad = (n) => String(n).padStart(2, '0');

export const toISODate = (d) => `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;

export const today = () => {
  const now = new Date();
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
};

export const currentMonth = () => today().slice(0, 7);

export function parseMonth(month) {
  const [y, m] = month.split('-').map(Number);
  return { y, m };
}

export function addMonths(month, delta) {
  const { y, m } = parseMonth(month);
  const d = new Date(Date.UTC(y, m - 1 + delta, 1));
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}`;
}

export function monthRange(month) {
  const { y, m } = parseMonth(month);
  const last = new Date(Date.UTC(y, m, 0)).getUTCDate();
  return { start: `${month}-01`, end: `${month}-${pad(last)}` };
}

/** Soma meses a uma data, ajustando o dia ao último dia do mês quando necessário (31/01 + 1 = 28/02). */
export function addMonthsToDate(date, delta) {
  const [y, m, d] = date.split('-').map(Number);
  const target = new Date(Date.UTC(y, m - 1 + delta, 1));
  const last = new Date(Date.UTC(target.getUTCFullYear(), target.getUTCMonth() + 1, 0)).getUTCDate();
  target.setUTCDate(Math.min(d, last));
  return toISODate(target);
}

function clampDay(month, day) {
  const { y, m } = parseMonth(month);
  const last = new Date(Date.UTC(y, m, 0)).getUTCDate();
  return `${month}-${pad(Math.min(day, last))}`;
}

/**
 * Período da fatura do cartão que contém a data de referência.
 * Compras feitas até o dia de fechamento entram na fatura do mês; depois disso, na próxima.
 */
export function billingPeriod(closingDay, refDate = today()) {
  const refMonth = refDate.slice(0, 7);
  const closingThisMonth = clampDay(refMonth, closingDay);
  const closeMonth = refDate <= closingThisMonth ? refMonth : addMonths(refMonth, 1);
  const end = clampDay(closeMonth, closingDay);
  // início = dia seguinte ao fechamento anterior
  const start = new Date(`${clampDay(addMonths(closeMonth, -1), closingDay)}T00:00:00Z`);
  start.setUTCDate(start.getUTCDate() + 1);
  return { start: toISODate(start), end };
}
