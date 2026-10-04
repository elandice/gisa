@echo off
setlocal
cd /d "%~dp0.."
if not exist "build\web\index.html" (
  echo Please build the app first: flutter build web
  pause
  exit /b 1
)
set "TASK_PYTHON=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if exist "%TASK_PYTHON%" (
  echo Open http://127.0.0.1:8765 in your browser. Press Ctrl+C to stop.
  "%TASK_PYTHON%" -m http.server 8765 --bind 127.0.0.1 --directory build\web
) else (
  echo Open http://127.0.0.1:8765 in your browser. Press Ctrl+C to stop.
  python -m http.server 8765 --bind 127.0.0.1 --directory build\web
)
endlocal
