#!/usr/bin/env bash

set -Euo pipefail

declare -r \
  apt_sources=/etc/apt/sources.list.d \
  apt_trusted=/etc/apt/trusted.gpg.d \
  runtime="${1:-}"

script_name=$(basename "${BASH_SOURCE[0]}")

source <(grep -F VERSION /etc/os-release)

has() {
  command -v "$1" &>/dev/null
}

check_exists() {
  has "$1" && {
    echo "$1 is already installed"
    exit
  }
}

add_apt_repo() {
  local -r name=$1 key=$2 repo=$3

  echo "Adding ${name} repo"

  curl -fsSL "${key}" | sudo gpg --dearmor -o "${apt_trusted}/${name}.gpg"

  echo "${repo}" | sudo tee "${apt_sources}/${name}.list" >/dev/null
}

apt_install() {
  echo "Installing $*"

  sudo apt-get -qq update
  sudo apt-get -qq install "$@"
}

pip-install() {
  has pip3 || {
    echo "Installing pip3"
    apt_install python3-pip
  }

  has "$1" || {
    echo "Installing $1"
    pip3 install --user -q "$1" &>/dev/null
  }
}

install-docker() {
  check_exists docker

  local -r repo_url="https://download.docker.com/linux/ubuntu/"

  add_apt_repo docker "${repo_url}gpg" "deb [arch=amd64] ${repo_url} ${VERSION_CODENAME} stable"

  apt_install docker-ce docker-ce-cli containerd.io docker-compose-plugin

  echo "Creating docker group"

  sudo groupadd docker >/dev/null
  sudo usermod -aG docker "${USER}"

  pip-install docker-compose
}

install-podman() {
  check_exists podman

  local -r repo_url="https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/testing/xUbuntu_${VERSION_ID}/"

  add_apt_repo devel:kubic:libcontainers:testing "${repo_url}Release.key" "deb ${repo_url} /"

  apt_install podman

  pip-install podman-compose

  grep -Fq 'docker()' ~/.profile || {
    echo "Adding aliases to ~/.profile"

    cat >>~/.profile <<"EOF"

  docker() {
    if [ "$1" = compose ]; then
      shift
      podman-compose "$@"
    else
      podman "$@"
    fi
  }

  export -f docker
  alias docker-compose=podman-compose
EOF
  }
}

case "${runtime}" in
  docker)
    install-docker
    ;;
  podman)
    install-podman
    ;;
  *)
    echo "USAGE

    ${script_name} <docker|podman>
    " >&2
    exit 1
    ;;
esac
