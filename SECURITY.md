# Segurança

O Family Funds guarda dados financeiros da família, então segurança é prioridade.

## Como relatar uma vulnerabilidade

**Não abra uma issue pública.** Use o [relato privado de vulnerabilidades do GitHub](https://github.com/gabriel1305rocha/FamilyFunds/security/advisories/new) com a descrição do problema e os passos para reproduzir. A resposta inicial vem em até 7 dias.

## O que o projeto já faz

- Senhas com hash bcrypt; autenticação por JWT com expiração.
- Limite de tentativas de login e cadastro por IP (`AUTH_RATE_LIMIT`).
- Todas as consultas isoladas por família e com SQL parametrizado; IDs referenciados são validados contra a família do usuário.
- Validação de toda entrada com zod; cabeçalhos de segurança com Helmet.
- A API se recusa a subir em produção sem um `JWT_SECRET` forte (32+ caracteres).
- CodeQL e Dependabot ativos no repositório.

## Recomendações para hospedar em casa

- Gere segredos fortes: `openssl rand -hex 32` para `JWT_SECRET` e uma senha própria em `POSTGRES_PASSWORD`.
- Não exponha a porta do PostgreSQL. O `docker-compose.yml` publica o banco só em `127.0.0.1`.
- Para acesso fora de casa, use HTTPS (Caddy/Nginx com certificado) ou uma VPN/túnel (Tailscale, WireGuard, Cloudflare Tunnel). Nunca exponha a API em HTTP puro na internet.
- Atrás de um proxy reverso, configure `TRUST_PROXY=1` para o limite de tentativas usar o IP real.
- Restrinja `CORS_ORIGIN` ao endereço do app web, se usar a versão web.
- Faça backup do volume do banco (`docker compose exec postgres pg_dump -U familyfunds familyfunds > backup.sql`) e guarde-o criptografado.
