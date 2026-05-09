#!/usr/bin/env bash
set -euo pipefail

ORG="${1:-seolith-llc}"
RUNNER_NAME="${2:-$(hostname)-seolith-build}"
RUNNER_VERSION="${RUNNER_VERSION:-2.329.0}"
RUNNER_USER="${RUNNER_USER:-github-runner}"
RUNNER_HOME="${RUNNER_HOME:-/opt/github-runner}"
RUNNER_LABELS="${RUNNER_LABELS:-seolith-build,docker,dotnet10,node24}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run with sudo: sudo $0 ${ORG} ${RUNNER_NAME}" >&2
  exit 1
fi

apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  git \
  jq \
  tar \
  unzip \
  docker.io

if ! id "${RUNNER_USER}" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "${RUNNER_USER}"
fi

usermod -aG docker "${RUNNER_USER}"
systemctl enable --now docker

mkdir -p "${RUNNER_HOME}"
chown -R "${RUNNER_USER}:${RUNNER_USER}" "${RUNNER_HOME}"

arch="$(uname -m)"
case "${arch}" in
  x86_64) runner_arch="x64" ;;
  aarch64|arm64) runner_arch="arm64" ;;
  *) echo "Unsupported architecture: ${arch}" >&2; exit 1 ;;
esac

runner_url="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${runner_arch}-${RUNNER_VERSION}.tar.gz"

sudo -u "${RUNNER_USER}" bash <<EOF
set -euo pipefail
cd "${RUNNER_HOME}"
if [[ ! -f .runner ]]; then
  curl -fsSL "${runner_url}" -o actions-runner.tar.gz
  tar xzf actions-runner.tar.gz
  rm actions-runner.tar.gz
fi
EOF

echo ""
echo "Create a short-lived registration token here:"
echo "https://github.com/organizations/${ORG}/settings/actions/runners/new?arch=${runner_arch}&os=linux"
echo ""
read -r -s -p "Registration token: " REGISTRATION_TOKEN
echo ""

sudo -u "${RUNNER_USER}" bash <<EOF
set -euo pipefail
cd "${RUNNER_HOME}"
if [[ -f .runner ]]; then
  echo "Runner already configured at ${RUNNER_HOME}."
else
  ./config.sh \
    --url "https://github.com/${ORG}" \
    --token "${REGISTRATION_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --labels "${RUNNER_LABELS}" \
    --work "_work" \
    --unattended \
    --replace
fi
EOF

cd "${RUNNER_HOME}"
./svc.sh install "${RUNNER_USER}"
./svc.sh start

echo "Runner installed:"
echo "  org: ${ORG}"
echo "  name: ${RUNNER_NAME}"
echo "  labels: self-hosted, linux, ${runner_arch}, ${RUNNER_LABELS}"
