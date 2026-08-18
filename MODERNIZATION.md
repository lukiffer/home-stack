# Home Stack modernization report

**Date:** 18 August 2026
**Repository:** `lukiffer/home-stack`
**Branch reviewed:** `main` @ `ac92a60` (31 March 2024)
**Age:** ~2 years 5 months since last commit

This is an inventory of what the repo actually does today, what has gone stale, and a prioritized plan to bring it up to date. It is based on the current tree plus upstream versions as of August 2026.

---

## 1. What this repo is

A single-node home-automation stack:

1. `bootstrap.sh` provisions a minimal Ubuntu host: system packages, SOPS, Terraform, k0s (`controller --single`), then clones this repo and an optional config repo.
2. Terraform talks to that k0s cluster and deploys six Kubernetes Deployments + NodePort Services via a shared module.

There is no CI, no tests, no LICENSE, no `.github/`, and almost no documentation beyond a curl-pipe bootstrap snippet in `README.md`. Application config and secrets live in a **separate, untracked config repo** expected at `/opt/home-stack/config`.

### File inventory

| Path | Role |
| --- | --- |
| `bootstrap.sh` | Host install + first `terraform apply` |
| `README.md` | Bootstrap instructions only |
| `.gitignore` | `.terraform`, tfstate, `.DS_Store` |
| `infra/terraform/main.tf` | Local backend, paths, ports, secrets load, namespace |
| `infra/terraform/providers.tf` | Kubernetes provider using `/opt/home-stack/k0s.config` |
| `infra/terraform/.terraform.lock.hcl` | Pins `hashicorp/kubernetes` **2.23.0** |
| `infra/terraform/modules/kubernetes-deployment/` | Generic Deployment + NodePort Service |
| `infra/terraform/{home-assistant,mariadb,node-red,zwave-js,grafana,nginx}.tf` | Workloads |

34 commits, all from March 2024, from an initial commit through “Default to `Always` for container image pull policy.”

---

## 2. Current workload map

| App | Image in repo | Ports | Persistence | Privileged | Notes |
| --- | --- | --- | --- | --- | --- |
| Home Assistant | `homeassistant/home-assistant:stable` | 8123 → NodePort 30000 | hostPath config dir | yes | USB `/dev/ttyUSB1`, `/dev/ttyUSB2` |
| MariaDB | `mariadb:latest` | 3306 → 30100 | hostPath `/var/lib/mysql` | no | `MYSQL_*` env vars |
| Node-RED | `lukiffer/node-red-home-assistant:latest` | 1880 → 30200 | hostPath `/data/` | no | Custom image, not official |
| Z-Wave JS UI | `zwavejs/zwave-js-ui:latest` | 8091 → 30210, 3000 → 30211 | hostPath store | yes | USB `/dev/ttyUSB0` |
| Grafana | `grafana/grafana:latest` | 3000 → 30300 | hostPath `/var/lib/grafana` | no | Admin user from secrets; no admin password env |
| nginx | `nginx:stable-alpine` | 80 → 32767 | hostPath file → `/etc/nginx/nginx.conf` | no | Reverse proxy, highest NodePort |

All six use the same module: Recreate strategy, `imagePullPolicy: Always`, hostPath volumes, no probes, no resource requests/limits, no securityContext beyond optional `privileged: true`.

---

## 3. Version drift (as of August 2026)

| Component | What the repo uses | Current upstream | Gap |
| --- | --- | --- | --- |
| Last commit | 31 Mar 2024 | — | ~29 months |
| Terraform CLI | `>= 1.5` (unpinned apt `terraform`) | **1.15.8** (1.14 still in support) | Several major 1.x lines; 1.5 is long EOL |
| Kubernetes provider | `~> 2.23.0` (Sept 2023 era) | **3.2.1** (Jun 2026); 2.x last was 2.38.0 | Two majors; unversioned resources deprecated in 3.0 |
| k0s | Unpinned `get.k0s.sh` | **v1.36.3+k0s.2** (K8s 1.36) | Likely installed ~K8s 1.29 in Mar 2024 |
| SOPS | Latest `.deb` at install time | **v3.13.3** | Install method still works; unused after install |
| Home Assistant | Docker Hub `:stable` | **2026.8.2**; official image is `ghcr.io/home-assistant/home-assistant` | ~29 monthly releases of breaking changes |
| Grafana | `:latest` | **13.2.0** | 10.x → 13.x if last pulled in 2024 |
| MariaDB | `:latest` | **12.3.x**; LTS **11.8.8** | `:latest` is now 12.x |
| nginx | `:stable-alpine` | **1.30.4** (stable) | Tag still valid; recent CVEs in 1.30.x |
| Z-Wave JS UI | `:latest` | **11.22.2** | Likely 9.x → 11.x if last pulled in 2024 |
| Node-RED | custom `:latest` | Official `nodered/node-red` **5.0.4** / 4.1.13 | Custom image is a maintenance liability |
| Ubuntu target | “minimal Ubuntu Server” | 24.04 LTS / 26.04 | 22.04 still OK; 26.04 exists |

