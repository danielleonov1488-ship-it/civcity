@echo off
rem CivCity: local server + browser. Needs Python (python.org).
cd /d "%~dp0"
rem old server windows are closed first, so the browser always gets fresh files
taskkill /FI "WINDOWTITLE eq CivCity server*" /F >nul 2>nul
where python >nul 2>nul && (start "CivCity server" /min python serve.py 5181) || (start "CivCity server" /min py serve.py 5181)
timeout /t 2 /nobreak >nul
start "" "http://localhost:5181/?b=%RANDOM%"
