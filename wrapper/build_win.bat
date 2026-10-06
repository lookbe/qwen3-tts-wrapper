@echo off
setlocal

:: Builds qwen3.dll (+ ggml backend DLLs) as Debug AND RelWithDebInfo into build\bin\<Config>\,
:: incrementally. Unlike build.bat this never wipes anything (its own build_win dir, separate from build.bat's build).
:: Usage: build_win.bat [Debug|RelWithDebInfo]   (default: both). Then run copy_dll.bat.

set SCRIPT_DIR=%~dp0
if "%SCRIPT_DIR:~-1%"=="\" set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%
set BUILD_DIR=%SCRIPT_DIR%\build_win
set CMAKE=cmake
set CONFIGS=Debug RelWithDebInfo
if not "%~1"=="" set CONFIGS=%~1

set VCVARS="C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
if not exist %VCVARS% set VCVARS="C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat"
if not exist %VCVARS% set VCVARS="C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"
if exist %VCVARS% (
    call %VCVARS%
) else (
    echo Warning: vcvars64.bat not found. Make sure MSVC is in your PATH.
)

echo --- Configuring qwen3 wrapper ---
%CMAKE% -S "%SCRIPT_DIR%" -B "%BUILD_DIR%" -G "Visual Studio 17 2022" -A x64 -DGGML_VULKAN=ON
if %errorlevel% neq 0 exit /b %errorlevel%

for %%C in (%CONFIGS%) do (
    echo --- Building qwen3 [%%C] ---
    %CMAKE% --build "%BUILD_DIR%" --config %%C --target qwen3
    if errorlevel 1 exit /b 1
)

echo --- Build Successful. Now run copy_dll.bat ---
endlocal
