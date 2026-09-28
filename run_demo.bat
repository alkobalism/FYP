@echo off
title Launching Pothole Detection AI Demo...
cd /d "%~dp0"
echo ========================================================
echo Starting Pothole Detection AI
echo ========================================================
echo.
"model_training\.venv\Scripts\streamlit.exe" run "streamlit_deployment\app.py"
pause
