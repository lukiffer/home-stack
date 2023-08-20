#!/usr/bin/env bash

HOME_STACK_ROOT="/opt/home-stack"
HOME_STACK_SOURCE="$HOME_STACK_ROOT/source"
HOME_STACK_CONFIG="$HOME_STACK_ROOT/config"

function init_directories() {
  sudo mkdir -p "$HOME_STACK_ROOT"
  sudo mkdir -p "$HOME_STACK_SOURCE"
  sudo mkdir -p "$HOME_STACK_CONFIG"
}

function get_latest_git_release() {
  local -r repository_url="$1"
  local -r tag=$(curl -sSL --head "$repository_url/releases/latest" | grep 'location:' | sed -e "s|location: $repository_url/releases/tag/||" | tr -d '\r')
  printf "%s" "$tag"
}

function update_system() {
  # Get latest package manifests
  sudo apt-get update

  # Upgrade packages
  sudo apt-get upgrade -y
}

function install_dependencies() {
  # Install prerequisite packages
  sudo apt-get update
  sudo apt-get install -y \
    ca-certificates \
    curl \
    git \
    git-crypt \
    gnupg \
    lsb-release \
    software-properties-common
}

function install_k0s() {
  # Install and start k0s
  curl -sSLf https://get.k0s.sh | sudo sh
  sudo k0s install controller --single
  sudo k0s start

  # Create a user Terraform will use to provision pods and services
  sudo k0s kubeconfig create --groups "system:masters" ha | sudo tee "$HOME_STACK_ROOT/k0s.config"

  # Create a roleBinding to grant the user access to the resources
  sudo k0s kubectl create clusterrolebinding --kubeconfig k0s.config ha-admin-binding --clusterrole=admin --user=ha
}

function install_sops() {
  # Install SOPS
  local -r sops_repo="https://github.com/mozilla/sops"
  local -r sops_version=$(get_latest_git_release "$sops_repo")

  sudo curl -fsSL "$sops_repo/releases/download/$sops_version/sops_${sops_version/v/}_$(dpkg --print-architecture).deb" -o sops.deb
  sudo dpkg -i sops.deb
  sudo rm sops.deb
}

function install_terraform() {
  wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg

  gpg --no-default-keyring \
    --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    --fingerprint

  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list

  sudo apt-get update
  sudo apt-get install -y terraform
}

function clone_source_repo() {
  sudo git clone "https://github.com/lukiffer/home-stack.git" "$HOME_STACK_SOURCE"
}

function clone_config_repo() {
  echo "Enter the git URI of the configuration repository (press enter for none):"
  read -r git_uri

  if [ -n "$git_uri" ]; then
    sudo git clone "$git_uri" "$HOME_STACK_CONFIG"
  else
    echo "No git URI supplied for a configuration repository. Empty config will be used."
  fi
}

function main() {
  set -x;
  init_directories
  update_system
  install_dependencies
  install_sops
  install_terraform
  clone_source_repo
  clone_config_repo
  set +x;
}

main "$@"
