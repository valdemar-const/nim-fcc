@echo off
setlocal

echo Creating resources directory...
if not exist ".\resources" mkdir ".\resources"

echo Downloading fasm2.zip...
curl -L -o ".\resources\fasm2.zip" https://flatassembler.net/fasm2.zip
if errorlevel 1 (
    echo Failed to download fasm2.zip
    exit /b 1
)

echo Downloading fasmg.l5p0.zip...
curl -L -o ".\resources\fasmg.l5p0.zip" https://flatassembler.net/fasmg.l5p0.zip
if errorlevel 1 (
    echo Failed to download fasmg.l5p0.zip
    exit /b 1
)

echo Extracting fasm2.zip...
if not exist ".\resources\fasm2" mkdir ".\resources\fasm2"
pushd ".\resources\fasm2"
powershell -Command "Expand-Archive -Path '..\fasm2.zip' -DestinationPath '.' -Force"
if errorlevel 1 (
    popd
    exit /b 1
)
popd

echo Extracting fasmg.l5p0.zip...
if not exist ".\resources\fasmg.l5p0" mkdir ".\resources\fasmg.l5p0"
pushd ".\resources\fasmg.l5p0"
powershell -Command "Expand-Archive -Path '..\fasmg.l5p0.zip' -DestinationPath '.' -Force"
if errorlevel 1 (
    popd
    exit /b 1
)
popd

echo Removing zip files...
del /q ".\resources\*.zip"

echo Done.