Terraform has been BSL-licensed since 1.6 (2023). OpenTofu is the MPL alternative if license terms matter.

---

## 4. What is actually broken or fragile

These are bugs and design problems in the current code, not just “old versions.”

### 4.1 Bootstrap wait loop does not sleep

```bash
until sudo k0s status | grep -m 1 "Kube-api probing successful: true" > /dev/null; do : sleep 1; done;
```

`:` is a no-op that ignores its arguments, so this busy-loops at 100% CPU until k0s is ready. It should be `sleep 1`.

### 4.2 ClusterRoleBinding uses the wrong kubeconfig path

```bash
sudo k0s kubectl create clusterrolebinding --kubeconfig k0s.config ...
```

The kubeconfig was written to `$HOME_STACK_ROOT/k0s.config` (`/opt/home-stack/k0s.config`). This command looks for `./k0s.config`. The user is also in `system:masters`, so the binding is redundant if the kubeconfig is used correctly — and insufficient (`clusterrole=admin` ≠ `cluster-admin`) if it is not.

### 4.3 Secrets tooling is installed and then ignored

- README lists **git-crypt**; bootstrap installs git-crypt **and** SOPS.
- Terraform does `yamldecode(file(.../home-assistant/secrets.yaml))` with no decrypt step.
- SOPS is never invoked. git-crypt is never invoked.

Whichever tool the config repo uses, this repo does not wire it up.

### 4.4 `get_latest_git_release` is brittle

It greps `location:` from a GitHub HTML redirect. Header casing, rate limits, and asset-name changes will fail the SOPS install silently (`sops_version` empty → 404 `.deb`).

### 4.5 Terraform root module is incomplete

- `required_providers` / `required_version` live only on the **module**, not the root.
- Root uses unversioned `kubernetes_namespace`, `kubernetes_deployment`, `kubernetes_service`. Provider 3.0 deprecates those; 4.0 will remove them. Migration target: `kubernetes_*_v1` plus `moved` blocks.
- State is a **local file inside the config repo path**. Secrets from `env` land in that state. There is no backup, locking, or encryption.

### 4.6 `:latest` + `imagePullPolicy: Always`

Every pod restart can pull a new major version (MariaDB 11 → 12, Grafana 10 → 13, Z-Wave 9 → 11) with no review. That is how home-lab databases get surprise-upgraded. `Always` was added in the last commit specifically to make floating tags work.

### 4.7 USB device paths will break

`/dev/ttyUSB0` etc. are enumeration order, not identity. Z-Wave JS docs now tell you **not** to use them; use `/dev/serial/by-id/...`. Unplugging a stick or adding a second adapter can swap HA and Z-Wave onto the wrong radios.

### 4.8 Home Assistant discovery will be weak

HA is a ClusterIP/NodePort pod, not `hostNetwork: true`. mDNS, SSDP, DHCP discovery, and many integrations expect to be on the LAN. This is a common reason people abandon k8s for HA Container on Docker with `network_mode: host`, or run HA OS.

### 4.9 Privileged containers for USB

Home Assistant and Z-Wave JS run `privileged: true` to mount serial devices. That grants full host access. Device cgroup rules, `hostPath` type `CharDevice`, and a tighter securityContext are the modern substitute.

### 4.10 MariaDB is published to the LAN

NodePort 30100 exposes MySQL on every node IP. Grafana/HA/Node-RED are also published without TLS. nginx is on 32767 rather than 80/443 (k0s may already bind 80 via Traefik/extensions).

### 4.11 Grafana/MariaDB hostPath permissions

Grafana runs as uid 472; MariaDB as 999. hostPath mounts often come up owned by the bootstrap user. No `fsGroup` / `runAsUser` is set. This is a frequent first-boot failure.

### 4.12 nginx mounts a **file** as hostPath

`local_config_path` points at `nginx.conf` and mounts it at `/etc/nginx/nginx.conf`. Kubernetes hostPath-to-file is fragile (missing file → directory mount → nginx fails). A ConfigMap is the usual pattern.

### 4.13 Custom Node-RED image

