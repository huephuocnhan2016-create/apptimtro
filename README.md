# Trọ Tốt

A Flutter app for finding and depositing rental rooms in Vietnam, built for the
CMP177 mobile programming course. Students sign in with a phone number and OTP,
search rooms by keyword, filter, map radius or amenities, chat with the
landlord, place a deposit through VNPay or MoMo, and review a room once they
have deposited. Landlords register, publish rooms with photos, and manage
availability.

Repository: https://github.com/huephuocnhan2016-create/apptimtro
Backend: NestJS + Prisma + PostgreSQL/PostGIS · Chat: Firebase Auth + Firestore
· Client: Flutter, Riverpod, go_router, Dio.

## 1. Project overview

| Component | Technology / Library | Purpose |
| --- | --- | --- |
| Mobile app | Flutter 3 / Dart | The app itself (required by the course) |
| State management | Riverpod 3 | Providers, notifiers, repositories |
| Navigation | go_router | Bottom-nav shell, deep links, auth redirect guard |
| HTTP client | Dio | Calls the REST API |
| Local storage | flutter_secure_storage | Access and refresh tokens |
| Backend / API | NestJS 11, Passport JWT, class-validator | REST API, guards, rate limiting |
| ORM | Prisma 6 + migrations | Schema and data access |
| Database | PostgreSQL 16 + PostGIS | Rooms, users, deposits, geo queries |
| Chat | Firebase Auth (custom token) + Cloud Firestore | Student↔landlord messaging |
| Payments | VNPay and MoMo gateway adapters | Deposit checkout and result handling |
| Maps | `flutter_map` with OpenStreetMap tiles, Geolocator, Permission Handler | Map tab, radius search, room pinning |
| Reviews | NestJS `ReviewsModule` + `room_reviews` | Ratings from students who deposited |

Room images go through a local filesystem adapter; the storage abstraction is
there so a Cloudinary/S3 provider can replace it later.

### Feature list and status

Grouped by role, with the honest state of each item.

| Role | Feature | Status |
| --- | --- | --- |
| Sinh viên | Đăng ký / đăng nhập bằng số điện thoại + OTP, chọn vai trò | Hoàn thành |
| Sinh viên | Trang chủ: thanh tìm kiếm và phòng gợi ý | Hoàn thành |
| Sinh viên | Tìm kiếm, bộ lọc (giá, diện tích, tiện nghi, số phòng còn) và sắp xếp | Hoàn thành |
| Sinh viên | Tìm phòng bán kính gần, lọc bằng PostGIS | Hoàn thành |
| Sinh viên | Bản đồ phòng (OpenStreetMap, `flutter_map`) | Hoàn thành |
| Sinh viên | Chi tiết phòng: ảnh, giá, tiện nghi, chủ trọ, số điện thoại | Hoàn thành |
| Sinh viên | Yêu thích phòng | Hoàn thành |
| Sinh viên | Chat realtime với chủ trọ (Firestore) | Hoàn thành |
| Sinh viên | Đặt cọc qua VNPay hoặc MoMo, chọn cổng thanh toán | Hoàn thành |
| Sinh viên | Danh sách phòng đã đặt cọc và hủy cọc | Hoàn thành |
| Sinh viên | Đánh giá phòng (chỉ sau khi đã cọc) | Hoàn thành |
| Chủ trọ | Đăng ký, đăng nhập | Hoàn thành |
| Chủ trọ | Thêm / sửa / xóa phòng, bật bán, upload ảnh | Hoàn thành |
| Chủ trọ | Dashboard danh sách phòng của mình | Hoàn thành |
| Chủ trọ | Chat với sinh viên | Hoàn thành |
| — | Gửi OTP bằng nhà mạng SMS thật | Chưa hoàn thiện (xem mục 13) |
| — | Hoàn tiền, lịch sử thanh toán, tự hết hạn đơn cọc | Chưa xây dựng |
| — | Push notification, video call | Đã bỏ khỏi phạm vi đồ án |

## 2. Architecture

Flutter features are split into `data`, `domain`, and `presentation` under
`lib/features/`. Widgets use Riverpod repositories; Dio stays in API clients.
The backend uses NestJS modules, DTO validation, JWT and role guards, Prisma
services, and SQL/PostGIS for radius queries. Access tokens are short lived;
refresh tokens are rotated and only their SHA-256 hashes are stored.
Chat messages are not stored in PostgreSQL: the backend mints a short-lived
Firebase custom token for the logged-in user and the app reads and writes
Firestore documents directly, under the Firestore security rules.

### Repository layout

```
lib/
  core/        theme tokens, Dio client, router + auth guard, secure storage
  features/    auth, home, rooms, map, favorites, chat, payment, landlord,
               profile — each split into data / domain / presentation
  shared/      formatting helpers and reusable widgets
test/          Flutter widget and unit tests
backend/
  src/modules/ auth, users, rooms, chat, payment, reviews
  src/config/  env schema — every variable the API needs is declared here
  prisma/      schema, migrations, seed script, sample room images
  uploads/     room images saved at runtime (ignored by Git)
tools/         scripts that build the OpenStreetMap commune dataset, plus the
               emulator location bridge used for testing
```

