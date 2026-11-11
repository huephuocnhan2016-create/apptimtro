# Trọ Tốt

Ứng dụng Flutter tìm và đặt cọc phòng trọ cho sinh viên — đồ án cuối kỳ CMP177.

Sinh viên: đăng nhập số điện thoại + OTP, tìm phòng theo từ khóa / bộ lọc / bán
kính, chat với chủ trọ, đặt cọc VNPay hoặc MoMo, đánh giá phòng sau khi cọc.
Chủ trọ: đăng phòng kèm ảnh, quản lý số phòng còn.

## Tính năng

- **Sinh viên** — OTP, trang chủ gợi ý, tìm kiếm và lọc (giá, diện tích, tiện
  nghi, số phòng còn), sắp xếp, bản đồ, chi tiết phòng, yêu thích, chat
  realtime, đặt cọc, danh sách phòng đã cọc + hủy cọc, đánh giá.
- **Chủ trọ** — đăng / sửa / xóa phòng, upload ảnh, bật bán, dashboard, chat.
- **Chưa xây dựng** — hoàn tiền, lịch sử thanh toán, job tự hết hạn đơn
  `PENDING`, nhà mạng SMS thật.

## Công nghệ

| Tầng | Công nghệ |
| --- | --- |
| Client | Flutter 3, Riverpod 3, go_router, Dio |
| Backend | NestJS 11, Passport JWT, Prisma 6 |
| Dữ liệu | PostgreSQL 16 + PostGIS |
| Chat | Firebase custom token + Cloud Firestore |
| Thanh toán | VNPay, MoMo, cổng giả lập cho dev |
| Bản đồ | flutter_map (tile OpenStreetMap), Geolocator |

## Chạy thử

Cần Flutter SDK, Node.js 20+, Docker (hoặc PostgreSQL 16 + PostGIS 3.4), và một
project Firebase đã bật Firestore.

```powershell
cd backend
docker compose up -d postgres
Copy-Item .env.example .env    # điền các biến bắt buộc
npm.cmd install
npm.cmd run db:migrate
npx.cmd prisma db seed
npm.cmd run start:dev
```

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

`API_BASE_URL` là `http://10.0.2.2:3000/api` trên Android emulator,
`http://localhost:3000/api` trên iOS simulator, hoặc địa chỉ LAN của máy khi chạy
điện thoại thật.

Seed tạo 100 phòng ở 40 xã thuộc TP.HCM (tọa độ lấy từ ranh giới hành chính
OpenStreetMap, giá là số giả lập) và một tài khoản chủ trọ `+84908000001`. Không
tạo sẵn tài khoản sinh viên.

## Biến môi trường

Danh sách đầy đủ ở `backend/.env.example`; `.env` không được commit.

- `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `OTP_SECRET`: chuỗi ngẫu nhiên ≥ 32
  ký tự, khác nhau.
- `DATABASE_URL`: chuỗi kết nối PostgreSQL. `PORT` (3000), `CORS_ORIGIN`,
  `PUBLIC_API_URL` phải là URL mà thiết bị test truy cập được, ví dụ
  `http://10.0.2.2:3000`.
- `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`: **bắt
  buộc**, thiếu thì API không khởi động. Lấy ở Firebase console → Project
  settings → Service accounts.
- `VNPAY_*`, `MOMO_*`: để trống thì app dùng cổng giả lập.
- `DEV_OTP_ENABLED=true`: trả OTP trong response để test tay; production bắt buộc
  `false`.

Flutter đọc Firebase từ `android/app/google-services.json` và
`lib/firebase_options.dart`; đổi project thì chạy `flutterfire configure`. Rule
bảo mật chat nằm trong Firebase console chứ không thuộc repo, nên project mới phải
publish rule trước.

## Cấu trúc

