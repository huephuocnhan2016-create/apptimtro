
-- CreateTable
CREATE TABLE "conversations" (
    "id" UUID NOT NULL,
    "student_id" UUID NOT NULL,
    "landlord_id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "conversations_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "conversations_student_id_created_at_idx" ON "conversations"("student_id", "created_at");

-- CreateIndex
CREATE INDEX "conversations_landlord_id_created_at_idx" ON "conversations"("landlord_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "conversations_student_id_room_id_key" ON "conversations"("student_id", "room_id");

-- AddForeignKey
ALTER TABLE "conversations" ADD CONSTRAINT "conversations_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "conversations" ADD CONSTRAINT "conversations_landlord_id_fkey" FOREIGN KEY ("landlord_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "conversations" ADD CONSTRAINT "conversations_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

