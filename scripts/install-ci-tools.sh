#!/usr/bin/env bash
set -euo pipefail
# Runner-only tooling. Official release archives and SHA256; no curl | sh.
TOOL_DIR="${CI_TOOL_DIR:-${RUNNER_TEMP:?RUNNER_TEMP required}/tc3-tools}"
mkdir -p "$TOOL_DIR"
install_archive() {
  local base="$1" archive="$2" checksum_file="$3" binary="$4"
  curl -fsSL --connect-timeout 10 --max-time 90 "$base/$archive" -o "$TOOL_DIR/$archive"
  curl -fsSL --connect-timeout 10 --max-time 30 "$base/$checksum_file" -o "$TOOL_DIR/checksums"
  local checksum
  checksum="$(awk -v file="$archive" '$2 == file || $2 == "*" file {print $1}' "$TOOL_DIR/checksums")"
  [[ "$checksum" =~ ^[a-fA-F0-9]{64}$ ]]
  printf '%s  %s\n' "$checksum" "$TOOL_DIR/$archive" | sha256sum -c -
  tar -xzf "$TOOL_DIR/$archive" -C "$TOOL_DIR" "$binary"
  chmod +x "$TOOL_DIR/$binary"
}
install_archive https://github.com/rhysd/actionlint/releases/download/v1.7.12 actionlint_1.7.12_linux_amd64.tar.gz actionlint_1.7.12_checksums.txt actionlint
install_archive https://github.com/yannh/kubeconform/releases/download/v0.8.0 kubeconform-linux-amd64.tar.gz CHECKSUMS kubeconform
HELM_ARCHIVE=helm-v3.22.1-linux-amd64.tar.gz
curl -fsSL --connect-timeout 10 --max-time 90 "https://get.helm.sh/$HELM_ARCHIVE" -o "$TOOL_DIR/$HELM_ARCHIVE"
curl -fsSL --connect-timeout 10 --max-time 30 "https://get.helm.sh/$HELM_ARCHIVE.sha256sum" -o "$TOOL_DIR/helm.sha256"
HELM_SHA="$(awk '{print $1}' "$TOOL_DIR/helm.sha256")"
[[ "$HELM_SHA" =~ ^[a-fA-F0-9]{64}$ ]]
printf '%s  %s\n' "$HELM_SHA" "$TOOL_DIR/$HELM_ARCHIVE" | sha256sum -c -
tar -xzf "$TOOL_DIR/$HELM_ARCHIVE" -C "$TOOL_DIR" linux-amd64/helm
install -m 755 "$TOOL_DIR/linux-amd64/helm" "$TOOL_DIR/helm"
printf '%s\n' "$TOOL_DIR" >> "${GITHUB_PATH:?GITHUB_PATH required}"
