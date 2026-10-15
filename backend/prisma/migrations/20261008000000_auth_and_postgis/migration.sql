CREATE EXTENSION IF NOT EXISTS "postgis";

CREATE TYPE "UserRole" AS ENUM ('STUDENT', 'LANDLORD', 'ADMIN');

CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "phone" VARCHAR(16) NOT NULL,
    "email" VARCHAR(320),
    "full_name" VARCHAR(120),
    "avatar_url" TEXT,
    "role" "UserRole" NOT NULL DEFAULT 'STUDENT',
    "is_verified" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "refresh_tokens" (
    "id" UUID NOT NULL,
    "token_hash" CHAR(64) NOT NULL,
    "user_id" UUID NOT NULL,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "revoked_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "phone_verifications" (
    "id" UUID NOT NULL,
    "phone" VARCHAR(16) NOT NULL,
    "role" "UserRole" NOT NULL,
    "otp_hash" CHAR(64) NOT NULL,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "verified_at" TIMESTAMPTZ(3),
    "consumed_at" TIMESTAMPTZ(3),
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "phone_verifications_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "users_phone_key" ON "users"("phone");
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");
CREATE UNIQUE INDEX "refresh_tokens_token_hash_key" ON "refresh_tokens"("token_hash");
CREATE INDEX "refresh_tokens_user_id_revoked_at_idx" ON "refresh_tokens"("user_id", "revoked_at");
CREATE INDEX "phone_verifications_phone_created_at_idx" ON "phone_verifications"("phone", "created_at");

ALTER TABLE "refresh_tokens"
ADD CONSTRAINT "refresh_tokens_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