```
lib/core/                 theme, Dio client, router + guard, secure storage
lib/features/<tên>/       data / domain / presentation cho từng tính năng
lib/shared/               widget và hàm định dạng dùng chung
test/                     60 test widget và test đơn vị
backend/src/modules/      auth, users, rooms, chat, payment, reviews
backend/prisma/           schema, migration, seed, ảnh phòng mẫu
tools/                    script dựng dữ liệu xã + cầu nối vị trí cho máy ảo
```

## API

Swagger: `http://localhost:3000/docs` (toàn bộ tham số lọc nằm trong đó). Response
luôn bọc `{ success, message, data }`, lỗi có thêm `code`.

- `auth`, `users` — OTP, login/refresh/logout, `firebase-token` mở phiên chat.
- `rooms` — tìm kiếm, lọc, nearby, phòng của chủ trọ, ảnh, favorite; lọc bán kính
  do PostGIS xử lý ở server. Tham số: `query`, `minPrice`/`maxPrice`,
  `minArea`/`maxArea`, `availableRooms`, `amenities`, `latitude`/`longitude`,
  `radius` (km), `sort` = `distance|price_asc|price_desc|newest`.
- `chat/conversations` — chỉ metadata cuộc trò chuyện; tin nhắn đi thẳng giữa app
  và Firestore.
- `rooms/:roomId/reviews` — chỉ sinh viên đang giữ đơn `PAID` của phòng đó mới ghi
  được (`403`); `GET /rooms/:id` trả kèm điểm trung bình và cờ `canReview`.
- `payment` — `POST /orders` nhận `roomId` + `gateway` rồi trả URL cổng đã ký
  (tiền lấy từ database, client không tự đặt). `GET /orders/:txnRef/status` đối
  chiếu cổng trước khi chuyển `PAID`; `POST .../cancel` hủy và hoàn phòng. Đơn
  `PAID` giảm `availableRooms`, về 0 thì phòng thành `DEPOSITED`. Mỗi sinh viên
  chỉ có một đơn đang hiệu lực cho một phòng, trùng thì trả `409`.
- Cổng giả lập cho dev: `GET /payment/dev/checkout/:txnRef`,
  `GET /payment/dev/return/:txnRef?code=00|24`, `POST /payment/dev/succeed/:txnRef`
  — production trả `503`/`404`.

Bảng: `users`, `refresh_tokens`, `phone_verifications`, `room_images`,
`favorites`, `room_reviews`, `conversations`, `payments` và `rooms` (cột
`location` là `geography(Point,4326)` có chỉ mục GiST). Bất biến một đơn cọc đang
hiệu lực mỗi (sinh viên, phòng) do chỉ mục unique riêng phần
`payments_active_deposit_key` giữ.

## Kiểm chứng

```powershell
flutter analyze
flutter test          # 60 test
cd backend
npm.cmd test          # 9 spec jest
npm.cmd run build
npx.cmd prisma validate
npx.cmd prisma migrate status
```

## Hạn chế

- **OTP**: chưa nối nhà cung cấp SMS. Bản dev trả OTP trong response
  (`DEV_OTP_ENABLED=true`) — đó là cách dự án chạy và demo; production trả `503`
  tới khi có nhà cung cấp nối vào `OTP_SENDER`.
- **Tiền**: hủy đơn trả lại phòng, nhưng tiền cổng đã thực nhận thì bản này không
  hoàn được.
- **Về app**: trang kết quả dùng liên kết `trotot://`, còn phụ thuộc trình duyệt
  xử lý intent.
- **Ảnh**: lưu trên đĩa `backend/uploads/`, đủ cho dev cục bộ, không để scale
  ngang.
- **Bản đồ**: cần internet tải tile; phòng chưa có tọa độ thì không vào kết quả
  bán kính.

Production cần thêm: HTTPS, giới hạn CORS, xoay secret, SMS thật, ảnh chuyển sang
S3 hoặc Cloudinary, sao lưu database, giám sát log, test lại trên thiết bị thật.
