-- CreateTable
CREATE TABLE "room_reviews" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "student_id" UUID NOT NULL,
    "rating" INTEGER NOT NULL,
    "comment" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "room_reviews_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "room_reviews_student_id_room_id_key" ON "room_reviews"("student_id", "room_id");

-- CreateIndex
CREATE INDEX "room_reviews_room_id_created_at_idx" ON "room_reviews"("room_id", "created_at");

-- AddForeignKey
ALTER TABLE "room_reviews" ADD CONSTRAINT "room_reviews_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_reviews" ADD CONSTRAINT "room_reviews_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Prisma has no check constraint, so the 1..5 star range lives here: the
-- service validates first, this stops anything that reaches the table another
-- way (a hand-run script, a future migration).
ALTER TABLE "room_reviews" ADD CONSTRAINT "room_reviews_rating_range_check" CHECK ("rating" >= 1 AND "rating" <= 5);
