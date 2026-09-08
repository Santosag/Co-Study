# Full MariaDB password reset for localhost, 127.0.0.1, and %
$ErrorActionPreference = 'Continue'

Write-Host "1. Stopping MariaDB service..." -ForegroundColor Yellow
Stop-Service MariaDB -Force -ErrorAction SilentlyContinue
net stop MariaDB

Start-Sleep -Seconds 2

Write-Host "2. Starting mysqld with --skip-grant-tables in background..." -ForegroundColor Yellow
$mysqld = "C:\Program Files\MariaDB 12.2\bin\mysqld.exe"
$myini = "C:\Program Files\MariaDB 12.2\data\my.ini"

$proc = Start-Process -FilePath $mysqld -ArgumentList "--defaults-file=`"$myini`"", "--skip-grant-tables" -PassThru

Start-Sleep -Seconds 4

Write-Host "3. Executing password reset SQL..." -ForegroundColor Yellow
$mariadbExe = "C:\Program Files\MariaDB 12.2\bin\mariadb.exe"

$sqlCommands = @"
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY 'santosh123';
CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY 'santosh123';
ALTER USER 'root'@'127.0.0.1' IDENTIFIED BY 'santosh123';
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'santosh123';
ALTER USER 'root'@'%' IDENTIFIED BY 'santosh123';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
CREATE DATABASE IF NOT EXISTS co_study_db;
FLUSH PRIVILEGES;
"@

& $mariadbExe -u root -e $sqlCommands

Write-Host "4. Stopping temporary mysqld..." -ForegroundColor Yellow
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
Stop-Process -Name mysqld -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 2

Write-Host "5. Starting MariaDB service..." -ForegroundColor Yellow
net start MariaDB

Write-Host "Done! MariaDB root password set to santosh123 for all hosts." -ForegroundColor Green
Start-Sleep -Seconds 3
