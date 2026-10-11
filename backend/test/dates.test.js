import { test } from 'node:test';
import assert from 'node:assert/strict';
import { addMonths, addMonthsToDate, billingPeriod, monthRange } from '../src/services/dates.js';

test('addMonths atravessa o ano', () => {
  assert.equal(addMonths('2026-11', 3), '2027-02');
  assert.equal(addMonths('2026-01', -1), '2025-12');
});

test('addMonthsToDate ajusta o fim do mês', () => {
  assert.equal(addMonthsToDate('2026-01-31', 1), '2026-02-28');
  assert.equal(addMonthsToDate('2028-01-31', 1), '2028-02-29');
});

test('monthRange', () => {
  assert.deepEqual(monthRange('2026-02'), { start: '2026-02-01', end: '2026-02-28' });
});

test('billingPeriod respeita o dia de fechamento', () => {
  assert.deepEqual(billingPeriod(5, '2026-03-05'), { start: '2026-02-06', end: '2026-03-05' });
  assert.deepEqual(billingPeriod(5, '2026-03-06'), { start: '2026-03-06', end: '2026-04-05' });
  assert.deepEqual(billingPeriod(31, '2026-02-15'), { start: '2026-02-01', end: '2026-02-28' });
});
