# Running a Commonwealth node on AMP

A **node** hosts game maps for a Commonwealth **master** server. Players log in and chat on the
master; when they start a mission, the master asks a node in their chosen region to run the map,
and the player's game connects straight to that node over UDP.

**To install a node, follow [INSTALL.md](INSTALL.md)** (steps 1 to 4, then 5B) with the
**Global Agenda (Commonwealth Node)** app. This page explains the node-specific parts in more
detail.

From the master's operator you need a **node ID** (your node's name, for example
`na-west-yourname`), a **node key** (64 hex characters, shared between your node and the master;
keep it private) and the **master's node address** (`host:9020`). A node needs only its UDP match
ports forwarded; it connects *out* to the master, so it needs no inbound TCP ports.

Tested 2026-11-19/20 with releases 0.1.60 and 0.1.61, AMP 2.8 and the
`cubecoders/ampbase:wine-10-stable` image, on an instance of the standalone app switched to node.
The Node app was tested in AMP with a stand-in server (settings page, refusing to start without
settings, Status page, Master Link); a full run with the game and a real node key is still to do.

## Node settings

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

## What the console shows at start

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

## What AMP's Status page shows

- **Match Ports 9002-9020:** green *Listening (n/19, need 1)* while at least one match runs, red
  *Not Listening (0/19)* when the node is idle. Idle is normal for a node.
- **Master Link** (TCP 9021 by default): green while the node is connected to its master, red
  when it isn't. AMP can only colour ports, so the `Start Master Link Indicator` start-up step
  (`amp-master-link.sh`) opens a listener on `127.0.0.1` on that port while `control-server` has an
  open connection to `master_addr`, and closes it when that connection drops. It checks every 5
  seconds and logs each change to `amp-master-link.log`. Don't forward it; nothing outside the
  machine uses it.

  The same script gets the node back onto the master after an outage. `control-server` (0.1.62
  and older) stops retrying after a connection attempt times out, which is what happens while
  the master's machine is offline, so the node would otherwise stay disconnected until someone
  restarted it. When `control-server` hasn't tried to reach the master for 2 minutes, no map is
  running and the master answers again, the script stops `control-server`. AMP starts it again a
  few seconds later, and it reconnects and takes the master's build. It does this at most once
  every 10 minutes, and stops after 3 restarts that don't get the node connected. Each step is in
  `amp-master-link.log`.
- **Primary Endpoint** is the node's first match port. There's no Connection Link: players log in
  through the master, not the node.

Made a node from the standalone **Global Agenda (Commonwealth)** app instead (its Server role
setting)? It works, but its Status page keeps the standalone Login and Chat ports (red on a node)
and has no Master Link light. AMP's panel can't change an instance's ports, so for this Status
page, create a new instance from the Node app.

## Testing with a player

Log in to the master, pick your node's region, and start a mission. On the node you should see:

```
[node] spawned instance=… map=… port=9002 pid=…
[node] [NodeAgent] instance=… connected on 127.0.0.1:…
[node] holding player user=… character=… for instance=…
[node] player joined instance=… user=… character=… name='…'
```

Match Ports turns green (1/19) and the player shows in AMP's user list.

To confirm the player's game reached the map, set `"enabled_channels": ["debug"]` in
`control-server.json` (File Manager) and restart. Each map then writes `logs/<instance>/debug.txt`, which has a
`notify accepted connection called` line for every client that connects. Turn it off again
afterwards, because it writes a lot.

## Running it day to day

- **A restart ends every map the node is hosting**, including other players' matches. Check the
  console for running instances first.
- **Updates:** the master pushes new hook DLLs live. When the master offers a new
  `control-server`, the node waits until no map is running, swaps it in and exits, and AMP
  restarts it a few seconds later. You don't need to do anything. AMP's own **Update** also pulls
  the latest GitHub release; the node takes the master's builds again on its next handshake.
  The node only hears about new builds while it's connected, which is why the Master Link script
  reconnects it after an outage (see above).
- **Players show in AMP's user list** while they're in a map on the node (0.1.61+, which logs
  `[node] player joined … name='…'` and `player left …`). Players who are only logged in to the
  master, in no map on this node, don't show: they aren't on this machine.
- **CPU and RAM in AMP** only cover the node agent, not the Wine processes running the maps.

Something not working? See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
