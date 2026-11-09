# Contribuindo com o Family Funds

Obrigado por ajudar! Este guia explica como preparar o ambiente e enviar mudanças.

## Ambiente

Siga a seção [Desenvolvimento](README.md#desenvolvimento) do README. Em resumo: `docker compose up -d postgres`, depois `npm install` em `backend/` e `flutter pub get` em `app/`.

## Fluxo de trabalho

1. Crie uma branch a partir da `main`:
   - `feature/descricao-curta` para novas funcionalidades
   - `bugfix/descricao-curta` para correções
   - `refactor/descricao-curta` para refatorações
2. Faça commits pequenos com mensagens claras, por exemplo `Add recurring transactions` ou `Fix credit card bill period`.
3. Antes de abrir o pull request, rode as verificações:

   ```bash
   cd backend && npm run lint && npm run format:check && npm test
   cd ../app && dart format --set-exit-if-changed lib test && flutter analyze && flutter test
   ```

4. Abra o pull request preenchendo o modelo. O CI precisa estar verde para o merge.

## Convenções

- **API:** JavaScript ESM, Express 5, validação com zod em toda entrada, SQL parametrizado (nunca concatene valores do usuário). Toda consulta filtra por `family_id`.
- **Banco:** cada mudança de schema é uma nova migração numerada em `backend/src/db/migrations/` (nunca edite uma migração já aplicada).
- **Valores em dinheiro:** `NUMERIC(14,2)` no banco, sempre positivos nos lançamentos (o `type` define o sentido).
- **App:** Flutter com Material 3, cores de `FFColors` em `lib/theme.dart`, textos em pt-BR.
- **Testes:** toda regra de negócio nova precisa de teste (`backend/test/` ou `app/test/`).
- **Formatação:** Prettier (API) e `dart format` com largura 120 (app). Use `npm run format` e `dart format lib test`.

## Dados sensíveis

Nunca inclua dados financeiros reais, senhas, tokens ou arquivos `.env` em commits, issues ou prints.
