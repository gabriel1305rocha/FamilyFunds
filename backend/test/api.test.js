import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { app, pool, registerFamily, request, resetDb } from './helpers.js';
import { currentMonth } from '../src/services/dates.js';

before(resetDb);
after(() => pool.end());

const month = currentMonth();

describe('auth', () => {
  test('cadastro cria família com categorias padrão e permite login', async () => {
    const { api, credentials, member } = await registerFamily();
    assert.equal(member.role, 'owner');
    assert.equal(member.password_hash, undefined);

    const login = await request(app)
      .post('/api/auth/login')
      .send({ email: credentials.email.toUpperCase(), password: credentials.password })
      .expect(200);
    assert.ok(login.body.token);

    const cats = await api.get('/api/categories').expect(200);
    assert.ok(cats.body.some((c) => c.name === 'Mercado' && c.kind === 'expense'));
    const me = await api.get('/api/auth/me').expect(200);
    assert.equal(me.body.family_name, 'Família Teste');
  });

  test('senha errada e rotas sem token retornam 401', async () => {
    const { credentials } = await registerFamily();
    await request(app).post('/api/auth/login').send({ email: credentials.email, password: 'errada!!' }).expect(401);
    await request(app).get('/api/accounts').expect(401);
  });

  test('valida dados de cadastro', async () => {
    const res = await request(app).post('/api/auth/register').send({ familyName: 'x', name: 'y', email: 'nope', password: '1' }).expect(400);
    assert.ok(res.body.details.length >= 2);
  });
});

describe('contas e lançamentos', () => {
  test('saldo da conta corrente e do cartão de crédito com pagamento de fatura', async () => {
    const { api, member } = await registerFamily();
    const checking = (await api.post('/api/accounts', { name: 'Corrente', type: 'checking', initial_balance: 1000 }).expect(201)).body;
    const card = (await api.post('/api/accounts', { name: 'Cartão', type: 'credit_card', credit_limit: 5000, closing_day: 5, due_day: 12 }).expect(201)).body;
    const cats = (await api.get('/api/categories')).body;
    const salary = cats.find((c) => c.name === 'Salário');
    const market = cats.find((c) => c.name === 'Mercado');

    await api.post('/api/transactions', { type: 'income', account_id: checking.id, category_id: salary.id, amount: 5000, date: `${month}-01` }).expect(201);
    await api.post('/api/transactions', { type: 'expense', account_id: card.id, category_id: market.id, amount: 800, date: `${month}-01` }).expect(201);
    await api.post('/api/transactions', { type: 'transfer', account_id: checking.id, transfer_account_id: card.id, amount: 500, date: `${month}-01` }).expect(201);

    const accounts = (await api.get('/api/accounts').expect(200)).body;
    const c = accounts.find((a) => a.id === checking.id);
    const k = accounts.find((a) => a.id === card.id);
    assert.equal(c.balance, 5500);
    assert.equal(k.balance, -300);
    assert.equal(k.used_limit, 300);
    assert.equal(k.available_limit, 4700);

    const list = (await api.get(`/api/transactions?month=${month}&account_id=${card.id}`).expect(200)).body;
    assert.equal(list.length, 2);
    assert.equal(list[0].member_id, member.id);
  });

  test('compra parcelada gera parcelas mensais somando o total', async () => {
    const { api } = await registerFamily();
    const card = (await api.post('/api/accounts', { name: 'Cartão', type: 'credit_card', credit_limit: 3000 }).expect(201)).body;
    const res = await api
      .post('/api/transactions', { type: 'expense', account_id: card.id, amount: 1000, installments: 3, description: 'TV', date: '2026-01-31' })
      .expect(201);
    assert.equal(res.body.length, 3);
    assert.deepEqual(res.body.map((t) => t.date), ['2026-01-31', '2026-02-28', '2026-03-31']);
    assert.equal(res.body.reduce((s, t) => s + t.amount, 0), 1000);
    assert.equal(res.body[2].description, 'TV (3/3)');

    await api.delete(`/api/transactions/${res.body[0].id}?scope=all`).expect(204);
    assert.equal((await api.get('/api/transactions').expect(200)).body.length, 0);
  });

  test('regras de validação dos lançamentos', async () => {
    const { api } = await registerFamily();
    const acc = (await api.post('/api/accounts', { name: 'C', type: 'checking' }).expect(201)).body;
    const cats = (await api.get('/api/categories')).body;
    const salary = cats.find((c) => c.name === 'Salário');
    await api.post('/api/transactions', { type: 'transfer', account_id: acc.id, amount: 10, date: '2026-01-01' }).expect(400);
    await api.post('/api/transactions', { type: 'expense', account_id: acc.id, category_id: salary.id, amount: 10, date: '2026-01-01' }).expect(400);
    await api.post('/api/transactions', { type: 'expense', account_id: acc.id, amount: -5, date: '2026-01-01' }).expect(400);
    await api.post('/api/transactions', { type: 'income', account_id: acc.id, amount: 10, installments: 2, date: '2026-01-01' }).expect(400);
  });

  test('uma família não acessa dados de outra', async () => {
    const a = await registerFamily();
    const b = await registerFamily();
    const accA = (await a.api.post('/api/accounts', { name: 'A', type: 'checking' }).expect(201)).body;
    await b.api.get(`/api/accounts/${accA.id}`).expect(404);
    await b.api.patch(`/api/accounts/${accA.id}`, { name: 'hack' }).expect(404);
    await b.api.post('/api/transactions', { type: 'income', account_id: accA.id, amount: 10, date: '2026-01-01' }).expect(400);
    assert.equal((await b.api.get('/api/accounts')).body.length, 0);
  });
});

