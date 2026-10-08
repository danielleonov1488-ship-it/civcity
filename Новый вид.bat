@echo off
rem CivCity: the game in the NEW LOOK (Synty-style people, trees and props). Same city and save.
cd /d "%~dp0"
where python >nul 2>nul && (start "CivCity server" /min python -m http.server 5181) || (start "CivCity server" /min py -m http.server 5181)
timeout /t 2 /nobreak >nul
start "" "http://localhost:5181/?new"
