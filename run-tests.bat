@echo off
cd /d "%~dp0backend"
if not exist .venv call ..\start.bat
.venv\Scripts\python -m pytest -v
pause