describe('membros', () => {
  test('responsável adiciona a esposa e os gastos aparecem por membro', async () => {
    const { api, member } = await registerFamily();
    const wife = (await api.post('/api/members', { name: 'Esposa', color: '#1E88E5' }).expect(201)).body;
    assert.equal(wife.has_login, false);
    const acc = (await api.post('/api/accounts', { name: 'C', type: 'checking' }).expect(201)).body;
    await api.post('/api/transactions', { type: 'income', account_id: acc.id, amount: 4000, date: `${month}-02` }).expect(201);
    await api.post('/api/transactions', { type: 'expense', account_id: acc.id, member_id: wife.id, amount: 300, date: `${month}-02` }).expect(201);
    await api.post('/api/transactions', { type: 'expense', account_id: acc.id, amount: 100, date: `${month}-02` }).expect(201);

    const summary = (await api.get(`/api/reports/summary?month=${month}`).expect(200)).body;
    assert.equal(summary.income, 4000);
    assert.equal(summary.expense, 400);
    assert.equal(summary.savings_rate, 0.9);
    const byId = Object.fromEntries(summary.by_member.map((m) => [m.id, m]));
    assert.equal(byId[wife.id].expense, 300);
    assert.equal(byId[member.id].expense, 100);
    assert.equal(byId[wife.id].expense_share, 0.75);

    await api.delete(`/api/members/${member.id}`).expect(400);
  });
});

describe('relatórios', () => {
  test('saúde financeira, orçamento e investimentos', async () => {
    const { api } = await registerFamily();
    const acc = (await api.post('/api/accounts', { name: 'C', type: 'checking' }).expect(201)).body;
    const card = (await api.post('/api/accounts', { name: 'K', type: 'credit_card', credit_limit: 1000 }).expect(201)).body;
    const cats = (await api.get('/api/categories')).body;
    const lazer = cats.find((c) => c.name === 'Lazer');

    await api.post('/api/transactions', { type: 'income', account_id: acc.id, amount: 10000, date: `${month}-01` }).expect(201);
    await api.post('/api/transactions', { type: 'expense', account_id: card.id, category_id: lazer.id, amount: 900, date: `${month}-01` }).expect(201);
    await api.post('/api/budgets', { category_id: lazer.id, month, amount: 500 }).expect(201);
    await api.post('/api/investments', { name: 'BTC', type: 'crypto', invested_amount: 1000, current_value: 3000 }).expect(201);

    const health = (await api.get(`/api/reports/health?month=${month}`).expect(200)).body;
    assert.ok(health.score >= 0 && health.score <= 100);
    const ind = Object.fromEntries(health.indicators.map((i) => [i.key, i]));
    assert.equal(ind.credit_utilization.value, 0.9);
    assert.equal(ind.budget_adherence.value, 0);
    assert.ok(health.recommendations.some((r) => r.title === 'Orçamento estourado'));
    assert.ok(health.recommendations.some((r) => r.title === 'Exposição alta a cripto'));

    const inv = (await api.get('/api/reports/investments').expect(200)).body;
    assert.equal(inv.profit, 2000);
    assert.equal(inv.return_rate, 2);

    const dash = (await api.get(`/api/reports/dashboard?month=${month}`).expect(200)).body;
    assert.equal(dash.cashflow.length, 6);
    assert.equal(dash.cashflow.at(-1).income, 10000);
    assert.equal(dash.summary.budgets[0].spent, 900);
  });

  test('família sem lançamentos tem saúde "sem_dados"', async () => {
    const { api } = await registerFamily();
    const health = (await api.get('/api/reports/health').expect(200)).body;
    assert.equal(health.score, null);
    assert.equal(health.level, 'sem_dados');
  });
});
