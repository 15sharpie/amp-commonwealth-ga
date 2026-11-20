# What's still needed for anyone to set up a node on their own

Today a node works, but setting one up means hand-editing `control-server.json`, getting a key from
the master's operator, and knowing several gotchas (see [docs/NODE-SETUP.md](docs/NODE-SETUP.md)).
This is what's left to make it self-service.

## In this template

- [x] **Node settings in AMP's Configuration page.** Done (template v8): Server role, Node ID,
  Node key (password field), Master address and Node update mode, written into
  `control-server.json` by the `amp-node-config.sh` start-up step with `jq`. Tested on a
  throwaway instance with each role and with a bad key.
- [x] **Starter config that knows about nodes.** Covered by the start-up step above: it turns the
  standalone starter config into a node config (and back) based on the settings.
- [ ] **CPU check with a clear message.** Have `amp-wine-setup.sh` check `/proc/cpuinfo` for
  `avx2` and log "this CPU can't run the control server (needs x86-64-v3)". The only error today is
  `CPU ISA level is lower than required`, after AMP has already failed twice.
- [ ] **Rename the repo without hyphens** (for example `15sharpie/AMPCommonwealthGA`). AMP's
  "refresh instance configuration" reads `15sharpie-amp-commonwealth-ga-main` as `--main` and
  fails, so existing instances don't pick up template fixes without manual work. After a rename,
  update the Configuration Repositories entry and `deploy-to-amp.ps1`'s `TemplateStore`.
- [ ] **Leave the hook DLL alone on nodes during AMP updates.** The "Server Hook DLL Download"
  stage puts the release `dinput8.dll` back on every update, which a node immediately replaces with
  the master's on its next handshake. Harmless, but it could be skipped when role is node.
- [ ] **Ship or drop the API helpers.** `deploy-to-amp.ps1` and `set-node-ports.ps1` need `amp-query.ps1` and
  `amp-login.ps1`, which aren't in this repo. Either add generic versions or document creating the
  instance from the panel only.
- [ ] **Daily restart that doesn't kick players.** A scheduled restart lets a standalone server
  pick up a changed public IP and new releases. On a node it should wait until no maps are running;
  AMP's scheduler can't see that, so it needs a small script or an upstream "drain" command.
- [ ] **Submit to CubeCoders/AMPTemplates** once the settings page exists, so people can pick it
  from AMP's built-in app list without adding a repo. Their review requires a settings manifest and
  a full test run.

## Upstream (commonwealthga/commonwealth-ga-server)

- [ ] **Node player logs:** log join/leave with names on nodes so panels can list players
  ([#93](https://github.com/commonwealthga/commonwealth-ga-server/issues/93), opened).
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

- [ ] **Control server self-update on a node.** With `update_mode: apply`, a new `control-server`
  from the master is swapped in and the agent exits so AMP restarts it. It should work, because
  AMP restarts apps that exit unexpectedly, but it hasn't happened yet.
- [ ] **Players from outside the LAN on a node.** Tested from inside the node's network (through
  the router's NAT loopback) and with other master players placed on the node, but not
  deliberately from a separate internet connection.
- [ ] **Template update applied to an existing instance through AMP's normal flow.** Changes so far
  were pushed to the test instance through the API, because of the repo-name bug above.
