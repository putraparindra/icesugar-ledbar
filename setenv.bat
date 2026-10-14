@echo off
rem setenv.bat - aktifkan OSS CAD Suite di jendela CMD ini.
rem Jalankan dari CMD (bukan klik dua kali):   setenv.bat
rem Ubah baris di bawah sesuai lokasi oss-cad-suite (tanpa spasi di path).

set "OSS_CAD_DIR=d:\Tools\oss-cad-suite"

if not exist "%OSS_CAD_DIR%\environment.bat" (
    echo [ERROR] Tidak menemukan "%OSS_CAD_DIR%\environment.bat"
    echo Sesuaikan OSS_CAD_DIR di setenv.bat.
    exit /b 1
)

rem Tanpa setlocal agar PATH tetap aktif di jendela CMD ini.
call "%OSS_CAD_DIR%\environment.bat"
