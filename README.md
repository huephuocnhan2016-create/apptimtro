# Trọ Tốt

Ứng dụng Flutter tìm và đặt cọc phòng trọ: sinh viên đăng nhập bằng số điện
thoại + OTP, tìm phòng theo từ khóa, bộ lọc, bán kính hoặc tiện nghi, chat với
chủ trọ, đặt cọc qua VNPay/MoMo và đánh giá phòng sau khi cọc; chủ trọ đăng
phòng kèm ảnh và quản lý số phòng còn. Đồ án cuối kỳ học phần CMP177.

Kho mã nguồn: https://github.com/huephuocnhan2016-create/apptimtro

| Tầng | Công nghệ |
| --- | --- |
| Client | Flutter 3, Riverpod 3, go_router, Dio, flutter_secure_storage |
| Backend | NestJS 11, Passport JWT, class-validator |
| Dữ liệu | PostgreSQL 16 + PostGIS, Prisma 6 |
| Chat | Firebase Auth (custom token) + Cloud Firestore |
| Thanh toán | Adapter cổng VNPay và MoMo |
| Bản đồ | `flutter_map` (tile OpenStreetMap), Geolocator, Permission Handler |
| Đánh giá | `ReviewsModule` + bảng `room_reviews` |

## 1. Chức năng và trạng thái

| Vai trò | Tính năng | Trạng thái |
| --- | --- | --- |
| Sinh viên | Đăng ký / đăng nhập số điện thoại + OTP, chọn vai trò | Hoàn thành |
| Sinh viên | Trang chủ: thanh tìm kiếm và phòng gợi ý | Hoàn thành |
| Sinh viên | Tìm kiếm, bộ lọc (giá, diện tích, tiện nghi, số phòng còn), sắp xếp | Hoàn thành |
| Sinh viên | Tìm phòng theo bán kính, lọc bằng PostGIS | Hoàn thành |
| Sinh viên | Bản đồ phòng (OpenStreetMap) | Hoàn thành |
| Sinh viên | Chi tiết phòng: ảnh, giá, tiện nghi, chủ trọ, số điện thoại | Hoàn thành |
| Sinh viên | Yêu thích phòng | Hoàn thành |
| Sinh viên | Chat realtime với chủ trọ (Firestore) | Hoàn thành |
| Sinh viên | Đặt cọc VNPay hoặc MoMo, chọn cổng thanh toán | Hoàn thành |
| Sinh viên | Danh sách phòng đã cọc, hủy cọc và hoàn phòng | Hoàn thành |
| Sinh viên | Đánh giá phòng (chỉ sau khi đã cọc) | Hoàn thành |
| Chủ trọ | Đăng ký, đăng nhập, dashboard phòng của mình | Hoàn thành |
| Chủ trọ | Thêm / sửa / xóa phòng, bật bán, upload ảnh | Hoàn thành |
| Chủ trọ | Chat với sinh viên | Hoàn thành |
| — | Gửi OTP bằng nhà mạng SMS thật | Chưa hoàn thiện (xem mục 7) |
| — | Hoàn tiền, lịch sử thanh toán, tự hết hạn đơn cọc | Chưa xây dựng |

## 2. Yêu cầu môi trường

- Flutter/Dart SDK theo `pubspec.yaml`, Node.js 20+, Android Studio/Xcode
- Docker Desktop, hoặc PostgreSQL 16 có PostGIS 3.4+
- Một project Firebase đã bật Firestore — thiếu thì API không khởi động được và
  tab chat không chạy (xem mục 3)

## 3. Cài đặt và chạy

Cấu hình backend (thư mục `backend`):

```powershell
docker compose up -d postgres
Copy-Item .env.example .env    # rồi điền các biến bắt buộc
npm.cmd install
npm.cmd run db:migrate
npx.cmd prisma db seed         # du lieu mau
npm.cmd run start:dev
```

Biến môi trường trong `backend/.env`. Ba khóa JWT/OTP là chuỗi ngẫu nhiên ≥ 32 ký
tự, khác nhau; `.env.example` chỉ có placeholder và `.env` chưa từng được commit.

