@echo off
setlocal
title The Nuclear Life Simulator - Java v2.0

echo.
echo ================================================
echo   The Nuclear Life Simulator - Java Rewrite v2.0
echo ================================================
echo.

where javac >nul 2>nul
if %errorlevel% neq 0 (
  echo [ERROR] javac not found in PATH.
  echo Please install JDK 21+ (e.g. Eclipse Temurin) and add its bin folder to PATH.
  echo.
  pause
  exit /b 1
)

echo Compiling...
javac -encoding UTF-8 NuclearLifeSimulator.java
if %errorlevel% neq 0 (
  echo.
  echo [ERROR] Compilation failed. See errors above.
  pause
  exit /b 1
)
echo.
echo Running...
echo (Close the window or press ESC in the app to exit)
echo.
java -Xmx512m NuclearLifeSimulator

echo.
echo Simulator exited.
pause
endlocal
