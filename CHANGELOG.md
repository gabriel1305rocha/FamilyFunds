# Changelog

Todas as mudanças relevantes do projeto ficam registradas aqui. O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

## [Não lançado]

### Adicionado

- API REST em Node.js + PostgreSQL: autenticação, membros da família, contas, cartões de crédito, categorias, lançamentos (com parcelamento e transferências), orçamentos, investimentos, metas e relatórios.
- Nota de saúde financeira (0–100) com recomendações e insights de investimento.
- App Flutter (Android, iOS e web) com painel, lançamentos, contas e cartões, saúde financeira, investimentos e família, em verde e azul.
- Imagem Docker da API e `docker-compose.yml` para rodar API + banco em casa.
- Limite de tentativas no login/cadastro, limite geral de requisições, CORS restrito às origens configuradas e healthcheck com verificação do banco.
- CI no GitHub Actions (lint, formatação, testes, build web e Docker), CodeQL e Dependabot.
- Workflow manual "Release Android": compila o APK e publica numa release do GitHub; job de build Android no CI.
- Endereço do servidor configurável na tela de login; ícone do app em verde e azul.
- Modelos de issue e pull request, guia de contribuição e política de segurança.