`lukiffer/node-red-home-assistant:latest` is not the official image. If that Docker Hub repo is unmaintained, it will not pick up Node-RED 4/5, Node.js, or `node-red-contrib-home-assistant-websocket` updates. Prefer `nodered/node-red` plus a small Dockerfile that `npm install`s the HA nodes.

### 4.14 HashiCorp apt key is not actually verified

The script prints the GPG fingerprint and continues. Current HashiCorp install docs still use this pattern, but they also tell you to **match** `798A EC65 4E5C 1542 8C8E 42EE AA16 FCBC A621 E701`. The script never checks.

### 4.15 `curl | bash` supply chain

README installs the stack by piping GitHub raw content into bash; bootstrap then pipes `get.k0s.sh` into bash. Fine for a trusted homelab in 2024; not a modernization target to keep as the only path.

---

## 5. Kubernetes / Terraform module gaps

The shared module is a thin Deployment wrapper. Missing pieces that a 2026 homelab k8s stack usually has:

| Gap | Why it matters |
| --- | --- |
| No liveness/readiness probes | Recreate + Always pull can leave a dead pod with no restart signal besides crash |
| No CPU/memory requests/limits | One HA recorder spike can OOM the node and take k0s with it |
| Recreate strategy on everything | Intentional for USB/single-instance, but Grafana/nginx could RollingUpdate |
| No StatefulSet for MariaDB | Deployments + hostPath work until a reschedule; STS + PVC is the k8s-native shape |
| No PVC / local-path provisioner | k0s can ship a local-path storage class; hostPath is node-locked by design |
| Secrets in Terraform env | Visible in `terraform state`, pod spec, and crash dumps. Use k8s Secrets + envFrom, or SOPS+KSOPS/External Secrets |
| No Ingress / TLS | NodePorts + optional nginx. k0s can enable Traefik or you keep nginx but terminate TLS (Caddy or cert-manager + Ingress) |
| No NetworkPolicy | MariaDB should not be reachable from the LAN; only from HA |
| No PodSecurity / restricted PSS | Privileged + hostPath will fail any baseline PSS you enable later |
| Typo in variable description | `Requireds privileged` in `variables.tf` |

The module comment already notes that `gitRepo` volumes are gone and that hostPath will not survive a second node. That second-node path was never designed.

---

## 6. Docs and repo hygiene

- README covers only bootstrap, recommends embedding a GitHub username + PAT in the clone URL (password auth to GitHub has been dead for years; fine-grained PATs / SSH / `gh auth` are the current advice).
- No architecture diagram, no port table, no upgrade/backup procedure, no “how to apply config changes.”
- No LICENSE.
- `.gitignore` ignores tfstate in **this** repo, but state is written under the **config** repo path — that repo needs its own ignore/encryption story.
- `software-properties-common` is installed and unused (leftover from older apt-add-repository flows).
- Bootstrap `apt-get upgrade -y` on first run can reboot-worthy kernel upgrades with no warning.

---

## 7. Strategic fork in the road

Before spending effort on provider 3.x and pinned images, decide whether Kubernetes is still the right runtime.

**Keep k0s + Terraform** if you want a programmable cluster, may add nodes later, or already depend on this layout.

**Consider Docker Compose / Quadlet** if this stays one machine with USB sticks. Compose is what Home Assistant Container docs assume (`network_mode: host`, `devices:`). You would keep the config-repo idea and drop most of the k8s module.

**Consider Home Assistant OS** if add-ons (Mosquitto, Node-RED, Z-Wave JS, Grafana) are the main value. That is the supported appliance path as of 2025–2026; Core/Supervised are unsupported.

The rest of this report assumes you **keep the k0s homelab**, because that is what the repo is. If you switch runtimes, treat sections 8.1–8.2 as still valid (pin versions, fix secrets, stop using `ttyUSB*`) and drop the Terraform provider work.

---

## 8. Recommended workstreams

Prioritized by “will this bite a reinstall or an in-place upgrade.” Effort is relative, not calendar time.

### P0 — Make a fresh install survivable

1. **Pin every image** to a digest or at least `major.minor` (HA `2026.8.2`, Grafana `11.x` or `13.2.0` after a changelog read, MariaDB `11.8` LTS not `latest`/`12`, nginx `1.30.4-alpine`, zwave-js-ui `11.22.2`). Change default `image_pull_policy` to `IfNotPresent`.
2. **Switch HA image** to `ghcr.io/home-assistant/home-assistant:<version>`.
3. **Fix bootstrap**: real `sleep`, absolute kubeconfig path, `set -euo pipefail`, pin k0s version (`K0S_VERSION=v1.36.3+k0s.2` or similar), verify HashiCorp fingerprint, stop installing unused packages (or actually use SOPS).
4. **USB by-id paths** for Z-Wave and HA radios; document how to discover them.
5. **Stop exposing MariaDB on a NodePort.** ClusterIP only.
6. **Replace the custom Node-RED image** with official `nodered/node-red` + a Dockerfile in this repo for HA nodes.

