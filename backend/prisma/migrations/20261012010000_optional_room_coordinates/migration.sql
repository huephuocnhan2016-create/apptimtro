ALTER TABLE "rooms"
    ALTER COLUMN "latitude" DROP NOT NULL,
    ALTER COLUMN "longitude" DROP NOT NULL,
    ALTER COLUMN "location" DROP NOT NULL;

ALTER TABLE "rooms"
    DROP CONSTRAINT "rooms_coordinates_check",
    ADD CONSTRAINT "rooms_coordinates_check" CHECK (
        ("latitude" IS NULL AND "longitude" IS NULL) OR
        (
            "latitude" IS NOT NULL AND
            "longitude" IS NOT NULL AND
            "latitude" BETWEEN -90 AND 90 AND
            "longitude" BETWEEN -180 AND 180
        )
    );

CREATE OR REPLACE FUNCTION "rooms_set_location"() RETURNS TRIGGER AS $$
BEGIN
    IF NEW."latitude" IS NULL AND NEW."longitude" IS NULL THEN
        NEW."location" := NULL;
    ELSE
        NEW."location" := ST_SetSRID(
            ST_MakePoint(NEW."longitude", NEW."latitude"), 4326
        )::geography;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