## 3. Prerequisites

- Flutter/Dart SDK compatible with `pubspec.yaml`
- Node.js 20+
- Docker Desktop, or PostgreSQL 16 with PostGIS 3.4+
- A Firebase project with Firestore enabled (the chat feature will not start
  without one; see section 5)
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
| `PUBLIC_API_URL` | Public backend origin used in local image URLs and the VNPay return/checkout URLs |
| `NOMINATIM_EMAIL` | Optional contact identifier sent with Nominatim address lookups |
| `VNPAY_TMN_CODE`, `VNPAY_SECURE_SECRET` | VNPay merchant credentials; keep the secret only in `backend/.env` |
| `VNPAY_HASH_ALGORITHM` | Optional signing algorithm (`SHA512` by default) |
| `VNPAY_QUERY_IP_ADDR` | Backend IP sent with status queries; defaults to loopback for local sandbox use |
| `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` | **Required** — the service account the backend uses to mint chat tokens. The API refuses to boot without them |
| `MOMO_PARTNER_CODE`, `MOMO_ACCESS_KEY`, `MOMO_SECRET_KEY` | MoMo merchant credentials; leave empty to use the dev stand-in portal |
| `MOMO_ENDPOINT`, `MOMO_RETURN_URL`, `MOMO_IPN_URL` | MoMo gateway host and the callbacks it redirects to |
| `MOMO_REQUEST_TYPE` | `payWithApp` (default), `payWithQrCode`, `payWithATM` or `pay` |

Set `PUBLIC_API_URL` to an address reachable by the device (for example
`http://10.0.2.2:3000` for Android Emulator, or your development LAN URL).

`FIREBASE_PRIVATE_KEY` is a real signing key. Keep it in `backend/.env` only —
`.env` is ignored by Git and has never been committed. Copy the three values
from the service account under **Firebase console → Project settings →
Service accounts**; `FIREBASE_CLIENT_EMAIL` and `FIREBASE_PROJECT_ID` also
appear in `android/app/google-services.json`, which is committed because it is
client configuration, not a secret.

The Flutter client reads the same Firebase project from
`android/app/google-services.json` and `lib/firebase_options.dart`. There is no
iOS plist in this repository; regenerate the whole set with
`flutterfire configure` if you point the app at a different project. Chat
security rules live in the Firebase console, not in this repository, so a fresh
project needs them published before the chat tab works.

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
- `GET /api/auth/firebase-token` — a short-lived Firebase custom token for the
  signed-in user, used by the app to open a Firestore session for chat

### Chat

- `GET /api/chat/conversations` — the signed-in user's conversations, with the
  peer's name/avatar and the room's title/first image
- `POST /api/chat/conversations` — open (or reuse) the conversation with the
  landlord of a room

Messages themselves never pass through the REST API. The app signs in to
Firebase with the token above and reads/writes Firestore directly, so message
streaming is realtime and the backend stays out of the hot path. Access is
governed by the Firestore security rules configured in the Firebase console.

### Reviews

- `GET /api/rooms/:roomId/reviews` — public list of student reviews
- `POST /api/rooms/:roomId/reviews` — rate a room; limited to 10 requests a
  minute and rejected with `403` unless the caller is a student holding a
  `PAID` deposit on that room

`GET /api/rooms/:id` also returns the aggregate rating, the review count and a
`canReview` flag, which is what the app uses to show or hide the review dialog.

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

### Deposits

- `POST /api/payment/orders` creates an authenticated deposit order. It takes
  `roomId` and an optional `gateway` (`VNPAY` by default, or `MOMO`) and returns
  the server-signed portal payload together with `txnRef`, `amount` and
  `orderInfo`. The amount is read from the room deposit in PostgreSQL; clients
  cannot set it. A listing that is already `DEPOSITED` or has no free room left
  answers `409`.
- The app opens `payUrl` in the device browser (a Chrome custom tab refuses
  `intent://` links to another package, so the hand-back button would be dead).
  VNPay then redirects to `GET /api/payment/vnpay/return`, a public endpoint
  that re-checks the checksum and renders the result page. That page offers a
  **Về ứng dụng** button, a `trotot://payment-return?txnRef=…` link the app's
  manifest claims; the router turns it into `/payment?txnRef=…`, which re-reads
  the order and shows the result screen, so the shopper lands on their deposit
  instead of the splash screen. Returning to the foreground also refreshes the
  order, and the screen keeps polling every 3 seconds while it is pending.
  Configure `VNPAY_TMN_CODE`, `VNPAY_SECURE_SECRET` and a device-reachable
  `PUBLIC_API_URL` (the redirect target) in `backend/.env`; never commit either
  credential.
- MoMo is the second gateway and the app asks which one to use before it
  creates the order. `POST /api/payment/orders` with `gateway: MOMO` returns a
  signed MoMo `payUrl` plus a `deeplink` and a `qrCodeUrl`; the payment screen
  shows the QR in-app and offers the app-to-app link. MoMo calls back to
  `GET /api/payment/momo/return` (browser, human-readable result page and the
  same **Về ứng dụng** hand-back) and to `POST /api/payment/momo/ipn` (server
  to server, signature-verified, the authoritative status update). Configure
  `MOMO_PARTNER_CODE`, `MOMO_ACCESS_KEY`, `MOMO_SECRET_KEY`, `MOMO_ENDPOINT`,
  `MOMO_RETURN_URL` and `MOMO_IPN_URL`; the result-code table the app displays
  comes from MoMo's own documentation.
