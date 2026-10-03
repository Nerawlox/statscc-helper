$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$runtime = Join-Path $env:ProgramData 'StatsCC Helper'
$app = (Get-Content -LiteralPath "$root\settings.json" -Raw | ConvertFrom-Json).appPath
$proxyPath = Join-Path $env:ProgramFiles 'ProxiFyre\ProxiFyre.exe'
$mutex = New-Object Threading.Mutex -ArgumentList @($false, 'Local\StatsCCIndependentHelper')
if (!$mutex.WaitOne(0)) { $mutex.Dispose(); exit }
$core = $null
$router = $null
$job = $null
$status = 'Starting'
function Write-Status([string]$Value) {
    @{status=$Value;time=(Get-Date).ToString('o');controllerPid=$PID} | ConvertTo-Json | Set-Content -LiteralPath "$runtime\status.json" -Encoding UTF8
}
function Get-StatsProcesses {
    @(Get-Process -Name 'stats.cc' -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $app })
}
function Get-StopRequested {
    try { return ([IO.File]::ReadAllText("$runtime\stop.request").Trim() -eq 'stop') } catch { return $false }
}
function Show-Error([string]$Message) {
    Add-Type -AssemblyName System.Windows.Forms
    [void][Windows.Forms.MessageBox]::Show($Message, 'stats.cc — отдельное подключение', 'OK', 'Error')
}
try {
    if (!(Test-Path -LiteralPath $runtime)) { throw 'NotInstalled' }
    Write-Status 'Starting'
    if (!(Test-Path -LiteralPath $app)) { throw 'StatsNotFound' }
    if (!(Test-Path -LiteralPath $proxyPath)) { throw 'NotInstalled' }
    $expected = Get-Content -LiteralPath "$root\app-config.json" -Raw | ConvertFrom-Json
    $actual = Get-Content -LiteralPath (Join-Path (Split-Path $proxyPath) 'app-config.json') -Raw | ConvertFrom-Json
    if (($actual | ConvertTo-Json -Depth 20 -Compress) -ne ($expected | ConvertTo-Json -Depth 20 -Compress)) { throw 'RoutingChanged' }
    if ((Get-Service -Name ProxiFyreService -ErrorAction SilentlyContinue).Status -eq 'Running' -or (Get-Process -Name ProxiFyre -ErrorAction SilentlyContinue)) { throw 'RouterAlreadyRunning' }
    if (Get-NetTCPConnection -LocalPort 21980,21981 -State Listen -ErrorAction SilentlyContinue) { throw 'PortsBusy' }
    [IO.File]::WriteAllText("$runtime\stop.request", '')
    Start-Service -Name NDISRD
    Add-Type -Path "$root\Job.cs"
    $job = New-Object StatsHelperJob
    . "$root\Core.ps1"
    $core = Start-StatsCore $root
    $job.Add($core)
    $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
    $probe = & $curl -sS --compressed --max-time 20 --proxy socks5h://127.0.0.1:21981 'https://api.stats.cc/v1/overlay/config' -o NUL -w '%{http_code}' 2>$null
    if ($LASTEXITCODE -ne 0 -or $probe -ne '200') { throw 'UpstreamUnavailable' }
    $router = Start-Process -FilePath $proxyPath -WorkingDirectory (Split-Path $proxyPath) -WindowStyle Hidden -PassThru
    $job.Add($router)
    Start-Sleep -Seconds 3
    if ($router.HasExited) { throw 'RouterStartFailed' }
    # Restart only this overlay so its existing direct sockets are replaced.
    Get-StatsProcesses | Stop-Process -Force
    Start-Sleep -Milliseconds 600
    $null = Start-Process -FilePath $app -PassThru
    for ($i=0; $i -lt 40; $i++) {
        if ((Get-StatsProcesses).Count -gt 0) { break }
        Start-Sleep -Milliseconds 250
    }
    if ($i -eq 40) { throw 'StatsStartFailed' }
    Write-Status 'Running'
    while ((Get-StatsProcesses).Count -gt 0) {
        if (Get-StopRequested) {
            Get-StatsProcesses | Stop-Process -Force
            break
        }
        if ($core.HasExited -or $router.HasExited) { throw 'HelperExited' }
        Start-Sleep -Seconds 1
    }
    $status = 'Stopped'
} catch {
    $status = 'Error'
    $known = $_.Exception.Message
    $message = switch ($known) {
        'PortsBusy' {'Порты помощника заняты. Закрой предыдущий помощник и попробуй снова.'}
        'StatsNotFound' {'stats.cc не найден в обычной папке установки. Нужна проверка пути приложения.'}
        'RoutingChanged' {'Правило ProxiFyre изменено. Помощник остановлен, чтобы не затронуть другие программы.'}
        'RouterAlreadyRunning' {'ProxiFyre уже запущен. Закрой его перед отдельным запуском stats.cc.'}
        'UpstreamUnavailable' {'Не удалось подключиться к сохранённому серверу. Интернет или параметры сервера изменились.'}
        'NoPhysicalNetwork' {'Не найдена подключённая физическая сеть Wi-Fi или Ethernet.'}
        'StatsStartFailed' {'stats.cc не запустился. Повтори запуск после завершения обновления приложения.'}
        default {'Помощник не смог запуститься. Проверь установку ProxiFyre и сетевого фильтра. Техническое состояние: C:\ProgramData\StatsCC Helper\status.json.'}
    }
    if (Test-Path -LiteralPath $runtime) {
        @{status='Error';category=if ($known -match '^[A-Za-z]+$') {$known} else {'StartupFailure'};time=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath "$runtime\status.json" -Encoding UTF8
    }
    Show-Error $message
} finally {
    if ($job) { $job.Dispose() }
    foreach ($child in @($router,$core)) {
        if ($child) { try { if (!$child.HasExited) { $child.Kill(); $child.WaitForExit(3000) | Out-Null } } catch {} }
    }
    if ($status -eq 'Stopped') { Write-Status 'Stopped' }
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
