-- One live deposit per student per room. A checkout that is still PENDING and
-- a settled PAID deposit both occupy the (student, room) key; FAILED and
-- CANCELLED orders are history.
UPDATE "payments" p
SET "status" = 'CANCELLED', "response_code" = '24', "updated_at" = now()
WHERE p."status" = 'PENDING'
  AND EXISTS (
    SELECT 1
    FROM "payments" q
    WHERE q."student_id" = p."student_id"
      AND q."room_id" = p."room_id"
      AND q."id" <> p."id"
      AND (
        q."status" = 'PAID'
        OR (
          q."status" = 'PENDING'
          AND (q."created_at", q."id") > (p."created_at", p."id")
        )
      )
  );

-- Prisma cannot express a partial unique index, so the guard lives here only:
-- a second INSERT/UPDATE that would give one student two live deposits on one
-- room now fails with P2002 instead of racing past the service check.
CREATE UNIQUE INDEX "payments_active_deposit_key"
ON "payments" ("student_id", "room_id")
WHERE "status" IN ('PENDING', 'PAID');
