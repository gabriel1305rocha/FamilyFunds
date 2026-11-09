// Categorias criadas automaticamente para toda nova família.
export const DEFAULT_CATEGORIES = [
  { name: 'Salário', kind: 'income', essential: false, icon: 'work', color: '#00A86B' },
  { name: 'Renda extra', kind: 'income', essential: false, icon: 'savings', color: '#43A047' },
  { name: 'Rendimentos', kind: 'income', essential: false, icon: 'trending_up', color: '#26A69A' },
  { name: 'Moradia', kind: 'expense', essential: true, icon: 'home', color: '#1565C0' },
  { name: 'Mercado', kind: 'expense', essential: true, icon: 'shopping_cart', color: '#1E88E5' },
  { name: 'Transporte', kind: 'expense', essential: true, icon: 'directions_car', color: '#039BE5' },
  { name: 'Saúde', kind: 'expense', essential: true, icon: 'favorite', color: '#00897B' },
  { name: 'Educação', kind: 'expense', essential: true, icon: 'school', color: '#00ACC1' },
  { name: 'Contas e serviços', kind: 'expense', essential: true, icon: 'receipt', color: '#0277BD' },
  { name: 'Restaurantes', kind: 'expense', essential: false, icon: 'restaurant', color: '#2E7D32' },
  { name: 'Lazer', kind: 'expense', essential: false, icon: 'celebration', color: '#66BB6A' },
  { name: 'Compras', kind: 'expense', essential: false, icon: 'shopping_bag', color: '#4DB6AC' },
  { name: 'Assinaturas', kind: 'expense', essential: false, icon: 'subscriptions', color: '#5C6BC0' },
  { name: 'Outros', kind: 'expense', essential: false, icon: 'category', color: '#78909C' },
];

export async function createDefaultCategories(db, familyId) {
  for (const c of DEFAULT_CATEGORIES) {
    await db.query(
      'INSERT INTO categories (family_id, name, kind, essential, icon, color) VALUES ($1, $2, $3, $4, $5, $6)',
      [familyId, c.name, c.kind, c.essential, c.icon, c.color],
    );
  }
}
