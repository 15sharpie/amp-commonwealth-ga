# Running a Commonwealth node on AMP

A **node** hosts game maps for a Commonwealth **master** server. Players log in and chat on the
master; when they start a mission, the master asks a node in their chosen region to run the map,
and the player's game connects straight to that node over UDP.

This walkthrough takes a fresh AMP install to a working node. The node setup was tested on
2026-11-19 with release 0.1.60, AMP 2.8 and the `cubecoders/ampbase:wine-10-stable` image, on an
instance of the standalone app switched to node. The separate Node app (added 2026-11-20) was
tested in AMP with a stand-in server (settings page, refusing to start without settings, Status
page, Master Link); a full run with the game and a real node key is still to do.

## Before you start

You need:

- **A CPU with AVX2** (Intel Haswell / 4th gen or newer, any AMD Ryzen or EPYC). The released
  `control-server` is built for the **x86-64-v3** instruction set. On anything older it won't start
  (`CPU ISA level is lower than required` in the console). On a VM, set the CPU type to
  `x86-64-v3` or `host`. Proxmox's default `x86-64-v2-AES` is too old, and the VM needs a full
  stop and start after changing it.
- **A Steam account that owns Global Agenda** (app 17020). It's free, but unlisted, so it has to
  already be in your library. AMP downloads about 11.5 GB with it.
- **A node id and key from the master's operator.** The id is your node's name (for example
  `na-west-yourname`); the key is 64 hex characters, shared between your node and the master. Keep
  the key private.
- **The node's UDP match ports forwarded** from your router to the AMP machine: 9002–9020, unless
  another instance on that machine already uses them, in which case AMP gives the node other ones.
  The node's Status page lists the ports it actually uses (Match Ports), and the node follows them.
  Nodes don't need TCP 9000/9001. The node connects *out* to the master on TCP 9020, so no inbound
  rule is needed for that.
- **Memory:** about 0.5 GB per running map, plus a little for the agent.

Everything below happens in the AMP panel.

## 1. Add the templates to AMP

1. In the AMP controller (ADS): **Configuration → Instance Deployment → Configuration
   Repositories**, add `15sharpie/amp-commonwealth-ga:main`, save, then **Fetch latest**.
2. **Create Instance** → choose **Global Agenda (Commonwealth Node)**. Leave *Start on boot* on.
   Don't start the app yet.

## 2. First update (needs your Steam login)

Open the instance and click **Update**. When AMP asks, type your Steam username, password and
Steam Guard code.

The update downloads the game, the latest release's `control-server` and `dinput8.dll`, and the
baseline database. It also builds the Wine prefix and installs VC++ 2005 and PhysX, then writes a
starter `control-server.json`. Check `amp-wine-setup.log` in the file manager: it should end with
`check: PhysXLoader.dll present`.

## 3. Fill in the node settings

Open the instance's **Configuration → Global Agenda → Node** settings and set:

| Setting | Value |
|---|---|
| Node ID | your node id from the operator |
| Node key | your 64-hex key (a password field, so it stays hidden) |
| Master address | `<master ip>:9020` |
| Node update mode | **Apply (recommended)** |

They're written into `control-server.json` every time the server starts, by a start-up step
(`amp-node-config.sh`). It sets `role` to `node`, the `node` block, `apply_content`, `db_path` to
`node.db`, `content_dir`, and `udp_port_range` to the Match Ports in AMP's port settings, and
keeps everything else in the file. It saves the previous file as `control-server.json.bak-amp`.

**The server won't start until these are right.** If the ID is empty, the key isn't 64 hex
characters or the address isn't host:port, the start-up step fails, so AMP never runs the server
as a standalone one by mistake. `amp-node-config.log` in the File Manager says which setting is
wrong (the key is never logged).

Keep **Apply**. The master only sends players to nodes whose hook DLL matches its own, and `apply`
lets the node take the master's DLL. With `stage` or `off`, players get kicked back to the login
page when they start a mission.

The settings page owns the node block. Other parts of `control-server.json` (for example
`enabled_channels`) can still be edited in the File Manager; see
[`../examples/node-settings.example.jsonc`](../examples/node-settings.example.jsonc) for what a
node config looks like.

## 4. Start it and check the console

Start the app. AMP shows it **Ready** when this line appears:

```
[node] Node agent '<your id>' up: master=<ip>:9020 ipc=127.0.0.1:9010 db=node.db
```

Then, within a second or two:

```
[node] [NodeLink] connected to master <ip>:9020 as '<your id>'
[node] handshake accepted by master (node_id=…)
[node] content snapshot … ready (… KB, …)
[node] proxy DLL updated in place: '…/dinput8.dll' now … (was …)
```

These two lines are expected and harmless:

- `WARNING: dinput8.dll is installed but dll_overrides is 'version=n,b'`. The template adds the
  `dinput8` override in the Wine prefix instead, because `dll_overrides` can't be set from the
  config file yet.
- `dll differs (have …, master offers …) -- fetching`, on every start. The master's DLL replaces
  the release one each time.

## 5. What AMP's Status page shows

- **Match Ports 9002-9020:** green *Listening (n/19, need 1)* while at least one match runs, red
  *Not Listening (0/19)* when the node is idle. Idle is normal for a node.
- **Master Link** (TCP 9021 by default): green while the node is connected to its master, red
  when it isn't. AMP can only colour ports, so the `Start Master Link Indicator` start-up step
  (`amp-master-link.sh`) opens a listener on `127.0.0.1` on that port while `control-server` has an
  open connection to `master_addr`, and closes it when that connection drops. It checks every 5
  seconds and logs each change to `amp-master-link.log`. Don't forward it; nothing outside the
  machine uses it.
- **Primary Endpoint** is the node's first match port. There's no Connection Link: players log in
  through the master, not the node.

Made a node from the standalone **Global Agenda (Commonwealth)** app instead (its Server role
setting)? It works, but its Status page keeps the standalone Login and Chat ports (red on a node)
and has no Master Link light. AMP's panel can't change an instance's ports, so for this Status
page, create a new instance from the Node app.

## 6. Test with a player

Log in to the master, pick your node's region, and start a mission. On the node you should see:

```
[node] spawned instance=… map=… port=9002 pid=…
[node] [NodeAgent] instance=… connected on 127.0.0.1:…
[node] holding player user=… character=… for instance=…
```

To confirm the player's game reached the map, set `"enabled_channels": ["debug"]` in
`control-server.json` (File Manager) and restart. Each map then writes `logs/<instance>/debug.txt`, which has a
`notify accepted connection called` line for every client that connects. Turn it off again
afterwards, because it writes a lot.

## Running it day to day

- **A restart ends every map the node is hosting**, including other players' matches. Check the
  console for running instances first.
- **Updates:** the master pushes new hook DLLs live. When the master offers a new
  `control-server`, the node swaps it in and exits, and AMP restarts it. AMP's own **Update** also
  pulls the latest GitHub release; the node takes the master's DLL again on its next handshake.
- **Players aren't shown in AMP's user list** on a node. The node doesn't log player names or
  leaves yet (upstream request:
  [commonwealthga/commonwealth-ga-server#93](https://github.com/commonwealthga/commonwealth-ga-server/issues/93)).
- **CPU and RAM in AMP** only cover the node agent, not the Wine processes running the maps.

Something not working? See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
