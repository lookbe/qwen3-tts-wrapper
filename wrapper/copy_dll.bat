@echo off
setlocal

:: Copies qwen3.dll, the ggml backend DLLs and their PDBs into
:: tobe-said-win\NativeLibs\<Config>\ (the "jniLibs" of the Windows app).
:: Usage: copy_dll.bat [Debug|RelWithDebInfo]   (default: both)

set BUILD_DIR=%~dp0build\bin
set DEST_ROOT=%~dp0..\..\tobe-said-win\NativeLibs
set CONFIGS=Debug RelWithDebInfo
if not "%~1"=="" set CONFIGS=%~1
set COPIED=0

for %%C in (%CONFIGS%) do call :copy_cfg %%C
if "%COPIED%"=="0" (
    echo Error: nothing copied -- run build_win.bat first.
    exit /b 1
)
echo Done!
endlocal
exit /b 0

:copy_cfg
set SRC=%BUILD_DIR%\%1
set DEST=%DEST_ROOT%\%1
if not exist "%SRC%\qwen3.dll" (
    echo [skip] %1: %SRC%\qwen3.dll not found
    exit /b 0
)
if not exist "%DEST%" mkdir "%DEST%"
echo Copying qwen3 + ggml [%1] to %DEST%
copy /Y "%SRC%\qwen3.dll" "%DEST%\" >nul
copy /Y "%SRC%\ggml*.dll" "%DEST%\" >nul
if exist "%SRC%\qwen3.pdb" copy /Y "%SRC%\qwen3.pdb" "%DEST%\" >nul
copy /Y "%SRC%\ggml*.pdb" "%DEST%\" >nul 2>nul
set COPIED=1
exit /b 0
