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

Write-Host "[2/2] Iniciando AstraMed en http://localhost:8080 ..." -ForegroundColor Green
flutter run -d chrome --web-port=8080
