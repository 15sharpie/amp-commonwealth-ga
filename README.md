# AMP templates: Global Agenda (Commonwealth)

[AMP](https://cubecoders.com/AMP) generic-module templates that run the open-source
[Commonwealth Global Agenda server](https://github.com/commonwealthga/commonwealth-ga-server).
Everything is set up from the AMP panel; you don't need anything else on your computer.

**New here? Start with [docs/INSTALL.md](docs/INSTALL.md)**: it goes from "AMP is installed" to a
running server or node.

The Commonwealth `control-server` (a Linux binary) handles login, chat and matchmaking. It launches
the real `GlobalAgenda.exe` under Wine + Xvfb with the project's server hook loaded, once
per running map. So the instance needs the **Global Agenda game files**, downloaded from Steam with
an account that owns the game (app 17020).

The repo adds two apps to AMP's list:

| App | Use it to | Guide |
|---|---|---|
| **Global Agenda (Commonwealth)** | run your own standalone server: login, chat, matchmaking and maps | [Install](docs/INSTALL.md#5a-standalone-server) |
| **Global Agenda (Commonwealth Node)** | host maps for a Commonwealth master server as one of its nodes | [Install](docs/INSTALL.md#5b-node-of-a-master), then [docs/NODE-SETUP.md](docs/NODE-SETUP.md) |

Both download and run the same server; they differ in their settings page, start-up checks and
what AMP's Status page shows. Problems: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## Requirements

In short (details in [docs/INSTALL.md](docs/INSTALL.md#1-check-what-you-need)):

- **CPU with AVX2 (x86-64-v3).** The released `control-server` won't start without it
  (`CPU ISA level is lower than required`). On a VM, use CPU type `x86-64-v3` or `host`.
- AMP 2.5+ on Linux, with containers. The template runs in `cubecoders/ampbase:wine-10-stable`.
- A Steam account that owns Global Agenda (app 17020); about 15 GB of disk.
- About 0.5 GB of RAM per running map.

## What an update does

1. Downloads Global Agenda (app 17020, Windows depot) with SteamCMD. **Needs a Steam login.** AMP
   asks for it the first time; type it into AMP yourself.
2. Downloads the latest `control-server` and server hook `dinput8.dll` from the project's GitHub
   releases. The hook goes into `17020/Binaries/`, and any old `version.dll` there is removed.
   - Use `dinput8.dll`, not `version.dll`: `GlobalAgenda.exe` imports DINPUT8 at startup, but under
     WineHQ Wine nothing loads `version.dll`, so that hook never runs and the game crashes about 3
     seconds in (Wine's debugger then holds it, so the map sits at STARTING forever).
   - Both release DLLs are the server hook. The player client hook isn't released.
3. Downloads `dbbase/base.db` from the server repo. The control server builds a brand-new
   `server.db` from it (all game content, no players). It's ignored once `server.db` exists, so a
   database created before 0.1.59 keeps missing content tables (`map_game_info` and others); move
   that `server.db` aside to rebuild.
4. Sets up the Wine prefix (`.wine`) with `amp-wine-setup.sh`, logging to `amp-wine-setup.log`:
   - creates it with the Wine Mono/Gecko prompts off. Under Xvfb those prompts wait forever,
     so the prefix never gets its 32-bit half (`syswow64`) and `GlobalAgenda.exe` fails with
     `could not load kernel32.dll, status c0000135`. It rebuilds a prefix whose `syswow64` is empty.
   - installs the game's own prerequisites from `17020/PreReqs` once each, with Steam's switches:
     VC++ 2005 and NVIDIA PhysX (needed for `PhysXLoader.dll`). The .NET 3.5 and DirectX web
     installers don't install under Wine; they're tried once and then skipped.
   - adds a Wine DLL override so the game's own `dinput8.dll` loads instead of Wine's built-in one
     (`control-server` only sets `version=n,b` itself).
5. Writes a starter `control-server.json` **only if none exists**. After that, updates leave it
   alone; only the start-up steps change it (AMP's ports, and the node settings if you use them).

Runs in the `cubecoders/ampbase:wine-10-stable` container (WineHQ's official Wine 10 build).

## Ports

| Port | Protocol | Standalone | Node | Use |
|---|---|---|---|---|
| 9000 | TCP | forward | – | Login (`tcp_port`) |
| 9001 | TCP | forward | – | Chat (`chat_port`) |
| 9002-9020 | UDP | forward | forward | One per running game instance (`udp_port_range`) |
| 9010 | TCP | local | local | Internal IPC between the control server and game processes (`ipc_port`). Don't forward it. |
| 9021 | TCP | – | local | AMP's **Master Link** light, open on `127.0.0.1` while the node is connected to its master. Don't forward it. |

These are the defaults. AMP gives an instance other ports when another instance on the machine
already uses them; the Status page lists the ones an instance really has. Both apps copy AMP's
ports into `control-server.json` every time the server starts (`tcp_port`, `chat_port` and
`udp_port_range`; the Node app only the match ports), so AMP's ports always win: changes to those
keys in the file are overwritten. The internal IPC port isn't one of AMP's ports; see
[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) if you run two instances on one machine.

## Setting it up

Follow [docs/INSTALL.md](docs/INSTALL.md). In short: add `15sharpie/amp-commonwealth-ga:main` to
AMP's **Configuration Repositories**, create an instance of one of the two apps, run **Update**
(with your Steam login), then either set `host` in `control-server.json` (standalone) or fill in
the Node settings (node), forward the ports the Status page lists, and start it.

The standalone app's **Configuration → Global Agenda → Node** page can also turn an existing
instance into a node (Server role). That works, but its Status page keeps the standalone ports;
for a new node, use the Node app.

## Running as a node of a Commonwealth master (0.1.60+)

A node doesn't handle logins or chat; the master does. It runs game instances the master asks
for, and players' games connect straight to it over UDP. Use the **Global Agenda (Commonwealth
Node)** app and fill in **Configuration → Global Agenda → Node** (node ID, key, master address,
update mode). The server won't start until those are set. Full walkthrough:
[docs/NODE-SETUP.md](docs/NODE-SETUP.md).

- Keep the update mode on **Apply**. The master places players only on nodes whose hook DLL
  matches its own. With `stage`, the node kept its own DLL and the master stopped sending it
  instances (players were kicked back to the login page). `apply` swaps the master's DLL in live,
  even when it's the `version.dll` build saved under our `dinput8.dll` name; that worked on Wine 10
  here. It also self-updates the control server and then exits; AMP restarts it.
- If the master goes offline, the node reconnects by itself once it's back: the Master Link
  start-up script restarts `control-server` when it has stopped retrying and no map is running,
  so the node rejoins and picks up the master's build.
- A node restart ends every map it's hosting, including other players' on a shared master, so
  check the console for running instances before restarting.
- The master learns the node's public IP from the node's own connection, so no DNS setup is needed.
- AMP's Status page shows **Match Ports** (green while a match runs) and **Master Link** (green
  while the node is connected to its master). AMP's user list shows the players in maps on the
  node (0.1.61+).
- The node logs a warning that `dll_overrides` doesn't cover `dinput8.dll`. That's expected:
  `amp-wine-setup.sh` adds the `dinput8` override in the Wine prefix instead.

AMP only indexes this repo because of `manifest.json` at its root, so keep that file.

## Status

Working as of 2026-11-20 with release 0.1.61:

- **Standalone** (tested 2026-11-19 on 0.1.60): login, character creation, home map, travel.
- **Node** of the public master: placed by the master, clients connect and play, AMP lists the
  players and shows Match Ports and Master Link, and the node updates itself when the master moves
  to a new release. This ran on an instance of the standalone app switched to node. The Node app
  itself was tested in AMP with a stand-in server, not yet with the real game.

The server project is early and changes daily, and upstream runs it under Proton-GE Wine rather
than WineHQ, so new releases may need tuning. What's still open: [TODO.md](TODO.md).
