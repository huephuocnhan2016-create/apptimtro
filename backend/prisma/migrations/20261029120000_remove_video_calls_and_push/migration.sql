-- Video calls (Agora) and push notifications (FCM) were removed from the app.

DROP TABLE IF EXISTS "calls";
DROP TABLE IF EXISTS "device_tokens";

DROP TYPE IF EXISTS "CallStatus";
