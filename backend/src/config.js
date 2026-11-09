import 'dotenv/config';

const env = process.env.NODE_ENV ?? 'development';

export const config = {
  env,
  port: Number(process.env.PORT ?? 3000),
  databaseUrl:
    env === 'test'
      ? (process.env.TEST_DATABASE_URL ?? 'postgres://familyfunds:familyfunds@localhost:5432/familyfunds_test')
      : (process.env.DATABASE_URL ?? 'postgres://familyfunds:familyfunds@localhost:5432/familyfunds'),
  jwtSecret: process.env.JWT_SECRET || 'dev-secret-change-me',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '7d',
  // Origens permitidas no CORS, separadas por vírgula. Vazio = qualquer origem.
  corsOrigin: process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',').map((o) => o.trim()) : '*',
  // Tentativas de login/cadastro por IP a cada 15 minutos.
  authRateLimit: Number(process.env.AUTH_RATE_LIMIT ?? (env === 'test' ? 1000 : 20)),
  // Número de proxies reversos à frente da API (para o IP real no rate limit).
  trustProxy: Number(process.env.TRUST_PROXY ?? 0),
};

if (env === 'production' && (config.jwtSecret === 'dev-secret-change-me' || config.jwtSecret.length < 32)) {
  throw new Error('Defina JWT_SECRET com pelo menos 32 caracteres em produção');
}
