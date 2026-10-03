# Reporting a problem

Open an issue and include:

- Your Windows and stats.cc versions.
- The helper version and import method: Throne or Xray JSON.
- The protocol and transport, without server addresses or credentials.
- Expected behavior, actual behavior and the error category from `status.json`.
- Whether your normal connection to the same server works.

Do not publish `profile.dpapi`, connection JSON, `throne.db`, subscription links,
UUIDs, passwords, keys, stats.cc account credentials or complete network logs.
Before sharing screenshots, check for profile names, addresses and user paths.

# Code changes

For a pull request, describe the change and how you tested it. Preserve UTF-8 with
BOM for `.ps1` files: the installer uses Windows PowerShell 5.1.

Run on Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Test.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Build.ps1
```

Tests use synthetic connection data. Use the same approach for new tests; do not
add real profiles or binary dependencies. If you change the package contents,
update the explicit file list in `scripts/Build.ps1`.

Full installation testing requires a separate Windows system with stats.cc and
your own server. Passing automated checks does not establish compatibility with
all providers and configurations.
