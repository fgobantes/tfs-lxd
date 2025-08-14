# MindFulTeraFlowSDN LXD Bootstrap

## Overview
This automation:
1. Ensures LXD is installed and initialized.
2. Creates (or reuses) an Ubuntu 24.04 VM.
3. Runs Part 1 (MicroK8s install + reboot).
4. Runs Part 2 (enable addons, clone repos, deploys TeraFlowSDN).
5. Runs Julia bootstrap:
   - Instantiates MINDFulTeraFlowSDN.jl
   - Checks for admin context + target topology
   - Creates graph/devices
   - Verifies deployment

Deployment and graph creation are time‑consuming (expect 30+ minutes on first run).

## Why LXD (and not Docker)
LXD provides a lightweight VM with a full systemd environment, predictable networking, proper cgroups, kernel feature access, and stable loop/backing storage handling. Running MicroK8s or rather snapd inside plain Docker or even LXD containers causes issues (systemd supervision, cgroup delegation, mounting snaps, DNS/iptables quirks, storage provisioning). Using an LXD VM avoids these constraints while remaining reproducible and disposable.

## Prerequisites (Host machine)
- Linux host with snapd
- User in `sudo` group
- Network access (Git + external downloads)

## Run
```bash
cd tfs-lxd
bash tfs-lxd.sh          # Optional: DEVSPACE_MODE=yes
```

Safe to re-run: it detects VM, MicroK8s state, deployment, and Julia setup idempotently.

## What Gets Created
- LXD VM: `tfs-vm`
- User inside VM: `tfsuser`
- MicroK8s 1.29 with addons (dns, storage, ingress, registry, metrics, prometheus, linkerd)
- Repos: `controller`, `MINDFulTeraFlowSDN.jl`
- TeraFlow services in namespace `tfs`
- Stable admin context + topology
- Device graph loaded via Julia

## Access
After completion:
- Direct access: http://{VM_IP}:80/webui
- VSCode Server: Forward port {VM_IP}:80 in VSCode, check the auto forward and the access will be at http://localhost:{forwarded-port}/webui (likely port 80)
- Shell access if needed: `lxc exec tfs-vm -- bash`

## Idempotency Logic
- Part 1 skipped if MicroK8s already installed.
- Part 2 skips steps if TFS deployment already satisfied.
- Julia setup checks context + topology via API; if both exist, skips recreation.
- Graph creation runs each time (adjust if needed).

## Troubleshooting
- If you only want to do Julia scripts then Re-run Julia only: 
  ```bash
  lxc exec tfs-vm -- sudo -u tfsuser bash -c 'cd ~/MINDFulTeraFlowSDN.jl && ./bootstrap-julia.sh'
  ```

## Clean Up
```bash
lxc stop tfs-vm --force
lxc delete tfs-vm
```

## Notes
- Uses API URL `http://127.0.0.1:80/tfs-api` internally for the TeralowSDN controller instance.
- Extend logic in `bootstrap-julia.sh` if adding more