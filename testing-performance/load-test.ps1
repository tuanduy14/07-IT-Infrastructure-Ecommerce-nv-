# Script do tai cho he thong TMDT (qua nginx cong 8080)
# Chay: .\load-test.ps1 -Label before     (hoac -Label after)
# Thu nhanh: .\load-test.ps1 -Label before -Levels 5 -DurationSec 10 -Repeats 1
#
# Moi lan chay = 1 muc tai x 1 tac vu (read/write) x 1 lan lap.
# Ket qua ghi vao raw-data-<Label>\ : results.csv, summary.csv, docker-stats.csv, meta.txt
# Tac vu write se them don hang gia vao bang orders; cuoi script tu xoa (tru khi dung -KeepData).
param(
    [Parameter(Mandatory = $true)][ValidateSet("before", "after")][string]$Label,
    [int[]]$Levels = @(10, 50, 100),
    [int]$DurationSec = 30,
    [int]$Repeats = 3,
    [string[]]$Tasks = @("read", "write"),
    [string]$BaseUrl = "http://localhost:8080",
    [int]$CooldownSec = 5,
    [switch]$KeepData
)

$ErrorActionPreference = "Continue"
[System.Net.ServicePointManager]::DefaultConnectionLimit = 1000
[System.Net.ServicePointManager]::Expect100Continue = $false

$OutDir     = Join-Path $PSScriptRoot "raw-data-$Label"
$ResultsCsv = Join-Path $OutDir "results.csv"
$StatsCsv   = Join-Path $OutDir "docker-stats.csv"
$SummaryCsv = Join-Path $OutDir "summary.csv"
$MetaFile   = Join-Path $OutDir "meta.txt"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Khong ghi de du lieu goc cu: doi ten file cu kem thoi gian
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
foreach ($f in @($ResultsCsv, $StatsCsv, $SummaryCsv, $MetaFile)) {
    if (Test-Path $f) {
        $new = "{0}.old_{1}{2}" -f [IO.Path]::GetFileNameWithoutExtension($f), $stamp, [IO.Path]::GetExtension($f)
        Rename-Item $f $new
    }
}

# --- Kiem tra he thong san sang ---
try {
    $null = Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/api/products" -TimeoutSec 10
} catch {
    Write-Host "Khong goi duoc $BaseUrl/api/products. Kiem tra docker compose ps roi chay lai." -ForegroundColor Red
    exit 1
}

# --- Ghi cau hinh moi truong (de bao cao ghi ro dieu kien do) ---
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
$meta = @()
$meta += "Label            : $Label"
$meta += "Thoi diem bat dau : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$meta += "May do            : $($cpu.Name) | $($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) luong | RAM $ramGB GB"
$meta += "Docker            : $(docker --version)"
$meta += "Muc tai (ket noi) : $($Levels -join ', ')"
$meta += "Thoi luong/lan    : $DurationSec giay | So lan lap: $Repeats | Nghi giua cac lan: $CooldownSec giay"
$meta += "Tac vu            : $($Tasks -join ', ')  (read = GET /api/products, write = POST /api/orders)"
$meta += "Container dang chay:"
$meta += (docker ps --format "  {{.Names}} ({{.Status}})")
$meta += "nginx.conf dang dung:"
$meta += (docker exec ecommerce_lb cat /etc/nginx/nginx.conf 2>$null)
$meta | Out-File -Encoding utf8 $MetaFile
Write-Host "Da ghi cau hinh vao $MetaFile"

# --- Moc id don hang de don dep du lieu sau khi do ghi ---
$maxId = (docker exec ecommerce_db psql -U postgres -d ecommerce_db -t -A -c "SELECT COALESCE(MAX(id),0) FROM orders;").Trim()
Write-Host "Moc orders.id truoc khi do: $maxId"

# --- Worker chay trong runspace (moi worker = 1 ket noi lien tuc) ---
$worker = {
    param($url, $method, $body, $deadlineTicks)
    Add-Type -AssemblyName System.Net.Http
    $client = New-Object System.Net.Http.HttpClient
    $client.Timeout = [TimeSpan]::FromSeconds(10)
    $lat = New-Object System.Collections.Generic.List[double]
    $err = 0
    $sw = New-Object System.Diagnostics.Stopwatch
    while ([DateTime]::UtcNow.Ticks -lt $deadlineTicks) {
        $sw.Restart()
        try {
            if ($method -eq "POST") {
                $content = New-Object System.Net.Http.StringContent($body, [System.Text.Encoding]::UTF8, "application/json")
                $resp = $client.PostAsync($url, $content).Result
            } else {
                $resp = $client.GetAsync($url).Result
            }
            $sw.Stop()
            if ($resp.IsSuccessStatusCode) { $lat.Add($sw.Elapsed.TotalMilliseconds) } else { $err++ }
            $resp.Dispose()
        } catch {
            $sw.Stop()
            $err++
        }
    }
    $client.Dispose()
    [PSCustomObject]@{ Lat = $lat.ToArray(); Err = $err }
}

function Get-Pct($sorted, $p) {
    if ($sorted.Count -eq 0) { return 0 }
    $idx = [math]::Ceiling($p * $sorted.Count) - 1
    if ($idx -lt 0) { $idx = 0 }
    return $sorted[$idx]
}

function Save-DockerStats($level, $task, $rep) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $lines = docker stats --no-stream --format "{{.Name}};{{.CPUPerc}};{{.MemUsage}}" 2>$null
    foreach ($l in $lines) {
        $p = $l -split ";"
        if ($p.Count -ge 3) {
            [PSCustomObject]@{
                Time = $ts; Task = $task; Concurrency = $level; Repeat = $rep
                Container = $p[0]; CPU = $p[1]; Memory = $p[2]
            } | Export-Csv -Path $StatsCsv -Append -NoTypeInformation -Encoding UTF8
        }
    }
}

