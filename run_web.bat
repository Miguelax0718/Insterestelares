@echo off
echo ===================================================
echo   AstraMed Web Launcher - Puerto Fijo 8080
echo ===================================================

echo [1/2] Verificando si el puerto 8080 esta ocupado por ejecuciones previas...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :8080 ^| findstr LISTENING') do (
    echo [!] Liberando puerto 8080 ocupado por el proceso PID %%a...
    taskkill /F /PID %%a >nul 2>&1
)

set PUB_FLAG=
if exist ".dart_tool\package_config.json" (
    set PUB_FLAG=--no-pub
)

echo [2/2] Iniciando AstraMed en http://localhost:8080 ...
echo [TIP] Manten esta ventana abierta y usa 'r' (Hot Reload) o 'R' (Hot Restart) sin reiniciar todo.
flutter run -d chrome --web-port=8080 %PUB_FLAG%
