function Set-HelperDirectoryAcl([string]$Path, [string]$ReadUserSid = 'S-1-5-32-545') {
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true,$false)
    $acl.SetOwner((New-Object Security.Principal.SecurityIdentifier -ArgumentList 'S-1-5-32-544'))
    foreach ($entry in @(@('S-1-5-18','FullControl'),@('S-1-5-32-544','FullControl'),@($ReadUserSid,'ReadAndExecute'))) {
        $sid = New-Object Security.Principal.SecurityIdentifier -ArgumentList $entry[0]
        $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule -ArgumentList @($sid,$entry[1],'ContainerInherit, ObjectInherit','None','Allow')))
    }
    Set-Acl -LiteralPath $Path -AclObject $acl
}

function Initialize-HelperState([string]$Path, [string]$UserSid) {
    Set-HelperDirectoryAcl $Path $UserSid
    [IO.File]::WriteAllText((Join-Path $Path 'stop.request'),'')
    $acl = New-Object Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true,$false)
    $acl.SetOwner((New-Object Security.Principal.SecurityIdentifier -ArgumentList 'S-1-5-32-544'))
    foreach ($entry in @(@('S-1-5-18','FullControl'),@('S-1-5-32-544','FullControl'),@($UserSid,'Read, Write'))) {
        $sid = New-Object Security.Principal.SecurityIdentifier -ArgumentList $entry[0]
        $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule -ArgumentList @($sid,$entry[1],'Allow')))
    }
    Set-Acl -LiteralPath (Join-Path $Path 'stop.request') -AclObject $acl
}

function Test-HelperRoutingOwnership([string]$ActualPath, [string]$SavedPath) {
    if (!(Test-Path -LiteralPath $ActualPath)) { return $true }
    if (!(Test-Path -LiteralPath $SavedPath)) { return $false }
    try {
        $actual = Get-Content -LiteralPath $ActualPath -Raw | ConvertFrom-Json
        $saved = Get-Content -LiteralPath $SavedPath -Raw | ConvertFrom-Json
        return (($actual | ConvertTo-Json -Depth 20 -Compress) -eq ($saved | ConvertTo-Json -Depth 20 -Compress))
    } catch { return $false }
}

function New-StatsRoutingConfig([string]$AppPath) {
    return [ordered]@{
        logLevel='Info';bypassLan=$true
        proxies=@(@{appNames=@($AppPath);socks5ProxyEndpoint='127.0.0.1:21981';socks5Transport='TCP';supportedProtocols=@('TCP','UDP');supportedAddressFamilies=@('IPv4','IPv6')})
        excludes=@('Throne.exe','ThroneCore.exe','xray.exe','gearup_booster.exe','gearup_ball.exe','RainbowSix.exe','RainbowSix_Vulkan.exe','BEService.exe')
    }
}