function Invoke-Run($level, $task, $rep) {
    if ($task -eq "read") { $url = "$BaseUrl/api/products"; $method = "GET" }
    else { $url = "$BaseUrl/api/orders"; $method = "POST" }
    $body = '{"product_id":1,"quantity":1}'

    $pool = [runspacefactory]::CreateRunspacePool(1, $level)
    $pool.Open()
    $start = Get-Date
    $deadline = [DateTime]::UtcNow.AddSeconds($DurationSec).Ticks
    $jobs = @()
    for ($i = 0; $i -lt $level; $i++) {
        $ps = [powershell]::Create()
        $ps.RunspacePool = $pool
        [void]$ps.AddScript($worker).AddArgument($url).AddArgument($method).AddArgument($body).AddArgument($deadline)
        $jobs += [PSCustomObject]@{ PS = $ps; Handle = $ps.BeginInvoke() }
    }

    # Trong luc cho, lay mau CPU/RAM cua cac container
    while (@($jobs | Where-Object { -not $_.Handle.IsCompleted }).Count -gt 0) {
        Save-DockerStats $level $task $rep
        Start-Sleep -Milliseconds 300
    }
    $elapsed = ((Get-Date) - $start).TotalSeconds

    $all = New-Object System.Collections.Generic.List[double]
    $errors = 0
    foreach ($j in $jobs) {
        $res = $j.PS.EndInvoke($j.Handle)
        if ($res -and $res.Count -gt 0) {
            $r = $res[0]
            if ($r.Lat) { $all.AddRange([double[]]$r.Lat) }
            $errors += [int]$r.Err
        }
        $j.PS.Dispose()
    }
    $pool.Close(); $pool.Dispose()

    $sorted = $all.ToArray() | Sort-Object
    $ok = $all.Count
    $total = $ok + $errors
    $avg = 0; if ($ok -gt 0) { $avg = ($all | Measure-Object -Average).Average }
    $max = 0; if ($ok -gt 0) { $max = ($all | Measure-Object -Maximum).Maximum }
    $errRate = 0; if ($total -gt 0) { $errRate = 100.0 * $errors / $total }

    $row = [PSCustomObject]@{
        Time        = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Label       = $Label
        Task        = $task
        Concurrency = $level
        Repeat      = $rep
        ActualSec   = [math]::Round($elapsed, 1)
        OkRequests  = $ok
        Errors      = $errors
        ErrorRatePct = [math]::Round($errRate, 2)
        Rps         = [math]::Round($ok / $elapsed, 1)
        AvgMs       = [math]::Round($avg, 1)
        P50Ms       = [math]::Round((Get-Pct $sorted 0.50), 1)
        P95Ms       = [math]::Round((Get-Pct $sorted 0.95), 1)
        MaxMs       = [math]::Round($max, 1)
    }
    $row | Export-Csv -Path $ResultsCsv -Append -NoTypeInformation -Encoding UTF8
    Write-Host ("[{0}] {1,-5} tai={2,-4} lan={3} | ok={4} loi={5} ({6}%) | {7} req/s | avg={8}ms p95={9}ms" -f `
        $row.Time, $task, $level, $rep, $ok, $errors, $row.ErrorRatePct, $row.Rps, $row.AvgMs, $row.P95Ms)
}

# --- Chay toan bo ---
Write-Host "=== BAT DAU DO TAI: $Label ===" -ForegroundColor Cyan
foreach ($task in $Tasks) {
    foreach ($level in $Levels) {
        for ($rep = 1; $rep -le $Repeats; $rep++) {
            Invoke-Run $level $task $rep
            Start-Sleep -Seconds $CooldownSec
        }
    }
}

# --- Tong hop (trung binh cac lan lap, kem min-max cua p95 de thay bien thien) ---
$data = Import-Csv $ResultsCsv
$summary = $data | Group-Object Task, Concurrency | ForEach-Object {
    $g = $_.Group
    $rps = $g | ForEach-Object { [double]$_.Rps } | Measure-Object -Average
    $avgMs = $g | ForEach-Object { [double]$_.AvgMs } | Measure-Object -Average
    $p95 = $g | ForEach-Object { [double]$_.P95Ms } | Measure-Object -Average -Minimum -Maximum
    $er = $g | ForEach-Object { [double]$_.ErrorRatePct } | Measure-Object -Average
    [PSCustomObject]@{
        Label        = $Label
        Task         = $g[0].Task
        Concurrency  = [int]$g[0].Concurrency
        Runs         = $g.Count
        RpsAvg       = [math]::Round($rps.Average, 1)
        AvgMsAvg     = [math]::Round($avgMs.Average, 1)
        P95MsAvg     = [math]::Round($p95.Average, 1)
        P95MsMin     = $p95.Minimum
        P95MsMax     = $p95.Maximum
        ErrorRatePct = [math]::Round($er.Average, 2)
    }
} | Sort-Object Task, Concurrency
$summary | Export-Csv -Path $SummaryCsv -NoTypeInformation -Encoding UTF8
Write-Host "`n=== TONG HOP ($Label) ===" -ForegroundColor Cyan
$summary | Format-Table -AutoSize

# --- Don dep don hang gia do tac vu write tao ra ---
if ($Tasks -contains "write" -and -not $KeepData) {
    $del = docker exec ecommerce_db psql -U postgres -d ecommerce_db -c "DELETE FROM orders WHERE id > $maxId;"
    Write-Host "Don dep du lieu thu: $del"
}
"Ket thuc: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Encoding utf8 $MetaFile
Write-Host "Xong. Du lieu goc nam trong $OutDir" -ForegroundColor Green