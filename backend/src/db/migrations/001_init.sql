-- Family Funds - schema inicial

CREATE TABLE families (
  id          SERIAL PRIMARY KEY,
  name        TEXT NOT NULL,
  currency    CHAR(3) NOT NULL DEFAULT 'BRL',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Membros da família. Um membro pode ou não ter login (email/senha).
CREATE TABLE members (
  id             SERIAL PRIMARY KEY,
  family_id      INTEGER NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  name           TEXT NOT NULL,
  email          TEXT UNIQUE,
  password_hash  TEXT,
  role           TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'member')),
  color          TEXT NOT NULL DEFAULT '#1E88E5',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX members_family_idx ON members(family_id);

-- Contas: conta corrente, poupança, cartão de crédito, dinheiro, investimento.
CREATE TABLE accounts (
  id               SERIAL PRIMARY KEY,
  family_id        INTEGER NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  owner_id         INTEGER REFERENCES members(id) ON DELETE SET NULL, -- NULL = conta conjunta
  name             TEXT NOT NULL,
  type             TEXT NOT NULL CHECK (type IN ('checking', 'savings', 'credit_card', 'cash', 'investment')),
  institution      TEXT,
  initial_balance  NUMERIC(14, 2) NOT NULL DEFAULT 0,
  credit_limit     NUMERIC(14, 2),
  closing_day      SMALLINT CHECK (closing_day BETWEEN 1 AND 31),
  due_day          SMALLINT CHECK (due_day BETWEEN 1 AND 31),
  color            TEXT NOT NULL DEFAULT '#00A86B',
  archived         BOOLEAN NOT NULL DEFAULT false,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX accounts_family_idx ON accounts(family_id);

CREATE TABLE categories (
  id         SERIAL PRIMARY KEY,
  family_id  INTEGER NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  kind       TEXT NOT NULL CHECK (kind IN ('income', 'expense')),
  essential  BOOLEAN NOT NULL DEFAULT false,
  icon       TEXT NOT NULL DEFAULT 'category',
  color      TEXT NOT NULL DEFAULT '#26A69A',
  UNIQUE (family_id, name, kind)
);

-- Lançamentos. Valores sempre positivos; o "type" define o sentido.
-- Transferências (ex.: pagamento de fatura) usam account_id -> transfer_account_id.
CREATE TABLE transactions (
  id                   SERIAL PRIMARY KEY,
  family_id            INTEGER NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  account_id           INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  member_id            INTEGER REFERENCES members(id) ON DELETE SET NULL,
  category_id          INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  type                 TEXT NOT NULL CHECK (type IN ('income', 'expense', 'transfer')),
  amount               NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
  description          TEXT NOT NULL DEFAULT '',
  date                 DATE NOT NULL,
  transfer_account_id  INTEGER REFERENCES accounts(id) ON DELETE CASCADE,
  installment_number   SMALLINT,
  installment_total    SMALLINT,
  installment_group    UUID,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (type <> 'transfer' OR (transfer_account_id IS NOT NULL AND transfer_account_id <> account_id))
);
CREATE INDEX transactions_family_date_idx ON transactions(family_id, date);
CREATE INDEX transactions_account_idx ON transactions(account_id);
CREATE INDEX transactions_transfer_account_idx ON transactions(transfer_account_id);

-- Orçamento mensal por categoria (month = 'YYYY-MM').
CREATE TABLE budgets (
  id           SERIAL PRIMARY KEY,
  family_id    INTEGER NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  category_id  INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  month        CHAR(7) NOT NULL CHECK (month ~ '^\d{4}-(0[1-9]|1[0-2])$'),
  amount       NUMERIC(14, 2) NOT NULL CHECK (amount >= 0),
  UNIQUE (family_id, category_id, month)
);

CREATE TABLE investments (
  id               SERIAL PRIMARY KEY,
  family_id        INTEGER NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  member_id        INTEGER REFERENCES members(id) ON DELETE SET NULL,
  name             TEXT NOT NULL,
  type             TEXT NOT NULL CHECK (type IN ('fixed_income', 'treasury', 'stocks', 'reits', 'funds', 'crypto', 'pension', 'other')),
  institution      TEXT,
  liquidity        TEXT NOT NULL DEFAULT 'daily' CHECK (liquidity IN ('daily', 'monthly', 'maturity')),
  invested_amount  NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (invested_amount >= 0),
  current_value    NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (current_value >= 0),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX investments_family_idx ON investments(family_id);

CREATE TABLE goals (
  id              SERIAL PRIMARY KEY,
  family_id       INTEGER NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  target_amount   NUMERIC(14, 2) NOT NULL CHECK (target_amount > 0),
  current_amount  NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (current_amount >= 0),
  deadline        DATE,
  color           TEXT NOT NULL DEFAULT '#1E88E5',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
