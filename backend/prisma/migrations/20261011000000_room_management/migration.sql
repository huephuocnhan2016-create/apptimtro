CREATE TYPE "RoomStatus" AS ENUM ('PENDING', 'AVAILABLE', 'FULL', 'HIDDEN');

CREATE TABLE "rooms" (
    "id" UUID NOT NULL,
    "landlord_id" UUID NOT NULL,
    "title" VARCHAR(160) NOT NULL,
    "description" TEXT NOT NULL,
    "address" VARCHAR(500) NOT NULL,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "location" geography(Point, 4326) NOT NULL,
    "price" DECIMAL(12,2) NOT NULL,
    "area" DOUBLE PRECISION NOT NULL,
    "total_rooms" INTEGER NOT NULL,
    "available_rooms" INTEGER NOT NULL,
    "electricity_price" DECIMAL(12,2) NOT NULL,
    "water_price" DECIMAL(12,2) NOT NULL,
    "internet_price" DECIMAL(12,2) NOT NULL,
    "deposit" DECIMAL(12,2) NOT NULL,
    "status" "RoomStatus" NOT NULL DEFAULT 'AVAILABLE',
    "amenities" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    CONSTRAINT "rooms_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "rooms_room_counts_check" CHECK (
        "total_rooms" > 0 AND "available_rooms" >= 0 AND
        "available_rooms" <= "total_rooms"
    ),
    CONSTRAINT "rooms_coordinates_check" CHECK (
        "latitude" BETWEEN -90 AND 90 AND "longitude" BETWEEN -180 AND 180
    ),
    CONSTRAINT "rooms_nonnegative_values_check" CHECK (
        "price" >= 0 AND "area" > 0 AND "electricity_price" >= 0 AND
        "water_price" >= 0 AND "internet_price" >= 0 AND "deposit" >= 0
    )
);

CREATE FUNCTION "rooms_set_location"() RETURNS TRIGGER AS $$
BEGIN
    NEW."location" := ST_SetSRID(
        ST_MakePoint(NEW."longitude", NEW."latitude"), 4326
    )::geography;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER "rooms_location_trigger"
BEFORE INSERT OR UPDATE OF "latitude", "longitude" ON "rooms"
FOR EACH ROW EXECUTE FUNCTION "rooms_set_location"();

CREATE TABLE "room_images" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "image_url" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "room_images_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "favorites" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "favorites_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "rooms_landlord_id_created_at_idx" ON "rooms"("landlord_id", "created_at");
CREATE INDEX "rooms_status_price_idx" ON "rooms"("status", "price");
CREATE INDEX "rooms_available_rooms_idx" ON "rooms"("available_rooms");
CREATE INDEX "rooms_location_gist_idx" ON "rooms" USING GIST ("location");
CREATE INDEX "room_images_room_id_sort_order_idx" ON "room_images"("room_id", "sort_order");
CREATE UNIQUE INDEX "favorites_user_id_room_id_key" ON "favorites"("user_id", "room_id");
CREATE INDEX "favorites_user_id_created_at_idx" ON "favorites"("user_id", "created_at");

ALTER TABLE "rooms" ADD CONSTRAINT "rooms_landlord_id_fkey"
FOREIGN KEY ("landlord_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "room_images" ADD CONSTRAINT "room_images_room_id_fkey"
FOREIGN KEY ("room_id") REFERENCES "rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "favorites" ADD CONSTRAINT "favorites_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "favorites" ADD CONSTRAINT "favorites_room_id_fkey"
FOREIGN KEY ("room_id") REFERENCES "rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;
