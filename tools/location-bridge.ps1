<#
  Đẩy vị trí thật của máy tính (Windows Location Service) vào GPS của Android emulator.
  Cách dùng:
    powershell -NoProfile -ExecutionPolicy Bypass -File tools/location-bridge.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File tools/location-bridge.ps1 -Device emulator-5554 -IntervalSec 10
  Yêu cầu: Settings > Privacy & security > Location đang bật (Location services + Let desktop apps access your location).
#>
param(
  [string]$Device = 'emulator-5554',
  [int]$IntervalSec = 10
)

$ErrorActionPreference = 'Stop'
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (-not (Test-Path $adb)) { $adb = 'adb' }

Add-Type -AssemblyName System.Runtime.WindowsRuntime | Out-Null
$null = [Windows.Devices.Geolocation.Geolocator, Windows.Devices.Geolocation, ContentType = WindowsRuntime]
$asTaskGeneric = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
} | Select-Object -First 1

function Get-HostPosition {
  $locator = New-Object Windows.Devices.Geolocation.Geolocator
  $locator.DesiredAccuracyInMeters = 20
  $op = $locator.GetGeopositionAsync()
  $task = $asTaskGeneric.MakeGenericMethod([Windows.Devices.Geolocation.Geoposition]).Invoke($null, @($op))
  if (-not $task.Wait(15000)) { throw 'GetGeopositionAsync timeout' }
  $task.Result
}

$access = [Windows.Devices.Geolocation.Geolocator]::RequestAccessAsync()
$accessTask = $asTaskGeneric.MakeGenericMethod([Windows.Devices.Geolocation.GeolocationAccessStatus]).Invoke($null, @($access))
$null = $accessTask.Wait(10000)
if ($accessTask.IsCompleted -and $accessTask.Result -ne 'Allowed') {
  throw "Windows từ chối truy cập vị trí ($($accessTask.Result)). Bật Settings > Privacy & security > Location."
}

while ($true) {
  try {
    $pos = Get-HostPosition
    $lat = $pos.Coordinate.Point.Position.Latitude
    $lon = $pos.Coordinate.Point.Position.Longitude
    $latArg = $lat.ToString('F7', $inv)
    $lonArg = $lon.ToString('F7', $inv)
    & $adb -s $Device emu geo fix $lonArg $latArg | Out-Null
    $acc = [math]::Round($pos.Coordinate.Accuracy)
    Write-Output ("{0:HH:mm:ss} -> {1}, {2} (±{3}m, {4})" -f (Get-Date), $latArg, $lonArg, $acc, $pos.Coordinate.PositionSource)
  } catch {
    Write-Output ("{0:HH:mm:ss} ERROR: {1}" -f (Get-Date), $_.Exception.Message)
  }
  Start-Sleep -Seconds $IntervalSec
}
