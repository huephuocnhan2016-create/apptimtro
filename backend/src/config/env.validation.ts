import * as Joi from 'joi';

export const environmentSchema = Joi.object({
  NODE_ENV: Joi.string()
    .valid('development', 'test', 'production')
    .default('development'),
  PORT: Joi.number().port().default(3000),
  DATABASE_URL: Joi.string().uri({ scheme: ['postgres', 'postgresql'] }).required(),
  JWT_ACCESS_SECRET: Joi.string().min(32).required(),
  JWT_REFRESH_SECRET: Joi.string().min(32).required(),
  OTP_SECRET: Joi.string().min(32).required(),
  ACCESS_TOKEN_SECONDS: Joi.number().integer().min(60).default(900),
  REFRESH_TOKEN_DAYS: Joi.number().integer().min(1).default(30),
  OTP_TTL_MINUTES: Joi.number().integer().min(1).max(15).default(5),
  DEV_OTP_ENABLED: Joi.boolean()
    .truthy('true')
    .falsy('false')
    .default(false)
    .when('NODE_ENV', { is: 'production', then: Joi.valid(false) }),
  CORS_ORIGIN: Joi.string().default('*').when('NODE_ENV', {
    is: 'production',
    then: Joi.string().required().invalid('*'),
  }),
  PUBLIC_API_URL: Joi.string().uri({ scheme: ['http', 'https'] }).optional(),
  NOMINATIM_EMAIL: Joi.string().email().optional(),
  FIREBASE_PROJECT_ID: Joi.string().required(),
  FIREBASE_CLIENT_EMAIL: Joi.string().required(),
  FIREBASE_PRIVATE_KEY: Joi.string().required(),
  VNPAY_TMN_CODE: Joi.string().allow('').optional(),
  VNPAY_SECURE_SECRET: Joi.string().allow('').optional(),
  VNPAY_HASH_ALGORITHM: Joi.string().valid('SHA512', 'SHA256').default('SHA512'),
  VNPAY_QUERY_IP_ADDR: Joi.string().ip().default('127.0.0.1'),
  MOMO_PARTNER_CODE: Joi.string().allow('').optional(),
  MOMO_ACCESS_KEY: Joi.string().allow('').optional(),
  MOMO_SECRET_KEY: Joi.string().allow('').optional(),
  MOMO_ENDPOINT: Joi.string()
    .uri({ scheme: ['http', 'https'] })
    .allow('')
    .optional(),
  MOMO_RETURN_URL: Joi.string()
    .uri({ scheme: ['http', 'https'] })
    .allow('')
    .optional(),
  MOMO_IPN_URL: Joi.string()
    .uri({ scheme: ['http', 'https'] })
    .allow('')
    .optional(),
  MOMO_REQUEST_TYPE: Joi.string()
    .valid('payWithApp', 'payWithQrCode', 'payWithATM', 'pay')
    .allow('')
    .default('payWithApp'),
});
