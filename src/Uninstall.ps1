#Requires -RunAsAdministrator
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
try {
    $expected=Join-Path $env:ProgramFiles 'StatsCC Helper'
    if (!(Test-Path -LiteralPath "$expected\statscc-helper.marker")) { throw 'HelperNotInstalled' }
    $root=(Resolve-Path -LiteralPath $expected).Path
    if ($root -ne $expected -or ((Get-Item -LiteralPath $root).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'UnexpectedInstallationPath' }
    if (@(Get-ChildItem -LiteralPath $root -Recurse -Force | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count) { throw 'ReparsePointNotAllowed' }
    $task=Get-ScheduledTask -TaskName 'StatsCC Independent Helper' -ErrorAction SilentlyContinue
    if ($task -and $task.Actions.Arguments -notlike "*$root\Launch.ps1*") { throw 'UnexpectedTask' }
    $runtime=Join-Path $env:ProgramData 'StatsCC Helper'
    if ((Test-Path -LiteralPath $runtime) -and ((Get-Item -LiteralPath $runtime).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'UnexpectedRuntimePath' }
    if ([Windows.Forms.MessageBox]::Show('Удалить helper, его профиль и задачу? ProxiFyre и сетевой фильтр останутся установленными.','stats.cc helper','OKCancel','Question') -ne [Windows.Forms.DialogResult]::OK) { exit }
    if (Test-Path -LiteralPath "$runtime\stop.request") { [IO.File]::WriteAllText("$runtime\stop.request",'stop') }
    for ($i=0;$i -lt 15;$i++) {
        $current=Get-ScheduledTask -TaskName 'StatsCC Independent Helper' -ErrorAction SilentlyContinue
        if (!$current -or $current.State -ne 'Running') { break }
        Start-Sleep -Seconds 1
    }
    if ($current -and $current.State -eq 'Running') { throw 'StopHelperFirst' }
    if ($task) { Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false }
    $proxyConfig=Join-Path $env:ProgramFiles 'ProxiFyre\app-config.json'
    if ((Test-Path -LiteralPath $proxyConfig) -and (Get-FileHash -LiteralPath $proxyConfig).Hash -eq (Get-FileHash -LiteralPath "$root\app-config.json").Hash) { Remove-Item -LiteralPath $proxyConfig }
    $shell=New-Object -ComObject WScript.Shell
    $desktop=[Environment]::GetFolderPath('DesktopDirectory')
    foreach ($entry in @(@('stats.cc helper.lnk','Start.vbs'),@('Stop stats.cc helper.lnk','Stop.vbs'))) {
        $path=Join-Path $desktop $entry[0]
        if (Test-Path -LiteralPath $path) {
            $link=$shell.CreateShortcut($path)
            if ($link.Arguments -eq ('"'+(Join-Path $root $entry[1])+'"')) { Remove-Item -LiteralPath $path }
        }
    }
    Remove-Item -LiteralPath $root -Recurse -Force
    if (Test-Path -LiteralPath $runtime) {
        $resolved=(Resolve-Path -LiteralPath $runtime).Path
        if ($resolved -ne $runtime -or @(Get-ChildItem -LiteralPath $resolved -Recurse -Force | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count) { throw 'UnexpectedRuntimePath' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    [void][Windows.Forms.MessageBox]::Show('Helper удалён. Общие зависимости можно удалить через настройки Windows.','stats.cc helper','OK','Information')
} catch {
    $code=$_.Exception.Message
    if ($code -notmatch '^[A-Za-z]+$') { $code='UninstallFailed' }
    [void][Windows.Forms.MessageBox]::Show("Удаление остановлено: $code",'stats.cc helper','OK','Error')
    exit 1
}