| Biến | Công dụng |
| --- | --- |
| `DATABASE_URL` | Chuỗi kết nối PostgreSQL |
| `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `OTP_SECRET` | Khóa ký/HMAC |
| `NODE_ENV`, `PORT`, `CORS_ORIGIN`, `PUBLIC_API_URL` | Chế độ chạy, cổng, origin cho phép, URL công khai (thiết bị phải truy cập được, ví dụ `http://10.0.2.2:3000`) |
| `ACCESS_TOKEN_SECONDS`, `REFRESH_TOKEN_DAYS`, `OTP_TTL_MINUTES` | Thời hạn token và OTP |
| `DEV_OTP_ENABLED` | Trả OTP trong response để test; bắt buộc false khi production |
| `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` | **Bắt buộc** — service account cấp token chat. Thiếu là API từ chối boot. Lấy ở Firebase console → Project settings → Service accounts; `FIREBASE_PRIVATE_KEY` là khóa ký thật |
| `VNPAY_TMN_CODE`, `VNPAY_SECURE_SECRET`, `VNPAY_HASH_ALGORITHM`, `VNPAY_QUERY_IP_ADDR` | Gian hàng VNPay; để trống thì dùng cổng giả lập |
| `MOMO_PARTNER_CODE`, `MOMO_ACCESS_KEY`, `MOMO_SECRET_KEY`, `MOMO_ENDPOINT`, `MOMO_RETURN_URL`, `MOMO_IPN_URL`, `MOMO_REQUEST_TYPE` | Gian hàng MoMo; để trống thì dùng cổng giả lập |
| `NOMINATIM_EMAIL` | Tùy chọn — email liên hệ khi tra địa chỉ qua Nominatim |

Phía Flutter đọc Firebase từ `android/app/google-services.json` và
`lib/firebase_options.dart` (đổi project thì chạy `flutterfire configure`). Rule
bảo mật chat nằm trong Firebase console, không thuộc repo, nên project mới phải
publish rule trước.

Chạy ứng dụng từ thư mục gốc:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

`http://localhost:3000/api` cho iOS simulator, địa chỉ LAN của máy cho điện thoại
thật. Build phát hành: `flutter build apk|ios --dart-define=API_BASE_URL=...`.

Dữ liệu seed: xóa toàn bộ bảng rồi tạo 1 chủ trọ `+84908000001` và 100 phòng trải
ở 40 xã thuộc Thành phố Hồ Chí Minh (tọa độ lấy từ ranh giới hành chính
OpenStreetMap, giá tiền là số giả lập). Không tạo sẵn tài khoản sinh viên.

## 4. Kiến trúc

Flutter chia mỗi tính năng trong `lib/features/` thành `data` / `domain` /
`presentation`; widget dùng repository Riverpod, Dio nằm ở tầng API client.
Backend là module NestJS với DTO validation, guard JWT + vai trò, Prisma service
và SQL/PostGIS cho truy vấn bán kính. Access token ngắn hạn, refresh token xoay
vòng và chỉ lưu SHA-256 hash. Tin nhắn chat không qua PostgreSQL: backend cấp
Firebase custom token, ứng dụng tự đọc/ghi Firestore. Ảnh phòng ghi vào
`backend/uploads/` qua một lớp trừu tượng, có thể thay bằng S3/Cloudinary.

```
lib/core/         theme, Dio client, router + guard, secure storage
lib/features/     auth, home, rooms, map, favorites, chat, payment, landlord, profile
lib/shared/       hàm định dạng và widget dùng chung
test/             test widget và test đơn vị
backend/src/modules/  auth, users, rooms, chat, payment, reviews
backend/src/config/   lược đồ env — mọi biến API cần khai báo ở đây
backend/prisma/       schema, migration, seed và ảnh phòng mẫu
tools/            script dựng dữ liệu xã OpenStreetMap + cầu nối vị trí test máy ảo
```

## 5. API

Swagger ở `http://localhost:3000/docs` khi backend chạy. Response dùng bọc
`{ success, message, data }`, lỗi thêm `code`.

- **Xác thực**: `POST /api/auth/send-otp|verify-otp|register|login|refresh|logout`,
  `GET /api/auth/me`, `GET /api/users/me`,
  `GET /api/auth/firebase-token` (custom token mở phiên Firestore)
