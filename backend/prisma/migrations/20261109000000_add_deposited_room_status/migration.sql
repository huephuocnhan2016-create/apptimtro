-- A paid deposit reserves one of the listing's rooms.
ALTER TYPE "RoomStatus" ADD VALUE IF NOT EXISTS 'DEPOSITED' AFTER 'FULL';
