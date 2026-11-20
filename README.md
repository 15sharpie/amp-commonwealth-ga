# AMP template: Global Agenda (Commonwealth)

An [AMP](https://cubecoders.com/AMP) generic-module template that runs the open-source
[Commonwealth Global Agenda server](https://github.com/commonwealthga/commonwealth-ga-server).

The Commonwealth `control-server` (a Linux binary) handles login, chat and matchmaking. It launches
the real `GlobalAgenda.exe` under Wine + Xvfb with the project's server hook loaded, once
per running map. So the instance needs the **Global Agenda game files**, downloaded from Steam with
an account that owns the game (app 17020).

It can run as a standalone server (the default) or as a **node** of a Commonwealth master; see
[docs/NODE-SETUP.md](docs/NODE-SETUP.md). Problems: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## Requirements

- **CPU with AVX2 (x86-64-v3).** The released `control-server` won't start without it
  (`CPU ISA level is lower than required`). On a VM, use CPU type `x86-64-v3` or `host`.
- AMP 2.5+ with Docker. The template runs in `cubecoders/ampbase:wine-10-stable`.
- A Steam account that owns Global Agenda (app 17020); about 12 GB of disk for the game.
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
5. Writes a starter `control-server.json` **only if none exists**. After that, updates leave it alone.

Runs in the `cubecoders/ampbase:wine-10-stable` container (WineHQ's official Wine 10 build).

## Ports

| Port | Protocol | Use |
|---|---|---|
| 9000 | TCP | Login (`tcp_port`) |
| 9001 | TCP | Chat (`chat_port`) |
| 9002-9020 | UDP | One per running game instance (`udp_port_range`) |
| 9010 | TCP | Internal IPC between the control server and game processes (`ipc_port`). Don't forward it. |
| 9021 | TCP | Nodes only: AMP's **Master Link** light, open on `127.0.0.1` while the node is connected to its master. Don't forward it. |

If you change ports in `control-server.json`, change them in AMP's port settings too.

## After the first update, edit `control-server.json`

- `host`: the public IP that internet players reach.
- `nat_networks` / `nat_ip`: your LAN subnets and the server's LAN IP, so LAN players get the LAN
  address. See `hosting-behind-nat.md` in the server repo.

## Running as a node of a Commonwealth master (0.1.60+)

A node doesn't handle logins or chat; the master does. It runs game instances the master asks
for. Set it up in AMP under **Configuration → Global Agenda → Node** (role, node ID, key, master
address, update mode); a start-up step writes those into `control-server.json`. Full walkthrough:
[docs/NODE-SETUP.md](docs/NODE-SETUP.md). To edit by hand instead:
[examples/node-settings.example.jsonc](examples/node-settings.example.jsonc).

- Use `"update_mode": "apply"`. The master places players only on nodes whose hook DLL matches
  its own. With `stage`, the node kept its own DLL and the master stopped sending it instances
  (players were kicked back to the login page). `apply` swaps the master's DLL in live, even when
  it's the `version.dll` build saved under our `dinput8.dll` name; that worked on Wine 10 here.
  It also self-updates the control server and then exits; AMP restarts it.
- A node restart ends every map it's hosting, including other players' on a shared master, so
  check the console for running instances before restarting.
- The master learns the node's public IP from the node's own connection, so no DNS setup is needed.
- Players still connect straight to the node over UDP 9002-9020, so keep those forwarded. TCP
  9000/9001 aren't used by a node; `set-node-ports.ps1` removes them from AMP's Status page and
  adds a **Master Link** light that's green while the node is connected to its master (see
  [docs/NODE-SETUP.md](docs/NODE-SETUP.md#5-tidy-amps-status-page-optional)).
- AMP marks a node Ready on its `Node agent '…' up` line. AMP won't list players on a node,
  because the join/leave patterns match chat lines and chat runs on the master.
- The node logs a warning that `dll_overrides` doesn't cover `dinput8.dll`. That's expected:
  `amp-wine-setup.sh` adds the `dinput8` override in the Wine prefix instead.

## Deploying

1. Add `15sharpie/amp-commonwealth-ga:main` to *Configuration Repositories* in the AMP
   controller's settings and refresh the app list.
2. Create the instance from AMP's UI like any other app, or through the API:

   ```powershell
   .\deploy-to-amp.ps1 -DryRun
   .\deploy-to-amp.ps1
   ```

   The script needs `..\amp-query.ps1` and a session saved by `..\amp-login.ps1`. It uses the
   same create call as the panel's wizard, so the app must already be in AMP's app list (step 1).
   AMP only indexes the repo because of `manifest.json` at its root, so keep that file.

## Status

Working as of 2026-11-19 with release 0.1.60, both standalone (login, character creation, home map,
travel) and as a node of the public master (placed by the master, clients connect). The server
project is early and changes daily, and upstream runs it under Proton-GE Wine rather than WineHQ,
so new releases may need tuning. What's still missing for fully self-service nodes:
[TODO.md](TODO.md).
