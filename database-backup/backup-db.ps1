
$ErrorActionPreference = "Stop"

$BackupDir = Join-Path $PSScriptRoot ""
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupFile = Join-Path $BackupDir "ecommerce_$Timestamp.dump"

Write-Host "Bat dau sao luu database..."

docker exec ecommerce_db pg_dump -U postgres -d ecommerce_db -Fc -f /tmp/ecommerce_backup.dump

if ($LASTEXITCODE -ne 0) {
    throw "Sao luu PostgreSQL that bai!"
}

docker cp ecommerce_db:/tmp/ecommerce_backup.dump $BackupFile

if ($LASTEXITCODE -ne 0) {
    throw "Khong the copy file backup ve may!"
}

if ((Get-Item $BackupFile).Length -eq 0) {
    throw "File backup rong!"
}

Write-Host "Sao luu thanh cong: $BackupFile"
