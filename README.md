# Home Stack

A single-node home-automation stack: Ubuntu host bootstrap, k0s, and Terraform-managed Kubernetes workloads (Home Assistant, MariaDB, Node-RED, Z-Wave JS UI, Grafana, nginx).

This repository was last changed in March 2024. See [MODERNIZATION.md](MODERNIZATION.md) for an inventory of stale versions, bootstrap bugs, and recommended work to bring it current.

## Bootstrapping the Host

```bash
curl -sSL https://raw.githubusercontent.com/lukiffer/home-stack/main/bootstrap.sh | bash
```

Running this script installs all of the prerequisites for running Home Stack on a minimal Ubuntu Server:
- `ca-certificates`
- `git`
- `git-crypt`
- `gnupg`
- `lsb-release`
- `software-properties-common`
- [k0s](https://github.com/k0sproject/k0s)
- [Terraform](https://github.com/hashicorp/terraform)

The installation will prompt you for the git URI of the configuration repository.

We recommend using `https://<username>@github.com/<username>/<repository_name>.git` – remember to supply your GitHub
personal access token rather than your account password when prompted (see https://docs.github.com/en/get-started/getting-started-with-git/about-remote-repositories#cloning-with-https-urls).
