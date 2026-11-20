# What's still needed for anyone to set up a node on their own

A node can now be set up from the AMP panel alone with the Node app, but it still means getting a
key from the master's operator and knowing a few gotchas (see [docs/NODE-SETUP.md](docs/NODE-SETUP.md)).
This is what's left to make it fully self-service.

## In this template

- [x] **Node settings in AMP's Configuration page.** Done (template v8): Server role, Node ID,
  Node key (password field), Master address and Node update mode, written into
  `control-server.json` by the `amp-node-config.sh` start-up step with `jq`. Tested on a
  throwaway instance with each role and with a bad key.
- [x] **Starter config that knows about nodes.** Covered by the start-up step above: it turns the
  standalone starter config into a node config (and back) based on the settings.
- [x] **A separate Node app.** Done (2026-11-20): **Global Agenda (Commonwealth Node)**
  (`commonwealthganode.kvp`) shares the downloads with the standalone app, has only the node
  settings, refuses to start until they're valid, and shows Match Ports and Master Link on the
  Status page.
- [x] **Panel-only setup.** Done (2026-11-20): the repo needs nothing but the AMP panel. The API
  scripts that used to be here (`deploy-to-amp.ps1`, `set-node-ports.ps1`) needed helpers that
  were never in the repo, so they were removed.
- [ ] **CPU check with a clear message.** Have `amp-wine-setup.sh` check `/proc/cpuinfo` for
  `avx2` and log "this CPU can't run the control server (needs x86-64-v3)". The only error today is
  `CPU ISA level is lower than required`, after AMP has already failed twice.
- [ ] **Rename the repo without hyphens** (for example `15sharpie/AMPCommonwealthGA`). AMP's
  "refresh instance configuration" reads `15sharpie-amp-commonwealth-ga-main` as `--main` and
  fails, so existing instances don't pick up template fixes (new start-up steps, ports) without
  manual work. After a rename, update the Configuration Repositories entry in the docs.
- [ ] **Leave the hook DLL alone on nodes during AMP updates.** The "Server Hook DLL Download"
  stage puts the release `dinput8.dll` back on every update, which a node immediately replaces with
  the master's on its next handshake. Harmless, but it could be skipped when role is node.
- [x] **Standalone app: follow AMP's ports.** Done (2026-11-20): an `Apply Port Settings`
  start-up step (`amp-port-config.sh`) writes AMP's login, chat and match ports into
  `control-server.json` on every start. Tested on a throwaway instance that AMP gave
  9002/9003/9021-9039.
- [ ] **IPC port for a second instance on one machine.** Both apps default to `ipc_port` 9010,
  which isn't one of AMP's ports, so AMP can't move it. Today a second instance needs a hand edit;
  giving it an AMP port would let AMP pick a free one, at the cost of another row on the Status page.
- [ ] **Daily restart that doesn't kick players.** A scheduled restart lets a standalone server
  pick up a changed public IP and new releases. On a node it should wait until no maps are running;
  AMP's scheduler can't see that, so it needs a small script or an upstream "drain" command.
- [ ] **Submit to CubeCoders/AMPTemplates** once the settings page exists, so people can pick it
  from AMP's built-in app list without adding a repo. Their review requires a settings manifest and
  a full test run.

## Upstream (commonwealthga/commonwealth-ga-server)

- [x] **Node player logs.** Done: [#94](https://github.com/commonwealthga/commonwealth-ga-server/pull/94)
  (fixing [#93](https://github.com/commonwealthga/commonwealth-ga-server/issues/93)) shipped in
  0.1.61. Nodes log `player joined/left … name='…'`, and both apps' AMP user-list patterns match it.
- [ ] **Make `dll_overrides` configurable again.** The parser line is commented out, so the node
  warns that `version=n,b` doesn't cover `dinput8.dll` on every start, and the template has to set
  the override in the Wine registry instead.
- [ ] **Serve the hook in the node's own flavour.** The node reports which DLL it uses
  (`dinput8.dll` or `version.dll`), but the master sends its single `version.dll` build to every
  node, and the node saves it under its own name. It works today, but a master-side choice would
  avoid surprises.
- [ ] **A documented way to get a node id and key.** Today you ask the master's operator. A short
  page (where to ask, what to send, which regions exist) would let others onboard without help.
- [ ] **Release builds for older CPUs** (x86-64 baseline), or a note in the README, so a VM
  without AVX2 isn't a dead end.

## Not verified yet

- [ ] **The Node app with the real game.** Tested 2026-11-20 on a throwaway instance with a
  stand-in `control-server` (no game download): AMP lists the app; it gets the node settings page
  and only Match Ports + Master Link on Status; with empty settings it fails to start and the
  console says which settings to fill in; with settings it writes the node config, follows AMP's
  ports and goes Ready on the node line. Still to do: a full first update and run with a real
  node key.

- [x] **Control server self-update on a node.** Seen 2026-11-20 when the master moved to 0.1.61:
  the node fetched the new `control-server`, waited until no map was running, swapped it in and
  exited, and AMP restarted it on the new build (start-up steps included) within 3 seconds.
- [ ] **Players in AMP's user list on a node.** The 0.1.61 lines and the patterns were checked
  against each other, but no player has joined a node with the new patterns yet.
- [ ] **Players from outside the LAN on a node.** Tested from inside the node's network (through
  the router's NAT loopback) and with other master players placed on the node, but not
  deliberately from a separate internet connection.
- [x] **Master Link turning red when the link drops.** Tested 2026-11-20 on a throwaway instance
  with a stand-in master: green while connected, red within 5 seconds of the connection closing,
  and the listener closed when the server stopped. Not yet seen during a real master outage.
- [ ] **Template update applied to an existing instance through AMP's normal flow.** Changes so far
  were pushed to the test instance through the API, because of the repo-name bug above.
