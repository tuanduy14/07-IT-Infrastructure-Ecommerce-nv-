# Sao luu PostgreSQL -> file .dump + ma bam SHA256 + log + day len FTP
$ErrorActionPreference = "Continue"

$BackupDir = $PSScriptRoot
$LogFile   = Join-Path $BackupDir "backup.log"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupFile = Join-Path $BackupDir "ecommerce_$Timestamp.dump"
$HashFile   = "$BackupFile.sha256"

# Thong tin FTP (du lieu gia cho demo, khop voi docker-compose.ftp.yml)
$FtpHost = "localhost"
$FtpUser = "backup"
$FtpPass = "backup123"
$RetentionDays = 30

function Write-Log($msg) {
    $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

function Fail($msg) {
    Write-Log "FAILED: $msg"
    exit 1
}

Write-Log "START backup database ecommerce_db"

docker exec ecommerce_db pg_dump -U postgres -d ecommerce_db -Fc -f /tmp/ecommerce_backup.dump
if ($LASTEXITCODE -ne 0) { Fail "pg_dump that bai" }

docker cp ecommerce_db:/tmp/ecommerce_backup.dump $BackupFile
if ($LASTEXITCODE -ne 0) { Fail "Khong copy duoc file backup ve may" }

$size = (Get-Item $BackupFile).Length
if ($size -eq 0) { Fail "File backup rong" }

$hash = (Get-FileHash -Path $BackupFile -Algorithm SHA256).Hash
"$hash  $(Split-Path $BackupFile -Leaf)" | Out-File -Encoding ascii $HashFile
Write-Log "Backup local OK: $(Split-Path $BackupFile -Leaf) | $size bytes | SHA256=$hash"

# Day len FTP Server
curl.exe -sS --fail --ftp-pasv -T $BackupFile "ftp://$FtpHost/" --user "${FtpUser}:${FtpPass}"
if ($LASTEXITCODE -ne 0) { Fail "Upload FTP that bai (ban local van con): $BackupFile" }
curl.exe -sS --fail --ftp-pasv -T $HashFile "ftp://$FtpHost/" --user "${FtpUser}:${FtpPass}"
if ($LASTEXITCODE -ne 0) { Fail "Upload ma bam len FTP that bai" }
Write-Log "Upload FTP OK"

# Xoa ban local cu hon $RetentionDays ngay
Get-ChildItem $BackupDir -Filter "ecommerce_*.dump*" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) } |
    ForEach-Object { Remove-Item $_.FullName; Write-Log "Xoa ban cu: $($_.Name)" }

Write-Log "SUCCESS backup hoan tat"
exit 0
