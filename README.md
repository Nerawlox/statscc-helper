# statscc-helper

An independent connection for the **stats.cc overlay** on Windows. Route the
installed `stats.cc.exe` through your own server while leaving your general VPN off.

The method is **not tied to Throne**. Import a connection from Throne, or select an
outbound from an Xray JSON file. Throne is not required when importing JSON, and
does not need to stay open after importing a profile.

**You need your own working server or subscription.** This project sets up routing
for the tracker; it does not provide servers or free proxy access.

The installer runs once to set up the components and shortcuts. After that, one
shortcut starts the regular stats.cc overlay and the helper's background processes.
A successful launch opens no extra helper window, console or tray icon.
An error dialog appears if startup fails.

> **Experimental release.** The underlying method has been confirmed working on
> one Windows computer with VLESS + REALITY + XHTTP and the general VPN off.
> The generic installer has automated checks, but has not been validated across
> different Windows installations, servers and providers.

## How it works

```text
stats.cc -> ProxiFyre (rule for one executable)
         -> SOCKS5 127.0.0.1:21981 -> independent Xray -> your server
```

Xray does not create a TUN adapter or change the Windows system proxy. Its outbound
connection is bound to a physical Wi-Fi/Ethernet interface. ProxiFyre routes the
stats.cc processes' TCP/UDP traffic, including the embedded browser and WebSocket
connections. Local network destinations bypass the proxy. The game, GearUP and
the main Throne processes are excluded from the rules.

## Requirements

- Windows 10/11 **x64**, Windows PowerShell 5.1 and an administrator account.
- The installed [stats.cc overlay](https://www.stats.cc/overlay).
- A working Xray-compatible connection.
- Access to GitHub during setup to download dependencies.

The importer accepts Xray JSON outbounds using `vless`, `vmess`, `trojan`,
`shadowsocks`, `socks` or `http` with a TCP-based transport. **VLESS + REALITY + XHTTP**
is the configuration tested in practice. Other combinations need testing with
your server. Native sing-box, WireGuard/OpenVPN profiles, outbound chains and
UDP-based transports to the server are not supported. SOCKS/HTTP proxies must
also be supplied in Xray outbound format.

## Installation

1. Download `statscc-helper-0.1.1-windows-x64.zip` from
   [Releases](https://github.com/Nerawlox/statscc-helper/releases) and extract it.
2. Choose a time when a brief network interruption is acceptable: installing
   Windows Packet Filter may change network adapter bindings.
3. Run `Install.cmd` and approve UAC **using your own Windows account**.
4. Import a Throne profile or an Xray outbound/config JSON file. For portable
   Throne, select its `throne.db` file. Choose the connection from the list.
5. If stats.cc is not installed in the default location, select its `stats.cc.exe`.
6. Wait for setup to finish. It creates the desktop shortcuts `stats.cc helper`
   and `Stop stats.cc helper`.

Xray and ProxiFyre are downloaded from their official release pages. Versions and
SHA-256 checksums are pinned in `dependencies.json`. ProxiFyre's installer is
unsigned, so Windows may display an unknown publisher. The helper verifies the
checksum against the value published for the official release before running it.
ProxiFyre installs Windows Packet Filter and the Visual C++ runtime if needed.
Setup does not restart Windows automatically; if a restart is requested, do it
when convenient.

After installation, you can remove the extracted package: the shortcuts use
protected files in Program Files. Keep the ZIP if you want to import a new profile
later.

## Usage

- Start **stats.cc helper** with your general VPN off.
- The helper restarts stats.cc to replace its existing connections.
- Normal startup does not show UAC again: it uses the scheduled task created
  during installation. The task has no automatic triggers.
- To stop, use **Stop stats.cc helper** or fully exit the overlay through its menu.
  The window's close button may only hide stats.cc to the tray.
- Xray and ProxiFyre stop when the overlay exits. A Windows Job Object also
  terminates both child processes if the controller exits unexpectedly.
- You can continue using your main VPN normally. Restart the helper after
  switching between Wi-Fi and Ethernet.
- To update the server or credentials, stop the helper and run `Install.cmd` again.

Existing shortcuts are not overwritten. Setup stops if it finds a ProxiFyre
configuration that does not match the helper's saved configuration.

## Your data

The repository and release ZIP contain no real server credentials, user UUIDs,
Throne databases or user profiles. Each user imports their own connection.

The server parameters are stored in `profile.dpapi`, encrypted with Windows DPAPI
for the current Windows account. Xray receives its configuration through stdin;
the helper does not create a plaintext configuration file. It does not read your
stats.cc account credentials. Throne's SQLite database is opened read-only.

Importing creates a copy of the profile. Selecting another server in Throne does
not update that copy. Local profiles, databases, logs, download caches and user
settings are excluded from Git and from the package's explicit build file list.

## Files and troubleshooting

| Location | Purpose |
| --- | --- |
| `%ProgramFiles%\StatsCC Helper` | Xray, controller, encrypted profile and launch scripts |
| `%ProgramFiles%\ProxiFyre` | Router and its routing rule |
| `%ProgramData%\StatsCC Helper\status.json` | `Starting`, `Running`, `Stopped` or an error category |
| `%ProgramFiles%\ProxiFyre\logs` | Router diagnostic logs |
| Scheduled task `StatsCC Independent Helper` | Manual controller startup |

`Running` means the helper processes have started. It does not by itself confirm
account sign-in or working match statistics. After setup, check the actual overlay
with your general VPN off. Local logs may include paths and addresses; remove
personal details before sharing them in an issue.

Common errors:

- `ExistingProxiFyreConfiguration`: another ProxiFyre configuration is present.
- `StopHelperFirst` / `RouterAlreadyRunning`: stop the running helper or ProxiFyre.
- `NoCompatibleProfiles`: no compatible Xray profile was found; try JSON import.
- `ChainedOutboundsUnsupported`: the profile depends on another proxy; use a
  standalone outbound.
- `CoreConfigurationRejected`: Xray rejected the configuration; check the export.
- `PortsBusy`: local ports 21980/21981 are already in use.
- `UpstreamUnavailable`: the stats.cc API check through the saved server failed.

## Uninstallation

Run `Uninstall.cmd`. It stops the helper and removes its task, profile and files.
It also removes the standard shortcuts if their destinations are unchanged.
Remove renamed or modified shortcuts yourself.

ProxiFyre and Windows Packet Filter remain installed because other applications
may use them. If they are no longer needed, remove them through Windows Installed
Apps at a time when a brief network interruption is acceptable.

## Building and testing

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Test.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Build.ps1
```

The ZIP is written to `dist`. The build uses an explicit list of source files;
dependencies are downloaded on the user's computer during installation. GitHub
Actions runs Windows checks and builds the package. A `v*` tag publishes an
experimental prerelease.

Local validation covered the real overlay's routing and interface download,
startup/shutdown, Xray's independent physical connection and normal Throne proxy
operation. Automated checks cover parsing, import validation, DPAPI, routing
scope, preservation of changed router settings, read-only SQLite import and
child-process cleanup. They do not perform a full generic installation.

This is a small personal project. Report problems through
[Issues](https://github.com/Nerawlox/statscc-helper/issues), including the Windows
version, import method and error category from `status.json`. Do not attach
connection profiles, Throne databases or account credentials. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

The helper code is MIT-licensed. Dependencies have their own licenses; source and
license links are listed in [THIRD-PARTY.md](THIRD-PARTY.md). This project is not
affiliated with stats.cc or Ubisoft.
