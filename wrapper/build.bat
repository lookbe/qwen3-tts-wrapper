@echo off
setlocal
set SCRIPT_DIR=%~dp0
if "%SCRIPT_DIR:~-1%"=="\" set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%

:: Try to find vcvars64.bat
set VCVARS="C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
if not exist %VCVARS% set VCVARS="C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat"
if not exist %VCVARS% set VCVARS="C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"

if exist %VCVARS% (
    call %VCVARS%
) else (
    echo Warning: vcvars64.bat not found. Make sure MSVC is in your PATH.
)

if exist "%SCRIPT_DIR%\build" rmdir /s /q "%SCRIPT_DIR%\build"
mkdir "%SCRIPT_DIR%\build"
cd /d "%SCRIPT_DIR%\build"

cmake -S "%SCRIPT_DIR%" -B "%SCRIPT_DIR%\build" -G "Visual Studio 17 2022" -A x64 -DGGML_VULKAN=ON
if %errorlevel% neq 0 exit /b %errorlevel%

cmake --build . --config Release
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
echo Build completed successfully. Binaries are in %SCRIPT_DIR%\build\bin
endlocal
