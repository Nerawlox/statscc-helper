param([string]$Version='0.1.1')
$ErrorActionPreference='Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+(?:-[a-zA-Z0-9.-]+)?$') { throw 'Invalid version' }
$root=Split-Path $PSScriptRoot
$dist=Join-Path $root 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$zip=Join-Path $dist "statscc-helper-$Version-windows-x64.zip"
$allowed=@(
    'Install.cmd','Uninstall.cmd','README.md','LICENSE','THIRD-PARTY.md','CHANGELOG.md','CONTRIBUTING.md','dependencies.json',
    'src/Core.ps1','src/Launch.ps1','src/Job.cs','src/Profiles.ps1','src/ThroneSqlite.cs',
    'src/Security.ps1','src/SetupUI.ps1','src/Setup.ps1','src/Uninstall.ps1','src/Start.vbs','src/Stop.vbs',
    'scripts/Build.ps1','scripts/Test.ps1','tests/SqliteFixture.cs'
)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream=[IO.File]::Open($zip,[IO.FileMode]::Create)
$archive=New-Object IO.Compression.ZipArchive -ArgumentList @($stream,[IO.Compression.ZipArchiveMode]::Create,$false)
try {
    foreach ($name in $allowed) {
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,(Join-Path $root $name),$name,[IO.Compression.CompressionLevel]::Optimal)
    }
} finally { $archive.Dispose(); $stream.Dispose() }
$hash=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([IO.Path]::GetFileName($zip))" | Set-Content -LiteralPath "$zip.sha256" -Encoding ASCII
Write-Output $zip
