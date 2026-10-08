@echo off
rem CivCity: test scene "Roman quarter": new buildings, trees, people and animals.
cd /d "%~dp0"
where python >nul 2>nul && (start "CivCity server" /min python -m http.server 5181) || (start "CivCity server" /min py -m http.server 5181)
timeout /t 2 /nobreak >nul
start "" "http://localhost:5181/lab/rome-test.html"
