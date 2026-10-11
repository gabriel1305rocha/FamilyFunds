import 'dotenv/config';

const env = process.env.NODE_ENV ?? 'development';

export const config = {
  env,
  port: Number(process.env.PORT ?? 3000),
  databaseUrl:
    env === 'test'
      ? process.env.TEST_DATABASE_URL ?? 'postgres://familyfunds:familyfunds@localhost:5432/familyfunds_test'
      : process.env.DATABASE_URL ?? 'postgres://familyfunds:familyfunds@localhost:5432/familyfunds',
  jwtSecret: process.env.JWT_SECRET ?? 'dev-secret-change-me',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '7d',
};

if (env === 'production' && config.jwtSecret === 'dev-secret-change-me') {
  throw new Error('JWT_SECRET must be set in production');
}