- `GET /api/payment/orders/:txnRef/status` verifies the order against the
  gateway recorded on it (VNPay `queryDr`, or MoMo `queryOrder`) and returns
  the full transaction view — status, amount, bank, `transactionNo`,
  `responseCode`, `payDate` and a Vietnamese message. It moves the order to
  `PAID` only after a verified success code.
- `POST /api/payment/orders/:txnRef/cancel` lets the order's own student drop
  the deposit: the order turns `CANCELLED` with `responseCode` `24`, and a
  deposit that had already been paid gives its room back (`availableRooms`
  increments, and a `DEPOSITED` listing returns to `AVAILABLE`). With real
  merchant credentials a `PAID` order answers `409` instead — getting that
  money back needs the VNPay refund API, which this build does not call.
- A `PAID` deposit books one of the listing's rooms: `availableRooms` drops by
  one, and when it reaches zero the listing turns `DEPOSITED`. Deposited
  listings stay in search results and favourites so students can see they are
  taken, but no further deposit is accepted until the landlord raises
  availability again.
- `GET /api/payment/deposits` returns the student's own `PAID` orders, newest
  first, each with the room's id, title, address, price, deposit and first
  image. The app shows it under **Cá nhân → Phòng đã đặt cọc**
  (`/deposits`), and an entry opens `/rooms/:id`. Pending checkouts are not
  listed because they have not booked a room yet. Every row also carries a
  **Hủy cọc** button that asks for confirmation, calls
  `POST /api/payment/orders/:txnRef/cancel` and reloads the list, so a deposit
  made from another device can still be dropped here.
- A student holds at most one deposit per listing. `POST /api/payment/orders`
  answers `409` when they already have a `PAID` order on that room, and
  `GET /api/rooms/:id` reports it as `hasDeposit` so the app can disable the
  Đặt cọc button instead of sending them to a gate that will refuse them. Two
  checkouts opened before the first one paid still cannot both book: the second
  turns `FAILED` with `responseCode` `97` and leaves `availableRooms` alone.
- Without merchant credentials a non-production backend hands the app a
  stand-in portal page, `GET /api/payment/dev/checkout/:txnRef`, styled like the
  VNPay page. Its Xác nhận / Hủy links close the order through
  `GET /api/payment/dev/return/:txnRef?code=00|24`, so both the success and the
  cancellation path are testable; production still answers `503`.
- `POST /api/payment/dev/succeed/:txnRef` with the student's access token marks
  a pending order `PAID` directly. It only exists while the dev stand-in is
  active — with real credentials configured it answers `404`.

## 11. Database structure

- `users`, `refresh_tokens`, `phone_verifications`
- Rooms: `rooms`, `room_images`, `favorites`
- Chat: `conversations` (metadata only — the messages themselves live in
  Firestore, not in PostgreSQL)
- Reviews: `room_reviews` (one review per student per room)
- Payments: `payments` (gateway, amount, status, `transactionNo`,
  `responseCode` and the rest of the portal metadata). A partial unique index,
  `payments_active_deposit_key`, keeps a student to at most one live order per
  room.
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

## 13. Known limitations

Stated plainly, because the graded demo should not oversell the build.

- **OTP delivery.** There is no SMS provider integrated. Outside production the
  code logs the OTP and, with `DEV_OTP_ENABLED=true`, returns it in the API
  response so the app can show it — that is how the app is meant to be run and
  demoed. In production `POST /api/auth/send-otp` answers `503` until a real
  provider is wired into `OTP_SENDER`.
- **Payments.** The deposit flow uses the hosted VNPay portal and MoMo, plus
  status polling and MoMo's server-to-server IPN. There is no refund call, no
  payment history screen, and no job that expires a `PENDING` order on a timer;
  such an order is reused or cancelled when the student comes back. Cancelling
  returns the room, but money a gateway already captured cannot be pushed back
  by this build.
- **Hand-back from the portal.** The result page offers a `trotot://` link the
  app's manifest claims, and the app also re-reads the order when it returns to
  the foreground. It still depends on the browser honouring that intent; a
  browser that blocks it leaves the student reopening the app by hand.
- **Chat** needs a Firebase project and its Firestore rules; the rules are
  configured in the Firebase console and are not part of this repository.
- **Images** are stored on the backend's own filesystem, which suits local
  development, not a horizontally scaled deployment.
- **Push notifications and in-app video calls** were dropped from the scope;
  their tables and code are gone rather than disabled.

## 14. Production recommendations

Use HTTPS, restrict CORS, rotate secrets, use a production OTP/SMS provider,
persistent shared storage (S3/Cloudinary), durable distributed rate limiting,
database backups, observability, and end-to-end device testing. Do not enable
`DEV_OTP_ENABLED` in production.