- **Phòng & yêu thích**: `GET /api/rooms/nearby|search|filter|:id`,
  `POST|DELETE /api/rooms/:id/favorite`, `GET /api/users/me/favorites`; chủ trọ
  `POST /api/rooms`, `GET /api/rooms/my`, `PUT|DELETE /api/rooms/:id`,
  `POST|DELETE /api/rooms/:id/images`, `PATCH /api/rooms/:id/availability`.
  Bộ lọc: `query`, `minPrice`, `maxPrice`, `minArea`, `maxArea`,
  `availableRooms`, `amenities`, `latitude`, `longitude`, `radius` (km),
  `sort` = `distance|price_asc|price_desc|newest`; lọc bán kính chạy bằng PostGIS
  ở server.
- **Chat**: `GET|POST /api/chat/conversations` chỉ quản lý metadata cuộc trò
  chuyện; tin nhắn đi thẳng giữa ứng dụng và Firestore.
- **Đánh giá**: `GET|POST /api/rooms/:roomId/reviews` — ghi điểm bị chặn `403`
  nếu không phải sinh viên đang giữ đơn `PAID` của phòng đó; `GET /api/rooms/:id`
  trả thêm điểm trung bình, số đánh giá và cờ `canReview`.
- **Đặt cọc**: `POST /api/payment/orders` nhận `roomId` + `gateway`
  (`VNPAY` mặc định hoặc `MOMO`), trả payload cổng đã ký kèm `txnRef`; số tiền lấy
  từ tiền cọc trong database, client không tự đặt. `GET
  /api/payment/orders/:txnRef/status` đối chiếu với cổng trên đơn (VNPay `queryDr`
  / MoMo `queryOrder`) rồi mới chuyển `PAID`; `POST .../cancel` hủy và hoàn
  phòng. Đơn `PAID` giảm `availableRooms`, về 0 thì phòng thành `DEPOSITED` và
  ngừng nhận cọc. `GET /api/payment/deposits` danh sách cọc của sinh viên. Mỗi
  sinh viên tối đa một đơn đang hiệu lực cho một phòng (partial unique index
  `payments_active_deposit_key`, vi phạm trả `409`). Cổng giả lập cho môi trường
  dev: `GET /api/payment/dev/checkout/:txnRef`,
  `GET /api/payment/dev/return/:txnRef?code=00|24`,
  `POST /api/payment/dev/succeed/:txnRef`; production trả `503`/`404`.

Bảng: `users`, `refresh_tokens`, `phone_verifications`, `rooms`, `room_images`,
`favorites`, `room_reviews`, `conversations`, `payments`, và `rooms.location` là
`geography(Point,4326)` có chỉ mục GiST.

## 6. Kiểm chứng

```powershell
flutter analyze
flutter test
cd backend
npm.cmd test
npm.cmd run build
npx.cmd prisma validate
npx.cmd prisma migrate status
```

## 7. Hạn chế đã biết

Nói thẳng vì bản demo chấm điểm không nên nói quá về sản phẩm.

- **Phát OTP**: chưa có nhà cung cấp SMS. Ngoài production OTP được ghi ra log và
  trả trong response khi `DEV_OTP_ENABLED=true` — đó là cách dự án chạy và demo.
  Production trả `503` tới khi có nhà cung cấp thật nối vào `OTP_SENDER`.
- **Thanh toán**: không có hoàn tiền, không có màn lịch sử thanh toán, không có
  job tự hết hạn đơn `PENDING` (đơn đó được dùng lại hoặc hủy khi sinh viên quay
  lại). Hủy thì trả phòng, còn tiền cổng đã thực nhận thì bản build này không đẩy
  lại được.
- **Quay về ứng dụng**: trang kết quả dùng liên kết `trotot://` và ứng dụng đọc lại
  đơn khi về foreground, vẫn phụ thuộc trình duyệt chịu xử lý intent.
- **Chat** cần project Firebase kèm rule publish trong console.
- **Ảnh** lưu trên đĩa của backend, phù hợp dev cục bộ, không phù hợp scale ngang.
- **Bản đồ** cần internet để tải tile; phòng chỉ có địa chỉ, chưa có tọa độ thì
  không vào kết quả bán kính.

## 8. Khuyến nghị khi vận hành production

HTTPS, giới hạn CORS, xoay vòng secret, OTP/SMS thật, lưu trữ ảnh dùng chung (S3
hay Cloudinary), giới hạn tần suất phân tán bền vững, sao lưu database, giám sát
và log, test đầu cuối trên thiết bị thật. Không bật `DEV_OTP_ENABLED`.
