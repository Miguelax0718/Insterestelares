Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "   AstraMed Web Launcher - Puerto Fijo 8080" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

Write-Host "[1/2] Verificando procesos previos en el puerto 8080..." -ForegroundColor Yellow
$connections = netstat -ano | Select-String ":8080" | Select-String "LISTENING"
foreach ($line in $connections) {
    $parts = ($line.ToString().Trim() -split '\s+')
    $pidToKill = $parts[-1]
    if ($pidToKill -and $pidToKill -ne "0") {
        Write-Host "Liberando puerto 8080 (cerrando proceso PID: $pidToKill)..." -ForegroundColor Red
        Stop-Process -Id $pidToKill -Force -ErrorAction SilentlyContinue
    }
}

$pubArgs = @()
if (Test-Path ".dart_tool\package_config.json") {
    $pubArgs += "--no-pub"
}

Write-Host "[2/2] Iniciando AstraMed en http://localhost:8080 ..." -ForegroundColor Green
Write-Host "[TIP] Manten esta sesion abierta y usa 'r' (Hot Reload) o 'R' (Hot Restart) sin reiniciar." -ForegroundColor Gray
flutter run -d chrome --web-port=8080 @pubArgs
