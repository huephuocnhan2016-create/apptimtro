# Trọ Tốt

Flutter app for finding rental rooms in Vietnam. The existing phone OTP
authentication is extended with PostGIS room discovery, favorites, and landlord
room management.

## 1. Project overview

- Mobile client: Flutter, Riverpod, GoRouter, Dio.
- REST API: NestJS, Passport JWT, Prisma.
- Database: PostgreSQL 16 + PostGIS.
- Maps and location: OpenStreetMap via `flutter_map`, Geolocator, Permission
  Handler.
- Room images: local filesystem adapter; storage is abstracted for a future
  Cloudinary/S3 provider.

## 2. Architecture

Flutter features are split into `data`, `domain`, and `presentation` under
`lib/features/`. Widgets use Riverpod repositories; Dio stays in API clients.
The backend uses NestJS modules, DTO validation, JWT and role guards, Prisma
services, and SQL/PostGIS for radius queries. Access tokens are short lived;
refresh tokens are rotated and only their SHA-256 hashes are stored.

## 3. Prerequisites

- Flutter/Dart SDK compatible with `pubspec.yaml`
- Node.js 20+
- Docker Desktop, or PostgreSQL 16 with PostGIS 3.4+
- Android Studio/Xcode for native builds

## 4. PostgreSQL and PostGIS

From `backend`:

```powershell
docker compose up -d postgres
Copy-Item .env.example .env
npm.cmd install
npm.cmd run db:migrate
```

For an existing PostgreSQL server, create a database and ensure the server
allows `CREATE EXTENSION postgis`; configure `DATABASE_URL` accordingly.

## 5. Backend environment

Set the values in `backend/.env`. Generate three different random secrets of at
least 32 characters for JWT access, JWT refresh, and OTP. The committed
`.env.example` contains placeholders only.

| Variable | Purpose |
| --- | --- |
| `NODE_ENV`, `PORT` | Runtime mode and API port |
| `DATABASE_URL` | PostgreSQL connection string |
| `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `OTP_SECRET` | Separate signing/HMAC secrets |
| `ACCESS_TOKEN_SECONDS`, `REFRESH_TOKEN_DAYS`, `OTP_TTL_MINUTES` | Token lifetimes |
| `DEV_OTP_ENABLED` | Development-only OTP output; must be false in production |
| `CORS_ORIGIN` | Comma-separated allowed origins; `*` is rejected in production |
| `PUBLIC_API_URL` | Public backend origin used in local image URLs |
| `NOMINATIM_EMAIL` | Optional contact identifier sent with Nominatim address lookups |
| `VNPAY_TMN_CODE`, `VNPAY_SECURE_SECRET` | VNPay merchant credentials; keep the secret only in `backend/.env` |
| `VNPAY_HASH_ALGORITHM` | Optional signing algorithm (`SHA512` by default) |
| `VNPAY_QUERY_IP_ADDR` | Backend IP sent with status queries; defaults to loopback for local sandbox use |

Set `PUBLIC_API_URL` to an address reachable by the device (for example
`http://10.0.2.2:3000` for Android Emulator, or your development LAN URL).

## 6. OpenStreetMap

The app uses OpenStreetMap tiles through `flutter_map`; no map API key or
billing account is required. An internet connection is required to load tiles.
The app displays OpenStreetMap attribution in its map views.

- Grant location permission and enable device location. For emulator testing,
  select a location in Android Studio Extended Controls.
- On a physical phone, landlords can use **Dùng vị trí GPS hiện tại** in the
  room form to pin the device's current coordinates. Android emulators only
  provide the simulated location configured in Extended Controls.
- Landlords can save a room using its text address even when geocoding is
  unavailable. Rooms without coordinates remain searchable by address but do
  not appear in radius-based or map results until a location is added.
- When saving a room without coordinates, the backend also looks up its
  address with OpenStreetMap Nominatim. The address is sent to that service;
  `NOMINATIM_EMAIL` can be set in `backend/.env` as a contact identifier.
  Lookups are limited to one request per second per backend process. If a
  lookup fails or finds no result, the room is still saved without a pin.
- Existing address-only rooms can be geocoded by editing and saving them again.
- Seed/create AVAILABLE rooms with valid coordinates to see API-backed markers.

## 7. Image storage

The current `StorageService` implementation writes image files to
`backend/uploads/` and returns a URL under `PUBLIC_API_URL`. PostgreSQL stores
only image metadata and URL. `uploads/` is ignored by Git. Replace the provider
behind the storage abstraction to integrate Cloudinary or S3.

