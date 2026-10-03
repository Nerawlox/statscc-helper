# Third-party components

The MIT license applies to this repository's helper scripts and C# utilities.
Third-party applications retain their own licenses. They are not bundled in
the source repository or the release ZIP; Setup downloads their original,
unmodified release packages directly from the publishers.

| Component | Version | License and source |
| --- | --- | --- |
| Xray-core | 26.3.27 | [MPL-2.0](https://github.com/XTLS/Xray-core/blob/v26.3.27/LICENSE), [source](https://github.com/XTLS/Xray-core/tree/v26.3.27) |
| ProxiFyre | 2.6.1 | [AGPL-3.0](https://github.com/wiresock/proxifyre/blob/v2.6.1/LICENSE), [source](https://github.com/wiresock/proxifyre/tree/v2.6.1) |
| Windows Packet Filter | dependency of ProxiFyre | [Upstream project and license](https://github.com/wiresock/ndisapi); obtained by ProxiFyre's official installer |
| Microsoft Visual C++ runtime | dependency of ProxiFyre | Microsoft license; obtained by ProxiFyre's official installer if needed |
| winsqlite3.dll | provided by Windows | Microsoft-provided SQLite library; no DLL is copied into this package |

Setup preserves Xray's LICENSE next to its installed executable. ProxiFyre's
official installer handles its own prerequisites. See the respective source
projects for their full notices and component licenses.

This project is independent of stats.cc, Ubisoft, Throne, Xray and ProxiFyre.
