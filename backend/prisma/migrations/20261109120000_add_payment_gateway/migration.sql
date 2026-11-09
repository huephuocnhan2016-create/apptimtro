-- CreateEnum
CREATE TYPE "PaymentGateway" AS ENUM ('VNPAY', 'MOMO');

-- Each deposit order now remembers which portal it was opened through, so the
-- status poller queries and the cancel refund path use the same gateway.
ALTER TABLE "payments"
  ADD COLUMN "gateway" "PaymentGateway" NOT NULL DEFAULT 'VNPAY',
  ADD COLUMN "gateway_request_id" VARCHAR(64);
