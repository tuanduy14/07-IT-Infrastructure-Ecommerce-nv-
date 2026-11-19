# Khoi phuc backup vao DB sach ecommerce_restore va doi chieu
# Cach dung: .\restore-db.ps1            (dung ban moi nhat)
#            .\restore-db.ps1 -BackupFile .\ecommerce_20261119_230000.dump
param([string]$BackupFile)

$ErrorActionPreference = "Continue"
$LogFile = Join-Path $PSScriptRoot "restore.log"

function Write-Log($msg) {
    $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}
function Fail($msg) { Write-Log "FAILED: $msg"; exit 1 }

if (-not $BackupFile) {
    $latest = Get-ChildItem $PSScriptRoot -Filter "ecommerce_*.dump" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) { Fail "Khong tim thay file .dump" }
    $BackupFile = $latest.FullName
}
Write-Log "START restore tu $BackupFile"
$sw = [System.Diagnostics.Stopwatch]::StartNew()

# 1. Doi chieu ma bam (neu co file .sha256)
$HashFile = "$BackupFile.sha256"
if (Test-Path $HashFile) {
    $expected = ((Get-Content $HashFile) -split "\s+")[0]
    $actual = (Get-FileHash -Path $BackupFile -Algorithm SHA256).Hash
    if ($expected -ne $actual) { Fail "Ma bam KHONG khop (file hong hoac bi sua)" }
    Write-Log "SHA256 khop: $actual"
} else {
    Write-Log "CANH BAO: khong co file .sha256, bo qua doi chieu"
}

# 2. Tao DB sach
docker exec ecommerce_db psql -U postgres -c "DROP DATABASE IF EXISTS ecommerce_restore;"
docker exec ecommerce_db psql -U postgres -c "CREATE DATABASE ecommerce_restore;"
if ($LASTEXITCODE -ne 0) { Fail "Khong tao duoc DB ecommerce_restore" }

# 3. Restore
docker cp $BackupFile ecommerce_db:/tmp/restore.dump
docker exec ecommerce_db pg_restore -U postgres -d ecommerce_restore /tmp/restore.dump
if ($LASTEXITCODE -ne 0) { Fail "pg_restore that bai" }

# 4. Kiem tra so dong 2 DB
$srcProducts = (docker exec ecommerce_db psql -U postgres -d ecommerce_db -t -A -c "SELECT COUNT(*) FROM products;").Trim()
$srcOrders   = (docker exec ecommerce_db psql -U postgres -d ecommerce_db -t -A -c "SELECT COUNT(*) FROM orders;").Trim()
$dstProducts = (docker exec ecommerce_db psql -U postgres -d ecommerce_restore -t -A -c "SELECT COUNT(*) FROM products;").Trim()
$dstOrders   = (docker exec ecommerce_db psql -U postgres -d ecommerce_restore -t -A -c "SELECT COUNT(*) FROM orders;").Trim()
Write-Log "Nguon : products=$srcProducts orders=$srcOrders"
Write-Log "Restore: products=$dstProducts orders=$dstOrders"

$sw.Stop()
Write-Log ("Thoi gian restore (RTO do duoc): {0:N1} giay" -f $sw.Elapsed.TotalSeconds)

if ($dstProducts -eq 0) { Fail "Bang products rong sau restore" }
if ($srcOrders -ne $dstOrders) {
    Write-Log "LUU Y: so don hang khac nhau (co the do don moi phat sinh sau luc backup). Day chinh la RPO."
}
Write-Log "SUCCESS restore hoan tat"
exit 0
