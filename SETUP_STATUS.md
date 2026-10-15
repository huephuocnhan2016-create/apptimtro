# Môi Trường Test Đã Thiết Lập Thành Công 🎉

## Trạng Thái Hiện Tại
- ✅ **PostgreSQL Database**: Đang chạy trên port 5432
- ✅ **NestJS API Server**: Đang chạy trên port 3000
- ✅ **Android Emulator**: sdk gphone16k x86 64 (emulator-5554)
- ⏳ **Flutter App**: Đang build trên Android Emulator

## Backend API Đã Test Thành Công
- ✅ Health check endpoint
- ✅ Send OTP flow
- ✅ Verify OTP flow  
- ✅ Nearby rooms endpoint
- ✅ Database connectivity

## Thông Tin Test Quan Trọng

### Credentials để test app:
- **Số điện thoại**: `0987654321`
- **Role**: `STUDENT` 
- **OTP Code**: `000738` (development mode)
- **API Base URL**: `http://10.0.2.2:3000/api` (đã cấu hình sẵn)

### URLs quan trọng:
- **API Documentation**: http://localhost:3000/docs
- **API Base**: http://localhost:3000/api
- **Emulator API**: http://10.0.2.2:3000/api

## Các Tính Năng Đã Bỏ Qua (Không Cần Thiết Để Test Core):
- ❌ Google Maps API (cần API key)
- ❌ Firebase Push Notifications (cần config)
- ❌ Agora Video Calls (cần credentials)
- ❌ Docker (sử dụng PostgreSQL có sẵn)

## Luồng Test Cơ Bản Khi App Build Xong:

### 1. Test Authentication
1. Mở app trên Android Emulator
2. Nhập số điện thoại: `0987654321`
3. Chọn role: `STUDENT`
4. Nhấn "Send OTP"
5. Nhập mã OTP: `000738`
6. Hoàn thành đăng ký/đăng nhập

### 2. Test Core Features
- Browse rooms (sẽ trống vì chưa có data)
- User profile
- Favorites (empty initially)

### 3. Test Landlord Features (Optional)
- Đăng ký với role `LANDLORD`
- Tạo phòng mới
- Upload hình ảnh
- Quản lý availability

## Script Hữu Ích
```powershell
# Test backend
.\test_backend.ps1

# Kiểm tra app build progress
Get-Content 'C:\Users\Nhan\AppData\Local\Temp\cline\proceed-while-running-*\*.log' -Tail 10

# Restart API server nếu cần
cd backend
npm run start:dev
```

## Khắc phục sự cố thường gặp:

### Nếu API không kết nối từ app:
1. Kiểm tra API server: `Test-NetConnection localhost -Port 3000`
2. Kiểm tra emulator: `flutter devices`
3. Restart app: `R` trong flutter console

### Nếu OTP không hoạt động:
1. Chạy script test: `.\test_backend.ps1`
2. Sử dụng OTP mới từ script output
3. Đảm bảo `DEV_OTP_ENABLED=true` trong .env

## Tiếp theo sau khi app build xong:
1. Test authentication flow
2. Test basic room browsing
3. Test user registration flow
4. Nếu cần Maps: cấu hình Google Maps API key
5. Nếu cần notifications: setup Firebase
6. Nếu cần video calls: setup Agora

---
**Thời gian thiết lập**: 2026-10-11 10:38
**Status**: Backend sẵn sàng, App đang build