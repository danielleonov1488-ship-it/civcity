@echo off
chcp 65001 >nul
echo Копия базы аккаунтов CivCity с сервера
"C:\Program Files\Git\bin\bash.exe" "%~dp0deploy\backup.sh"
echo.
pause
