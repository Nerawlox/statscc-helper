#Requires -RunAsAdministrator
param([string]$ProfileJson, [string]$AppPath)
$ErrorActionPreference='Stop'
$source=$PSScriptRoot
$package=Split-Path $source
$installed=Join-Path $env:ProgramFiles 'StatsCC Helper'
$runtime=Join-Path $env:ProgramData 'StatsCC Helper'
$proxy=Join-Path $env:ProgramFiles 'ProxiFyre'
$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$progress=$null
Add-Type -AssemblyName System.Windows.Forms
. "$source\Profiles.ps1"
. "$source\Security.ps1"
. "$source\SetupUI.ps1"
function Set-Stage([string]$Text) {
    $label.Text=$Text; $progress.Refresh(); [Windows.Forms.Application]::DoEvents()
}
function Get-VerifiedDownload($Dependency,[string]$FileName) {
    $path=Join-Path $cache $FileName
    if (!(Test-Path -LiteralPath $path) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $Dependency.sha256) {
        Invoke-WebRequest -Uri $Dependency.url -OutFile $path -UseBasicParsing
    }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $Dependency.sha256) { throw 'DependencyChecksumFailed' }
    return $path
}
try {
    if (![Environment]::Is64BitOperatingSystem -or ![Environment]::Is64BitProcess -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') { throw 'WindowsX64Required' }
    if (Get-Process -Name ProxiFyre -ErrorAction SilentlyContinue) { throw 'StopHelperFirst' }
    if ((Test-Path -LiteralPath $installed) -and !(Test-Path -LiteralPath "$installed\statscc-helper.marker")) { throw 'InstallationFolderOccupied' }
    if ((Test-Path -LiteralPath $runtime) -and !(Test-Path -LiteralPath "$installed\statscc-helper.marker")) { throw 'RuntimeFolderOccupied' }
    foreach ($path in @($installed,$runtime)) {
        if ((Test-Path -LiteralPath $path) -and ((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'ReparsePointNotAllowed' }
    }
    $existingConfig=Join-Path $proxy 'app-config.json'
    if (!(Test-HelperRoutingOwnership $existingConfig "$installed\app-config.json")) { throw 'ExistingProxiFyreConfiguration' }
    $existingTask=Get-ScheduledTask -TaskName 'StatsCC Independent Helper' -ErrorAction SilentlyContinue
    if ($existingTask) {
        if ($existingTask.State -eq 'Running') { throw 'StopHelperFirst' }
        if (!(Test-Path -LiteralPath "$installed\statscc-helper.marker") -or $existingTask.Actions.Count -ne 1 -or $existingTask.Actions.Execute -ne "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -or $existingTask.Actions.Arguments -ne "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$installed\Launch.ps1`"") { throw 'UnexpectedTask' }
        if ($existingTask.Principal.UserId -like 'S-1-*') { $taskSid=$existingTask.Principal.UserId }
        else { $taskSid=(New-Object Security.Principal.NTAccount -ArgumentList $existingTask.Principal.UserId).Translate([Security.Principal.SecurityIdentifier]).Value }
        if ($taskSid -ne $sid) { throw 'TaskBelongsToAnotherUser' }
    }
    if (!$AppPath) { $AppPath=Join-Path $env:LOCALAPPDATA 'Programs\stats.cc\stats.cc.exe' }
    if (!(Test-Path -LiteralPath $AppPath)) {
        $picker=New-Object Windows.Forms.OpenFileDialog
        $picker.Title='Выбери установленный stats.cc.exe'; $picker.Filter='stats.cc|stats.cc.exe'
        if ($picker.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { throw 'Cancelled' }
        $AppPath=$picker.FileName
    }
    $AppPath=(Resolve-Path -LiteralPath $AppPath).Path
    if ([IO.Path]::GetFileName($AppPath) -ne 'stats.cc.exe') { throw 'StatsExecutableRequired' }
    if ($ProfileJson) {
        $items=@(Get-XrayOutbounds ([IO.File]::ReadAllText((Resolve-Path -LiteralPath $ProfileJson).Path)))
        if ($items.Count -ne 1) { throw 'ExpectedSingleOutbound' }
        $outbound=$items[0]
    } else { $outbound=Select-SetupOutbound $source }
    $confirmation=[Windows.Forms.MessageBox]::Show("Установка направит только stats.cc через отдельное соединение.`n`nЕсли Windows Packet Filter ещё не установлен, его установка может кратко прервать сеть. Автоматической перезагрузки не будет.`n`nProxiFyre выпускает установщик без подписи; контрольная сумма проверяется по официальной публикации. Продолжить?",'Установка помощника stats.cc','OKCancel','Information')
    if ($confirmation -ne [Windows.Forms.DialogResult]::OK) { throw 'Cancelled' }
    $progress=New-Object Windows.Forms.Form; $progress.Text='Установка stats.cc helper'; $progress.Width=480; $progress.Height=140; $progress.StartPosition='CenterScreen'; $progress.ControlBox=$false
    $label=New-Object Windows.Forms.Label; $label.SetBounds(20,20,430,65); $progress.Controls.Add($label); $progress.Show()
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    $cache=Join-Path $package '.downloads'; New-Item -ItemType Directory -Path $cache -Force | Out-Null
    $dependencies=Get-Content -LiteralPath "$package\dependencies.json" -Raw | ConvertFrom-Json
    Set-Stage 'Скачивание Xray с официальной страницы...'
    $zip=Get-VerifiedDownload $dependencies.xray 'xray.zip'
    $extract=Join-Path $cache 'xray'; Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
    $core=Join-Path $extract 'xray.exe'
    if ((Get-FileHash -LiteralPath $core -Algorithm SHA256).Hash -ne $dependencies.xray.executableSha256) { throw 'DependencyChecksumFailed' }
    Test-XrayOutbound $outbound $core
    [byte[]]$sealed=Protect-Outbound $outbound
    $outbound=$null
    Set-Stage 'Подготовка ProxiFyre и сетевого фильтра...'
    $setup=Get-VerifiedDownload $dependencies.proxifyre 'proxifyre-setup.exe'
    $installer=Start-Process -FilePath $setup -ArgumentList '/install','/quiet','/norestart' -WindowStyle Hidden -PassThru
    $installer.WaitForExit()
    $exitCode=$installer.ExitCode
    if ($exitCode -notin @(0,3010)) { throw 'DependencyInstallationFailed' }
    if (!(Test-Path -LiteralPath "$proxy\ProxiFyre.exe")) { throw 'ProxiFyreNotInstalled' }
    Set-Stage 'Создание защищённого профиля и кнопок запуска...'
    New-Item -ItemType Directory -Path $installed,$runtime -Force | Out-Null
    Set-HelperDirectoryAcl $installed
    New-Item -ItemType Directory -Path "$installed\bin" -Force | Out-Null
    Set-HelperDirectoryAcl "$installed\bin"
    foreach ($file in @('Core.ps1','Launch.ps1','Job.cs','Start.vbs','Stop.vbs')) { Copy-Item -LiteralPath "$source\$file" -Destination "$installed\$file" -Force }
    Copy-Item -LiteralPath $core,"$extract\LICENSE" -Destination "$installed\bin" -Force
    Copy-Item -LiteralPath "$package\LICENSE","$package\THIRD-PARTY.md" -Destination $installed -Force
    [IO.File]::WriteAllBytes("$installed\profile.dpapi",$sealed)
    [Array]::Clear($sealed,0,$sealed.Length)
    @{appPath=$AppPath} | ConvertTo-Json | Set-Content -LiteralPath "$installed\settings.json" -Encoding UTF8
    $routing=New-StatsRoutingConfig $AppPath | ConvertTo-Json -Depth 20
    $routing | Set-Content -LiteralPath "$installed\app-config.json" -Encoding UTF8
    $routing | Set-Content -LiteralPath $existingConfig -Encoding UTF8
    'StatsCCIndependentHelper-1' | Set-Content -LiteralPath "$installed\statscc-helper.marker" -Encoding ASCII
    Initialize-HelperState $runtime $sid
    $action=New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$installed\Launch.ps1`"" -WorkingDirectory $installed
    $principal=New-ScheduledTaskPrincipal -UserId $sid -LogonType Interactive -RunLevel Highest
    $settings=New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName 'StatsCC Independent Helper' -Action $action -Principal $principal -Settings $settings -Description 'Only stats.cc via a separate proxy. Manual start, no automatic triggers.' -Force | Out-Null
    $shell=New-Object -ComObject WScript.Shell
    $desktop=[Environment]::GetFolderPath('DesktopDirectory')
    foreach ($entry in @(@('stats.cc helper.lnk','Start.vbs'),@('Stop stats.cc helper.lnk','Stop.vbs'))) {
        $shortcutPath=Join-Path $desktop $entry[0]
        if (!(Test-Path -LiteralPath $shortcutPath)) {
            $link=$shell.CreateShortcut($shortcutPath); $link.TargetPath=Join-Path $env:SystemRoot 'System32\wscript.exe'
            $link.Arguments='"'+(Join-Path $installed $entry[1])+'"'; $link.WorkingDirectory=$installed; $link.IconLocation=$AppPath+',0'; $link.Save()
        }
    }
    $progress.Close(); $progress=$null
    $message='Установлено. Запускай stats.cc helper с рабочего стола. Общий VPN для трекера не требуется. Обновить профиль можно повторным запуском Install.cmd после остановки помощника.'
    if ($exitCode -eq 3010) { $message='Установлено. Windows запросила перезагрузку для завершения установки фильтра. Перезагрузи компьютер в удобное время, затем используй ярлык stats.cc helper.' }
    [void][Windows.Forms.MessageBox]::Show($message,'stats.cc helper','OK','Information')
} catch {
    if ($progress) { $progress.Close() }
    if ($_.Exception.Message -eq 'Cancelled') { exit }
    # Never show raw JSON/parser exceptions containing credentials.
    $code=$_.Exception.Message
    if ($code -notmatch '^[A-Za-z]+$') { $code='SetupFailed' }
    [void][Windows.Forms.MessageBox]::Show("Установка остановлена: $code.`nПроверь инструкцию README.md и повтори настройку. Параметры профиля не выводятся в диагностику.",'stats.cc helper','OK','Error')
    exit 1
}
