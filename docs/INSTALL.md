# Installing from scratch (AMP only)

This guide starts from a machine with [AMP](https://cubecoders.com/AMP) installed and ends with a
running Global Agenda server. Everything happens in the AMP web panel, except two things AMP
can't do for you: forwarding ports on your router, and (on a VM) choosing the CPU type.

You can install one of two apps:

| App | Pick it if | Players log in to |
|---|---|---|
| **Global Agenda (Commonwealth)** | you want your own server: login, chat, matchmaking and maps | your server |
| **Global Agenda (Commonwealth Node)** | you want to host maps for an existing Commonwealth master server | the master; their maps run on your machine |

Steps 1 to 4 are the same for both. Then follow [5A](#5a-standalone-server) or
[5B](#5b-node-of-a-master).

## 1. Check what you need

| You need | Why | How to check |
|---|---|---|
| AMP 2.5 or newer on **Linux** (tested with 2.8) | The apps are Linux-only. | AMP on Windows won't list the apps at all. |
| Containers turned on in AMP | The server runs in AMP's `cubecoders/ampbase:wine-10-stable` container, which has Wine. | **Configuration → Instance Deployment → Deployment Defaults → Create in Containers** is on. If AMP can't create containers, Docker isn't installed on the machine; see CubeCoders' AMP documentation. |
| A CPU with **AVX2** (Intel Haswell / 4th gen or newer, any AMD Ryzen or EPYC) | The released `control-server` is built for x86-64-v3 and won't start on older CPUs. | Nothing to check up front: if the CPU is too old, the console says `CPU ISA level is lower than required`. On a VM, set the CPU type to `x86-64-v3` or `host` (Proxmox's default `x86-64-v2-AES` is too old) and fully stop and start the VM. |
| A **Steam account that owns Global Agenda** (app 17020) | AMP downloads the game files with it. The game is free but no longer listed, so it must already be in the account's library. | It shows in your Steam library. |
| About **15 GB of disk** and **0.5 GB of RAM per running map** | The game is about 11.5 GB; each match runs its own copy of the game server. | AMP's host status. |
| Access to your **router's port forwarding** | Players' games connect to your machine from the internet. | – |
| **Node only:** a node ID, a node key and the master's address | The master only accepts nodes it knows. | Ask the operator of the master you want to join. The key is 64 hex characters; keep it private. |

## 2. Add the templates to AMP

1. In the AMP controller, open **Configuration → Instance Deployment**.
2. Under **Configuration Repositories**, add:

   ```
   15sharpie/amp-commonwealth-ga:main
   ```

   Keep the entries that are already there. AMP warns that third-party repositories are at your
   own risk; this one only contains the two app templates and their start-up scripts.
3. Save, then click **Fetch Latest** so AMP reads the new repository.

Tested with **Use Host Networking for New Containers** (same page, under Networking) turned on.

## 3. Create the instance

1. Click **Create Instance**.
2. Pick **Global Agenda (Commonwealth)** or **Global Agenda (Commonwealth Node)**.
3. Give it a name, leave *Start on boot* on, and create it.
4. **Don't start it yet**: there's nothing to run until the first update.

The first instance on a machine can take a few minutes to appear, while AMP downloads the
container image.

## 4. Run the first update

1. Open the instance and click **Update**.
2. AMP asks for your **Steam username and password**, then your **Steam Guard code**. Type them into
   AMP yourself. AMP keeps the login for later updates.
3. Wait. The update downloads the game (about 11.5 GB), the latest `control-server` and server hook
   from the Commonwealth project's releases, and the baseline database. Then it sets up Wine and
   installs the game's prerequisites, which takes a few more minutes.
4. Check it finished properly: in the instance's **File Manager**, open `amp-wine-setup.log`. Its
   last lines should include `check: PhysXLoader.dll present`.

The update also writes a starter `control-server.json`, once; later updates leave it alone.

## 5A. Standalone server

1. **Tell the server its address.** In the **File Manager**, open `control-server.json` and set:
   - `host`: the public IP address or DNS name players on the internet use to reach you.
   - `nat_networks` and `nat_ip` (optional): your LAN subnets and this machine's LAN IP, so players
     on your own network get the LAN address. See `hosting-behind-nat.md` in the
     [server project](https://github.com/commonwealthga/commonwealth-ga-server).

   Leave the port settings in the file alone. AMP's ports are copied into it every time the
   server starts.
2. **Forward the ports.** The instance's **Status** page lists them: Login and Chat (TCP) and
   Match Ports (UDP, 19 ports). Forward all of them from your router to this machine. The defaults
   are TCP 9000, TCP 9001 and UDP 9002-9020; AMP picks others if another instance already uses
   those.
3. **Start it.** AMP shows the server **Ready** when the console shows
   `[main] Binding TCP listener on port …`.
4. **Connect.** Players need the Commonwealth game client set up to use your server's address;
   see the [server project](https://github.com/commonwealthga/commonwealth-ga-server) for the
   client side.

## 5B. Node of a master

1. **Fill in the node settings.** Open the instance's **Configuration → Global Agenda → Node**:

   | Setting | Value |
   |---|---|
   | Node ID | the node ID from the master's operator |
   | Node key | the 64-character key (a password field, so it stays hidden) |
   | Master address | the master's node address, `host:port` (usually port 9020) |
   | Node update mode | **Apply (recommended)** |

   The server refuses to start until these are valid. If a start fails, the console names the
   setting that's wrong.
2. **Forward the match ports.** The **Status** page lists **Match Ports** (UDP, 19 ports, 9002-9020
   by default). Forward them from your router to this machine. A node needs no TCP ports
   forwarded: it connects out to the master.
3. **Start it.** AMP shows it **Ready** when the console shows `[node] Node agent '<your id>' up`.
   Within a few seconds you should see `handshake accepted by master`, and **Master Link** on the
   Status page turns green.
4. **Test it.** Log in to the master with the game, pick your node's region and start a mission.
   On your node's Status page, **Match Ports** turns green and you appear in the user list.

More about what a node does, the Status page and day-to-day running: [NODE-SETUP.md](NODE-SETUP.md).

## 6. What "working" looks like

| On the Status page | Standalone | Node |
|---|---|---|
| App state | **Ready** | **Ready** |
| Login / Chat ports | green | (not shown) |
| Match Ports | red when no map runs, green while one does | same |
| Master Link | (not shown) | green while connected to the master |
| Users | players logged in to chat (not yet confirmed with a live login) | players in maps on this node |

Red Match Ports on an idle server are normal: each running map opens one of them.

## Keeping it running

- **Updates:** click **Update** in the panel to get the latest Commonwealth release. A node also
  updates itself: when the master moves to a new release, the node fetches it, waits until no map
  is running, and restarts on it.
- **Restarts end every running map**, including other players' matches on a node. Check the
  Status page (Match Ports, Users) before restarting.
- **Player names in Analytics:** AMP's Analytics page stores players anonymously unless
  **Configuration → Security and Privacy → Store user-specific data** is on. A node can't show
  players' countries, because it never sees their IP addresses.

Something not working? See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
