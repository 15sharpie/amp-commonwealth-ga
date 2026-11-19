# AMP template: Global Agenda (Commonwealth)

An [AMP](https://cubecoders.com/AMP) generic-module template that runs the open-source
[Commonwealth Global Agenda server](https://github.com/commonwealthga/commonwealth-ga-server).

The Commonwealth `control-server` (a Linux binary) handles login, chat and matchmaking. It launches
the real `GlobalAgenda.exe` under Wine + Xvfb with the project's `version.dll` hook loaded, once
per running map. So the instance needs the **Global Agenda game files**, downloaded from Steam with
an account that owns the game (app 17020).

## What an update does

1. Downloads Global Agenda (app 17020, Windows depot) with SteamCMD. **Needs a Steam login.** AMP
   asks for it the first time; type it into AMP yourself.
2. Downloads the latest `control-server` and `version.dll` from the project's GitHub releases.
   `version.dll` goes into `17020/Binaries/`.
3. Creates the Wine prefix (`.wine`) if it is missing.
4. Writes a starter `control-server.json` **only if none exists**. After that, updates leave it alone.

Runs in the `cubecoders/ampbase:wine-stable` container.

## Ports

| Port | Protocol | Use |
|---|---|---|
| 9000 | TCP | Login (`tcp_port`) |
| 9001 | TCP | Chat (`chat_port`) |
| 9002-9020 | UDP | One per running game instance (`udp_port_range`) |
| 9010 | TCP | Internal IPC between the control server and game processes (`ipc_port`). Don't forward it. |

If you change ports in `control-server.json`, change them in AMP's port settings too.

## After the first update, edit `control-server.json`

- `host`: the public IP that internet players reach.
- `nat_networks` / `nat_ip`: your LAN subnets and the server's LAN IP, so LAN players get the LAN
  address. See `hosting-behind-nat.md` in the server repo.

## Deploying

1. Add `15sharpie/amp-commonwealth-ga:main` to *Configuration Repositories* in the AMP
   controller's settings and refresh the app list.
2. Create the instance from AMP's UI like any other app, or through the API:

   ```powershell
   .\deploy-to-amp.ps1 -DryRun
   .\deploy-to-amp.ps1
   ```

   The script needs `..\amp-query.ps1` and a session saved by `..\amp-login.ps1`. AMP must
   already have this repo in its template store (step 1), because it reads the settings files
   from there.

## Status

The server project is early and experimental, with no official setup docs. Upstream runs it under
Proton-GE Wine. This template uses WineHQ stable from the AMP image, so expect some tuning.
