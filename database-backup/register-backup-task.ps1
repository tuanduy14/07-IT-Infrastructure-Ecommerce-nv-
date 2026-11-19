# Dang ky lich sao luu tu dong luc 23:00 hang ngay (Windows Task Scheduler)
$script = Join-Path $PSScriptRoot "backup-db.ps1"
$action = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$script`""
schtasks /Create /SC DAILY /ST 23:00 /TN "EcommerceDbBackup" /TR $action /F
schtasks /Query /TN "EcommerceDbBackup" /V /FO LIST
# Chay thu ngay de chung minh lich hoat dong:
#   schtasks /Run /TN "EcommerceDbBackup"