### P1 — Catch up the platform

1. Pin Terraform (`1.15.x`) or migrate to OpenTofu; put `required_version` and `required_providers` on the **root** module.
2. Upgrade kubernetes provider **2.23 → 2.38 first** (still unversioned resources), then **3.2.x** with `kubernetes_deployment_v1` / `kubernetes_service_v1` / `kubernetes_namespace_v1` and `moved` blocks so state does not recreate pods.
3. Pin k0s and document upgrades (`k0sctl` or k0s’ own update path). Jumping 1.29 → 1.36 in one shot on a live cluster is risky; plan minor hops or rebuild.
4. Decide SOPS **or** git-crypt; decrypt in `init.sh` or use `sops` provider / KSOPS so Terraform never reads plaintext from disk in git.
5. Move secrets out of Deployment env where possible (`kubernetes_secret_v1` + `env_from`). Assume existing tfstate is sensitive.

### P2 — Make the workloads production-shaped (for a homelab)

1. Probes, resources, `fsGroup` / `runAsUser` per image.
2. MariaDB as StatefulSet + PVC (k0s local-path).
3. Drop `privileged` in favor of device mounts + capabilities.
4. `hostNetwork: true` (or macvlan/host-device CNI) for Home Assistant if LAN discovery matters; keep NodePort only for UI if not.
5. Ingress or Caddy in front of HA / Grafana / Node-RED / Z-Wave UI; TLS (internal CA or Let's Encrypt DNS-01).
6. Grafana: pin OSS `grafana/grafana:<ver>` (or Enterprise if you want that default); set admin password via secret; do not bind data dir over a git checkout if the config repo is not meant to store Grafana’s sqlite.
7. nginx: ConfigMap + optional TLS; or replace with k0s Traefik Ingress.

### P3 — Repo and operations

1. CI: `terraform fmt -check`, `terraform validate`, `tflint`, `shellcheck` on `bootstrap.sh`.
2. Dependabot / Renovate for image tags and the kubernetes provider.
3. Backup story: HA snapshots, MariaDB dump, Z-Wave network backup, k0s etcd/kine snapshot, off-box copy of `/opt/home-stack/config`.
4. README: architecture, ports, config-repo contract (`secrets.yaml` keys, directory layout), upgrade and destroy.
5. LICENSE.
6. Optional: Mosquitto, if HA + Node-RED are still MQTT-centric (not in repo today).
7. Optional: replace Terraform-for-k8s with Helm/Kustomize. Terraform is a weak k8s app deployer; it is fine to keep it only for bootstrapping.

---

## 9. Suggested implementation order

Do not start with “upgrade Terraform provider to 3.x.” A provider bump that recreates privileged USB pods will take the Z-Wave network down.

1. Inventory the **live** host (if it still exists): k0s version, image digests actually running, USB by-id names, whether config repo uses git-crypt or plaintext.
2. Backup config + MariaDB + HA + Z-Wave.
3. P0 pins and bootstrap fixes on a branch; test on a spare VM without USB first.
4. In-place image pins on the live box (HA last; it has the longest changelog).
5. Provider 2.38, then 3.x with `moved`.
6. Networking/TLS/secrets refactor.
7. Docs + CI so it cannot silently rot again.

---

## 10. Out of scope / not found

This repo does **not** contain: MQTT, Pi-hole/AdGuard, unifi/controller, Prometheus, Loki, cert-manager, Traefik values, k0sctl cluster yaml, Ansible, or the actual Home Assistant configuration. Those may live in the separate config repo. A full modernization of “the home lab” needs that repo in the same review.

---

## 11. Bottom line

The design (Ubuntu + k0s single-node + Terraform Deployments + a git config repo) is still coherent for a homelab. Almost every pin is floating or two years behind, bootstrap has real bugs, secrets/USB/network exposure are weaker than 2026 norms, and Home Assistant in default k8s networking remains the biggest functional risk.

Minimum useful modernization: **pin versions, fix bootstrap, stop NodePort-ing the database, use serial-by-id, replace the custom Node-RED image, and put provider/CLI constraints on the root module.** Everything else is hardening and catching up to Kubernetes 1.36 / Terraform 1.15 / HA 2026.8.
