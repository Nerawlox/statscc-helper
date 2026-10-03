function Get-XrayOutbounds([string]$Json) {
    $value = $Json | ConvertFrom-Json -ErrorAction Stop
    if ($value.protocol) { $values = @($value) }
    elseif ($value.outbounds) { $values = @($value.outbounds) }
    else { throw 'ExpectedXrayOutbound' }
    $supported = @('vless','vmess','trojan','shadowsocks','socks','http')
    $items = @($values | Where-Object { $_.protocol -in $supported })
    if (!$items.Count) { throw 'UnsupportedOutboundProtocol' }
    foreach ($o in $items) {
        if (!$o.settings) { throw 'OutboundSettingsMissing' }
        if ($o.proxySettings.tag -or $o.streamSettings.sockopt.dialerProxy) { throw 'ChainedOutboundsUnsupported' }
        if ($o.streamSettings.network -in @('kcp','mkcp','quic','hysteria')) { throw 'UdpCarrierUnsupported' }
    }
    return $items
}

function Get-ThroneProfiles([string]$Database) {
    $rows = [ThroneSqlite]::Query($Database, 'SELECT id,name,type FROM profiles ORDER BY id')
    foreach ($row in $rows) {
        if ($row[2] -like 'xray*') {
            [pscustomobject]@{Id=[int]$row[0];Name=$row[1];Type=$row[2]}
        }
    }
}

function Get-ThroneOutbound([string]$Database, [int]$Id) {
    $rows = [ThroneSqlite]::Query($Database, "SELECT p.outbound_json,g.front_proxy_id,g.landing_proxy_id FROM profiles p LEFT JOIN groups g ON p.gid=g.id WHERE p.id=$Id")
    if ($rows.Length -ne 1) { throw 'ThroneProfileNotFound' }
    if (($rows[0][1] -and [int]$rows[0][1] -gt 0) -or ($rows[0][2] -and [int]$rows[0][2] -gt 0)) { throw 'ChainedOutboundsUnsupported' }
    $items = @(Get-XrayOutbounds $rows[0][0])
    if ($items.Count -ne 1) { throw 'ExpectedSingleOutbound' }
    return $items[0]
}

function Protect-Outbound($Outbound) {
    Add-Type -AssemblyName System.Security
    $bytes = [Text.Encoding]::UTF8.GetBytes(($Outbound | ConvertTo-Json -Depth 50 -Compress))
    try { return [Security.Cryptography.ProtectedData]::Protect($bytes,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser) }
    finally { [Array]::Clear($bytes,0,$bytes.Length) }
}

function Test-XrayOutbound($Outbound, [string]$CorePath) {
    $config = @{log=@{loglevel='none'};outbounds=@($Outbound)} | ConvertTo-Json -Depth 50 -Compress
    $info = New-Object Diagnostics.ProcessStartInfo -ArgumentList @($CorePath,'run -test -config stdin: -format json')
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.RedirectStandardInput=$true; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    $p = [Diagnostics.Process]::Start($info)
    $null=$p.StandardOutput.ReadToEndAsync(); $null=$p.StandardError.ReadToEndAsync()
    $bytes=[Text.Encoding]::UTF8.GetBytes($config)
    try { $p.StandardInput.BaseStream.Write($bytes,0,$bytes.Length); $p.StandardInput.Close() }
    finally { [Array]::Clear($bytes,0,$bytes.Length) }
    if (!$p.WaitForExit(10000)) { $p.Kill(); throw 'CoreValidationTimeout' }
    if ($p.ExitCode -ne 0) { throw 'CoreConfigurationRejected' }
}
