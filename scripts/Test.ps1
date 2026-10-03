param([string]$CorePath)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
function Assert([bool]$Value,[string]$Message) { if (!$Value) { throw $Message } }
function Assert-Rejected([scriptblock]$Action,[string]$Message) {
    $failed=$false
    try { $null=& $Action } catch { $failed=$true }
    Assert $failed $Message
}
foreach($file in Get-ChildItem -LiteralPath $root -Recurse -Filter '*.ps1' | Where-Object FullName -notlike '*\.local\*') {
    $tokens=$null; $errors=$null
    $null=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    Assert ($errors.Count -eq 0) "Syntax error: $($file.Name)"
}
. "$root\src\Profiles.ps1"
. "$root\src\Security.ps1"
Add-Type -Path "$root\src\ThroneSqlite.cs"
Add-Type -Path "$root\src\Job.cs"
Add-Type -Path "$root\tests\SqliteFixture.cs"
# Deliberately synthetic data: no live server or user account is involved.
$sample='{"protocol":"vless","settings":{"address":"fixture.invalid","port":443,"id":"00000000-0000-0000-0000-000000000000","encryption":"none"},"streamSettings":{"network":"tcp","security":"none"}}'
$o=@(Get-XrayOutbounds $sample)
Assert ($o.Count -eq 1 -and $o[0].protocol -eq 'vless') 'Single outbound parsing failed'
$full='{"outbounds":['+$sample+',{"protocol":"freedom","settings":{}}]}'
Assert (@(Get-XrayOutbounds $full).Count -eq 1) 'Full config must select proxy outbound only'
Assert-Rejected { Get-XrayOutbounds '{"protocol":"freedom","settings":{}}' } 'Direct outbound accepted'
Assert-Rejected { Get-XrayOutbounds '{"protocol":"vless","settings":{},"proxySettings":{"tag":"chain"}}' } 'Chained outbound accepted'
Assert-Rejected { Get-XrayOutbounds '{"protocol":"vless","settings":{"port":443},"streamSettings":{"network":"quic"}}' } 'Unsupported UDP carrier accepted'
Add-Type -AssemblyName System.Security
[byte[]]$sealed=Protect-Outbound $o[0]
$plain=[Security.Cryptography.ProtectedData]::Unprotect($sealed,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
Assert (([Text.Encoding]::UTF8.GetString($plain) | ConvertFrom-Json).settings.address -eq 'fixture.invalid') 'DPAPI round trip failed'
[Array]::Clear($plain,0,$plain.Length)
Assert ([Text.Encoding]::UTF8.GetString($sealed) -notlike '*fixture.invalid*') 'DPAPI output contains plaintext'
$route=New-StatsRoutingConfig 'C:\Fixture\stats.cc.exe'
Assert ($route.proxies.Count -eq 1 -and $route.proxies[0].appNames.Count -eq 1 -and $route.proxies[0].appNames[0] -eq 'C:\Fixture\stats.cc.exe') 'Routing rule must target one exe'
Assert ($route.excludes -contains 'ThroneCore.exe' -and $route.excludes -contains 'RainbowSix.exe') 'Exclusions missing'
$local=Join-Path $root ('.local\test-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $local -Force | Out-Null
$savedConfig=Join-Path $local 'saved.json'
$actualConfig=Join-Path $local 'actual.json'
$route | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $savedConfig -Encoding UTF8
Assert (Test-HelperRoutingOwnership $actualConfig $savedConfig) 'First installation must allow absent config'
$route | ConvertTo-Json -Depth 20 -Compress | Set-Content -LiteralPath $actualConfig -Encoding UTF8
Assert (Test-HelperRoutingOwnership $actualConfig $savedConfig) 'Own config must allow reinstallation'
(New-StatsRoutingConfig 'C:\Other\stats.cc.exe') | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $actualConfig -Encoding UTF8
Assert (!(Test-HelperRoutingOwnership $actualConfig $savedConfig)) 'Changed routing must be preserved'
Assert (!(Test-HelperRoutingOwnership $actualConfig (Join-Path $local 'absent.json'))) 'Foreign config must be preserved'
$db=Join-Path $local 'fixture.db'
[SqliteFixture]::Create($db,$sample)
$before=(Get-FileHash -LiteralPath $db).Hash
$profiles=@(Get-ThroneProfiles $db)
Assert ($profiles.Count -eq 1 -and $profiles[0].Id -eq 7) 'Throne profile listing failed'
$imported=Get-ThroneOutbound $db 7
Assert ($imported.settings.address -eq 'fixture.invalid') 'Throne outbound import failed'
Assert-Rejected { [ThroneSqlite]::Query($db,"UPDATE profiles SET name='changed'") } 'SQLite must be read-only'
Assert ((Get-FileHash -LiteralPath $db).Hash -eq $before) 'Import changed database'
$job=$null; $child=$null
try {
    $child=Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList '-NoProfile','-Command','Start-Sleep -Seconds 30' -WindowStyle Hidden -PassThru
    $job=New-Object StatsHelperJob; $job.Add($child); $job.Dispose(); $job=$null
    Assert ($child.WaitForExit(5000)) 'Job cleanup did not stop helper child'
} finally {
    if ($job) { $job.Dispose() }
    if ($child -and !$child.HasExited) { $child.Kill() }
}
if ($CorePath) { Test-XrayOutbound $o[0] $CorePath }
$resolved=(Resolve-Path -LiteralPath $local).Path
if (!$resolved.StartsWith((Join-Path $root '.local')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected fixture cleanup path' }
Remove-Item -LiteralPath $resolved -Recurse -Force
Write-Output 'PASS: syntax, import validation, DPAPI, scope, read-only Throne import, child cleanup'
