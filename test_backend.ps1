#!/usr/bin/env powershell
# Script to test backend functionality

Write-Host "=== Testing Backend API ===" -ForegroundColor Green

# Test 1: Health check
Write-Host "`n1. Testing API Health..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri 'http://localhost:3000/api/auth/me' -Method GET -ErrorAction Stop
} catch {
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "✅ API is running (401 Unauthorized as expected)" -ForegroundColor Green
    } else {
        Write-Host "❌ API health check failed" -ForegroundColor Red
        exit 1
    }
}

# Test 2: Send OTP
Write-Host "`n2. Testing Send OTP..." -ForegroundColor Yellow
$otpBody = @{
    phone = "0987654321"
    role = "STUDENT"
} | ConvertTo-Json

try {
    $otpResponse = Invoke-RestMethod -Uri 'http://localhost:3000/api/auth/send-otp' -Method POST -Body $otpBody -ContentType 'application/json'
    Write-Host "✅ Send OTP successful" -ForegroundColor Green
    Write-Host "   Phone: $($otpResponse.data.phone)" -ForegroundColor Cyan
    Write-Host "   Dev OTP: $($otpResponse.data.devOtp)" -ForegroundColor Cyan
    $devOtp = $otpResponse.data.devOtp
} catch {
    Write-Host "❌ Send OTP failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 3: Verify OTP
Write-Host "`n3. Testing Verify OTP..." -ForegroundColor Yellow
$verifyBody = @{
    phone = "0987654321"
    otp = $devOtp
} | ConvertTo-Json

try {
    $verifyResponse = Invoke-RestMethod -Uri 'http://localhost:3000/api/auth/verify-otp' -Method POST -Body $verifyBody -ContentType 'application/json'
    Write-Host "✅ Verify OTP successful" -ForegroundColor Green
    Write-Host "   Verification token received" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Verify OTP failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 4: Nearby rooms
Write-Host "`n4. Testing Nearby Rooms..." -ForegroundColor Yellow
try {
    $roomsResponse = Invoke-RestMethod -Uri 'http://localhost:3000/api/rooms/nearby?latitude=10.8231&longitude=106.6297&radius=5' -Method GET
    Write-Host "✅ Nearby rooms API working" -ForegroundColor Green
    Write-Host "   Found rooms: $($roomsResponse.data.Count)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Nearby rooms failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Backend Test Summary ===" -ForegroundColor Green
Write-Host "✅ All core API endpoints are working" -ForegroundColor Green
Write-Host "✅ OTP flow is functional (dev mode)" -ForegroundColor Green
Write-Host "✅ Database connection is working" -ForegroundColor Green
Write-Host "✅ Ready to test with Flutter app" -ForegroundColor Green

Write-Host "`n=== Test Instructions ===" -ForegroundColor Yellow
Write-Host "1. Use phone: 0987654321" -ForegroundColor White
Write-Host "2. Select role: STUDENT" -ForegroundColor White
Write-Host "3. Use OTP code: $devOtp" -ForegroundColor White
Write-Host "4. Backend URL in app: http://10.0.2.2:3000/api" -ForegroundColor White