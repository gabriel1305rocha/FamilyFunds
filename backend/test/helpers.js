import request from 'supertest';
import { createApp } from '../src/app.js';
import { pool } from '../src/db/pool.js';
import { migrate } from '../src/db/migrate.js';

export const app = createApp();

export async function resetDb() {
  await pool.query('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');
  await migrate({ log: () => {} });
}

let counter = 0;
export async function registerFamily(overrides = {}) {
  counter += 1;
  const body = {
    familyName: 'Família Teste',
    name: 'Gabriel',
    email: `user${counter}-${Date.now()}@test.com`,
    password: 'senha-segura',
    ...overrides,
  };
  const res = await request(app).post('/api/auth/register').send(body).expect(201);
  const token = res.body.token;
  const api = {
    get: (url) => request(app).get(url).set('Authorization', `Bearer ${token}`),
    post: (url, data) => request(app).post(url).set('Authorization', `Bearer ${token}`).send(data),
    patch: (url, data) => request(app).patch(url).set('Authorization', `Bearer ${token}`).send(data),
    delete: (url) => request(app).delete(url).set('Authorization', `Bearer ${token}`),
  };
  return { token, member: res.body.member, api, credentials: body };
}

export { pool, request };
