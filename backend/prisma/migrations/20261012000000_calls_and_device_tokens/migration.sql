CREATE TYPE "CallStatus" AS ENUM ('RINGING', 'ACCEPTED', 'REJECTED', 'MISSED', 'ENDED');

CREATE TABLE "calls" (
    "id" UUID NOT NULL,
    "caller_id" UUID NOT NULL,
    "receiver_id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "channel_name" VARCHAR(128) NOT NULL,
    "status" "CallStatus" NOT NULL DEFAULT 'RINGING',
    "started_at" TIMESTAMPTZ(3),
    "ended_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "calls_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "calls_participants_check" CHECK ("caller_id" <> "receiver_id")
);

CREATE TABLE "device_tokens" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "token" VARCHAR(2048) NOT NULL,
    "platform" VARCHAR(20),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    CONSTRAINT "device_tokens_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "calls_channel_name_key" ON "calls"("channel_name");
CREATE INDEX "calls_caller_id_created_at_idx" ON "calls"("caller_id", "created_at");
CREATE INDEX "calls_receiver_id_status_created_at_idx" ON "calls"("receiver_id", "status", "created_at");
CREATE INDEX "calls_room_id_created_at_idx" ON "calls"("room_id", "created_at");
CREATE UNIQUE INDEX "calls_one_ringing_per_receiver_idx"
ON "calls"("receiver_id") WHERE "status" = 'RINGING';
CREATE UNIQUE INDEX "device_tokens_token_key" ON "device_tokens"("token");
CREATE INDEX "device_tokens_user_id_idx" ON "device_tokens"("user_id");

ALTER TABLE "calls" ADD CONSTRAINT "calls_caller_id_fkey"
FOREIGN KEY ("caller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "calls" ADD CONSTRAINT "calls_receiver_id_fkey"
FOREIGN KEY ("receiver_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "calls" ADD CONSTRAINT "calls_room_id_fkey"
FOREIGN KEY ("room_id") REFERENCES "rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "device_tokens" ADD CONSTRAINT "device_tokens_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
