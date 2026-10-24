@echo off
REM Aegis - one-command start on Windows. Requires Python 3.11+ on PATH.
cd /d "%~dp0backend"
if not exist .venv (
  echo Creating virtual environment...
  python -m venv .venv || goto :err
  .venv\Scripts\python -m pip install --upgrade pip >nul
  .venv\Scripts\python -m pip install -r requirements.txt || goto :err
)
echo.
echo  Aegis is starting on http://localhost:8000
echo  Phones on the same Wi-Fi use:  http://YOUR-LAPTOP-IP:8000   (find it with: ipconfig)
echo  Optional: set ANTHROPIC_API_KEY / VIRUSTOTAL_API_KEY before running to enable AI review / reputation.
echo.
.venv\Scripts\python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
goto :eof
:err
echo Setup failed. Check that Python 3.11+ is installed and you are online.
pause