## 8. Run development

Backend:

```powershell
cd backend
npm.cmd run start:dev
```

Demo data:

```powershell
cd backend
npx.cmd prisma db seed
```

`prisma/seed.mjs` truncates every table and creates 1 landlord account
(`+84908000001`, "Chủ trọ TP.HCM") plus 100 rooms: 2-3 rooms in each of the 40
communes in `prisma/data/vn_communes_sample.json`, all of them in Thành phố Hồ
Chí Minh. There are no student accounts and no favourites. Coordinates and
commune names come from OpenStreetMap administrative boundaries; regenerate
the sample with `node tools/build_province_membership.mjs` then
`node tools/select_communes.mjs 40 "Hồ Chí Minh"` (needs internet, dumps land
in the ignored `tools/.cache/`). Prices are synthetic.

Flutter, from project root:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Use `http://localhost:3000/api` for a local iOS simulator or the computer's
LAN address for a physical device.

## 9. Android and iOS builds

```powershell
flutter build apk --dart-define=API_BASE_URL=YOUR_API_URL

flutter build ios --dart-define=API_BASE_URL=YOUR_API_URL
```

Configure signing, release app identifiers, and location descriptions before
publishing. Do not use a development API over plain HTTP for a release build.

## 10. API documentation

With backend running, open `http://localhost:3000/docs`. Requests use a
consistent `{ success, message, data }` envelope; errors use
`{ success: false, message, code, data: null }`.

### Authentication

- `POST /api/auth/send-otp`
- `POST /api/auth/verify-otp`
- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/refresh`
- `POST /api/auth/logout`
- `GET /api/auth/me`
- `GET /api/users/me`

### Rooms and favorites

- `GET /api/rooms/nearby`, `/api/rooms/search`, `/api/rooms/filter`
- `GET /api/rooms/:id`
- `POST /api/rooms/:id/favorite`, `DELETE /api/rooms/:id/favorite`
- `GET /api/users/me/favorites`
- Landlord: `POST /api/rooms`, `GET /api/rooms/my`, `PUT/DELETE /api/rooms/:id`
- Landlord: `POST/DELETE /api/rooms/:id/images`,
  `PATCH /api/rooms/:id/availability`

Nearby accepts `latitude`, `longitude`, and `radius` in km. Search/filter accept
`query`, `minPrice`, `maxPrice`, `minArea`, `maxArea`, `availableRooms`,
comma-separated `amenities`, optional coordinates and `radius`; sort accepts
`distance`, `price_asc`, `price_desc`, `newest`. Radius search is executed in
PostGIS, not in the client.

### Payments

- `POST /api/payment/orders` creates an authenticated VNPay QR order for a room.
  The amount is read from the room price in PostgreSQL; clients cannot set it.
- `GET /api/payment/orders/:txnRef/status` checks the authenticated student's
  order against VNPay and updates it to `PAID` only after response verification.
- The integration currently targets the VNPay sandbox and the app polls the
  status while displaying the QR. Configure `VNPAY_TMN_CODE` and
  `VNPAY_SECURE_SECRET` in `backend/.env`; never commit either value.

## 11. Database structure

- `users`, `refresh_tokens`, `phone_verifications`
- Rooms: `rooms`, `room_images`, `favorites`
- Payments: `payments` (VNPay order, amount, status and transaction metadata)
- `rooms.location` is PostGIS geography(Point,4326), maintained from latitude /
  longitude with a GiST index.

The video call and push notification tables (`calls`, `device_tokens`) were
removed; migration `20261029120000_remove_video_calls_and_push` drops them.

## 12. Verification

```powershell
flutter analyze
flutter test
cd backend
npm.cmd test
npm.cmd run build
npx.cmd prisma validate
npx.cmd prisma migrate status
```

## 13. Current provider limitations

The payment workflow currently supports sandbox QR orders and status polling;
payment history, IPN, refunds, and automatic expiration are not included. Local
image storage is intended for development, not horizontally scaled production
deployments.

## 14. Production recommendations

Use HTTPS, restrict CORS, rotate secrets, use a production OTP/SMS provider,
persistent shared storage (S3/Cloudinary), durable distributed rate limiting,
database backups, observability, and end-to-end device testing. Do not enable
`DEV_OTP_ENABLED` in production.
