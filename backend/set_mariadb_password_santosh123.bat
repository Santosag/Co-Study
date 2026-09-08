@echo off
:: Batch script to reset MariaDB root password to santosh123
echo ==================================================
echo Resetting MariaDB root password to: santosh123
echo and creating database: co_study_db
echo ==================================================

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Requesting Administrator privileges...
    powershell -Command "Start-Process '%~0' -Verb RunAs"
    exit /b
)

echo [1/4] Stopping MariaDB service...
net stop MariaDB

echo [2/4] Writing reset script...
set SQLFILE=%~dp0init_temp.sql
(
echo FLUSH PRIVILEGES;
echo ALTER USER 'root'@'localhost' IDENTIFIED BY 'santosh123';
echo CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY 'santosh123';
echo ALTER USER 'root'@'127.0.0.1' IDENTIFIED BY 'santosh123';
echo GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
echo GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
echo CREATE DATABASE IF NOT EXISTS co_study_db;
echo FLUSH PRIVILEGES;
) > "%SQLFILE%"

echo [3/4] Resetting password...
start "" /b "C:\Program Files\MariaDB 12.2\bin\mysqld.exe" --defaults-file="C:\Program Files\MariaDB 12.2\data\my.ini" --init-file="%SQLFILE%" --console
timeout /t 5 /nobreak >nul

taskkill /F /IM mysqld.exe >nul 2>&1
timeout /t 2 /nobreak >nul

del "%SQLFILE%" >nul 2>&1

echo [4/4] Restarting MariaDB service...
net start MariaDB

echo ==================================================
echo [SUCCESS] MariaDB root password is now: santosh123
echo Database: co_study_db is created!
echo ==================================================
pause
