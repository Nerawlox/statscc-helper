function Start-StatsCore {
    param([string]$Root, [int]$Port = 21980)
    Add-Type -AssemblyName System.Security
    $adapters = @(Get-NetAdapter -Physical | Where-Object Status -eq Up)
    $candidates = foreach ($a in $adapters) {
        $ip = Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.AddressState -eq 'Preferred' -and $_.IPAddress -notlike '169.254.*' } | Select-Object -First 1
        $route = Get-NetRoute -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($ip -and $route) { [pscustomobject]@{ Name=$a.Name; IP=$ip.IPAddress; Metric=$route.RouteMetric } }
    }
    $nic = $candidates | Sort-Object Metric | Select-Object -First 1
    if (!$nic) { throw 'NoPhysicalNetwork' }
    $secret = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes("$Root\profile.dpapi"), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    $outbound = [Text.Encoding]::UTF8.GetString($secret) | ConvertFrom-Json
    [Array]::Clear($secret, 0, $secret.Length)
    $outbound | Add-Member -NotePropertyName tag -NotePropertyValue 'stats-upstream' -Force
    if (!$outbound.streamSettings) { $outbound | Add-Member -NotePropertyName streamSettings -NotePropertyValue ([pscustomobject]@{}) -Force }
    $outbound | Add-Member -NotePropertyName sendThrough -NotePropertyValue $nic.IP -Force
    $outbound.streamSettings | Add-Member -NotePropertyName sockopt -NotePropertyValue @{ interface=$nic.Name; domainStrategy='UseIPv4' } -Force
    $download = $outbound.streamSettings.xhttpSettings.extra.downloadSettings
    if ($download) { $download | Add-Member -NotePropertyName sockopt -NotePropertyValue @{ interface=$nic.Name; domainStrategy='UseIPv4' } -Force }
    $config = @{
        log = @{ loglevel='none' }
        inbounds = @(
            @{ listen='127.0.0.1'; port=$Port; protocol='http'; tag='stats-http'; settings=@{} },
            @{ listen='127.0.0.1'; port=($Port + 1); protocol='socks'; tag='stats-socks'; settings=@{auth='noauth';udp=$true;ip='127.0.0.1'} }
        )
        outbounds = @($outbound)
    } | ConvertTo-Json -Depth 50 -Compress
    $info = New-Object Diagnostics.ProcessStartInfo -ArgumentList @("$Root\bin\xray.exe", 'run -config stdin: -format json')
    $info.WorkingDirectory = "$Root\bin"
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $core = [Diagnostics.Process]::Start($info)
    $null = $core.StandardOutput.ReadToEndAsync()
    $null = $core.StandardError.ReadToEndAsync()
    $configBytes = [Text.Encoding]::UTF8.GetBytes($config)
    $core.StandardInput.BaseStream.Write($configBytes,0,$configBytes.Length)
    $core.StandardInput.Close()
    [Array]::Clear($configBytes,0,$configBytes.Length)
    $config = $null
    $outbound = $null
    for ($i = 0; $i -lt 60; $i++) {
        if ($core.HasExited) { throw 'CoreConfigurationFailed' }
        $client = [Net.Sockets.TcpClient]::new()
        try { $client.Connect('127.0.0.1', $Port); break } catch { Start-Sleep -Milliseconds 200 } finally { $client.Dispose() }
    }
    if ($i -eq 60) { $core.Kill(); throw 'CoreStartTimeout' }
    return $core
}
