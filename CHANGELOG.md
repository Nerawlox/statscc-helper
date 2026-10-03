# 0.1.0

- Standalone per-process routing for the stats.cc overlay.
- Local import from Throne or Xray outbound/config JSON; no bundled credentials.
- Windows DPAPI storage and configuration through stdin.
- Pinned official Xray and ProxiFyre downloads with SHA-256 verification.
- Manual scheduled-task launcher, protected runtime files and automatic child cleanup.
- Windows tests, source-only ZIP and uninstall script.

Experimental Windows x64 release. The underlying VLESS/REALITY/XHTTP method
was confirmed working with the general VPN switched off; broader configurations
need user testing.
