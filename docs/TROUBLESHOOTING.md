# Troubleshooting

Every problem below came up while getting this template working on AMP 2.8 with Wine. Most of them
show up in the instance console, in `amp-wine-setup.log`, or as a map stuck at `STARTING`.

| What you see | Cause | Fix |
|---|---|---|
| `control-server: CPU ISA level is lower than required`; AMP says the app failed to start twice | The release build needs x86-64-v3 (AVX2). The VM's CPU type hides it. | Use a CPU type of `x86-64-v3` or `host`, then fully stop and start the VM. |
| `wine: could not load kernel32.dll, status c0000135`; `drive_c/windows/syswow64` is empty | The Wine prefix never got its 32-bit half. `wineboot` opened the Wine Mono install prompt, which waits forever under Xvfb. | Fixed in `amp-wine-setup.sh` (it creates the prefix with `WINEDLLOVERRIDES="mscoree,mshtml="` and rebuilds a prefix with an empty `syswow64`). Run **Update**. |
| Prefix setup hangs; `Failed to open RpcSs service` in the log | Same Mono prompt. The RpcSs errors are a side effect. | As above. |
| Map stuck at `STARTING` and the player sits on a loading screen; no files in `logs/<instance>/` | The game crashed about 3 seconds in (`Unhandled page fault … in GlobalAgenda.exe`) because the server hook never loaded, and `winedbg` then held the dead process. Under WineHQ Wine nothing loads `version.dll`. | Use the `dinput8.dll` hook. The template installs it, removes `version.dll`, and adds a `dinput8` override in the prefix. |
| `PhysXLoader.dll` missing; game exits early | The game's prerequisites aren't installed in the prefix. | `amp-wine-setup.sh` runs `PreReqs/vcredist.exe /Q` and `PreReqs/physx.exe /passive /norestart`. Check `amp-wine-setup.log` for `check: PhysXLoader.dll present`. |
| `.NET 3.5` and `DirectX` installers time out or crash in `amp-wine-setup.log` | They don't install under Wine. | Expected. The server doesn't need them; they're tried once and then skipped. |
| `no such table: map_game_info`; `table ga_queues has no column named team_policy`; matchmaking finds no queues | The database was created before 0.1.59 without the baseline content. | Stop the server, move `server.db`, `server.db-wal` and `server.db-shm` aside, make sure `dbbase/base.db` exists, and start it. A fresh database is built from the baseline. |
| Node: players get kicked back to the login page when they start a mission | The node's hook DLL doesn't match the master's, so the master won't place players on it. | Set `"update_mode": "apply"` in the `node` block and restart. |
| Node: the master spawns a map on your node, but the player never arrives and it stops after about 2 minutes with `reason=last player left` | The player's game couldn't reach the node over UDP. | Forward UDP 9002–9020 to the AMP machine on the **same internet connection the node uses to reach the master** (the master advertises the address it sees). With two internet connections, check which one carries outbound traffic. |
| Players don't appear in AMP's user list | On a master, the join/leave patterns need the chat lines (template v6+). On a node they can't work yet. | Master: update the template. Node: waiting on upstream issue [#93](https://github.com/commonwealthga/commonwealth-ga-server/issues/93). |
| AMP panel: "Unmanaged instances cannot be accessed from within ADS" | The instance was created with `ADSModule/CreateInstance` and inline settings. | Delete it and create it from the panel's wizard, or with `deploy-to-amp.ps1`, which uses `CreateInstanceFromSpec`. |
| AMP never lists the app after adding the repo | The repo has no `manifest.json`, or it's private. | Keep `manifest.json` at the root (`"repotype": "AppTemplates"`). AMP can only read public repos. |
| An update started through the AMP API reports success but does nothing | AMP needs the panel for the Steam login step. | Click **Update** in the panel. |

## Getting more detail

- **Game process output:** the control server sets `WINEDEBUG=-all` for maps, so Wine errors
  barely show. To trace a launch, run the same command line the control server uses (it's in the
  source, `InstanceSpawner.cpp`) with `WINEDEBUG=err+all,+loaddll` from an AMP pre-start step, and
  time-limit it.
- **Per-map logs:** set `"enabled_channels": ["debug"]` in `control-server.json` and restart. Each
  map then writes `logs/<instance>/debug.txt`.
- **Console history:** AMP's console only keeps the last 40 lines, and `[dbperf]` lines take up
  most of them. Read it soon after the event, or poll it.
