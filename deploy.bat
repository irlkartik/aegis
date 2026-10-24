@echo off
REM Deploy Aegis to Vercel (project: aegis-security). Needs Node.js 18+ and a Vercel login.
cd /d "%~dp0"
where node >nul 2>&1 || (echo Node.js is required: https://nodejs.org & pause & exit /b 1)
echo [1/4] Copying web UI into public\ ...
if exist public rmdir /s /q public
mkdir public\static
xcopy /e /i /q /y web\css public\static\css >nul
xcopy /e /i /q /y web\js public\static\js >nul
xcopy /e /i /q /y web\img public\static\img >nul
copy /y web\index.html public\index.html >nul
echo [2/4] Checking Vercel login ...
call npx --yes vercel@latest whoami >nul 2>&1 || call npx --yes vercel@latest login || goto :err
echo [3/4] Linking project and setting encrypted environment variables ...
call npx --yes vercel@latest link --yes --project aegis-security || goto :err
for %%V in (DATABASE_URL AEGIS_SECRET) do (
  call npx --yes vercel@latest env rm %%V production --yes >nul 2>&1
  call npx --yes vercel@latest env add %%V production < .vercel-secrets\%%V.txt || goto :err
)
echo [4/4] Deploying to production ...
call npx --yes vercel@latest deploy --prod --yes || goto :err
echo.
echo Done. Open the Production URL above, and check  <URL>/api/health  shows "database":"reachable".
pause
exit /b 0
:err
echo.
echo Deployment failed - see the message above.
pause
exit /b 1
