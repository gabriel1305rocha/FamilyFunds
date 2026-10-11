import { HttpError } from '../middleware/errors.js';

const ALLOWED_TABLES = new Set(['members', 'accounts', 'categories', 'investments', 'goals', 'budgets', 'transactions']);

/**
 * Garante que os IDs referenciados pertencem à família do usuário,
 * evitando que alguém aponte para dados de outra família.
 * refs: { campo: tabela }
 */
export async function assertFamilyRefs(db, familyId, data, refs) {
  for (const [field, table] of Object.entries(refs)) {
    const id = data[field];
    if (id === undefined || id === null) continue;
    if (!ALLOWED_TABLES.has(table)) throw new Error(`Tabela não permitida: ${table}`);
    const { rowCount } = await db.query(`SELECT 1 FROM ${table} WHERE id = $1 AND family_id = $2`, [id, familyId]);
    if (!rowCount) throw new HttpError(400, `Referência inválida em "${field}"`);
  }
}
