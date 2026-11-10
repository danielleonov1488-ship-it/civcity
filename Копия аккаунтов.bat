@echo off
chcp 65001 >nul
echo Копия базы аккаунтов CivCity с сервера
"C:\Program Files\Gitinash.exe" "%~dp0deployackup.sh"
echo.
pause
