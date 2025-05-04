#!/bin/bash

set -euo pipefail

# Check if a command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# Install required tools
ensure_dependencies() {
  if ! command_exists kustomize; then
    echo "Installing kustomize..."
    brew install kustomize || { echo "Error: Failed to install kustomize"; exit 1; }
  fi

  if ! command_exists kubernetes-split-yaml; then
    echo "Installing kubernetes-split-yaml..."
    go install github.com/mogensen/kubernetes-split-yaml@v0.4.0 || { echo "Error: Failed to install kubernetes-split-yaml"; exit 1; }
  fi

  if ! command_exists helm; then
    echo "Installing helm..."
    brew install helm || { echo "Error: Failed to install helm"; exit 1; }
  fi
}

# Generate Kubernetes manifests from a given directory
generate_manifest() {
  local dir=$1
  local kustom_file="$dir/kustomization.yaml"

  [[ -f "$kustom_file" ]] || return

  if grep -qE '^\s*#?\s*kustomization: ?render' "$kustom_file"; then
    echo "Rendering manifests in '$dir'..."

    rm -rf "$dir/default"
    mkdir -p "$dir/default"

    kustomize build --enable-helm "$dir" > "$dir/00_install.yaml"
    kubernetes-split-yaml --outdir "$dir/default" "$dir/00_install.yaml"

    {
      echo "---"
      echo "resources:"
      find "$dir/default" -type f -name '*.yaml' -not -name 'kustomization.yaml' -exec basename {} \; | sort | sed 's/^/- /'
    } > "$dir/default/kustomization.yaml"

    rm -f "$dir/00_install.yaml"
  else
    echo "Skipping '$dir' (no '#kustomization:render' found)"
  fi
}

main() {
  ensure_dependencies

  if [ "${1:-}" ]; then
    generate_manifest "base/$1"
  else
    for dir in base/*; do
      [ -d "$dir" ] && generate_manifest "$dir"
    done
  fi
}

main "$@"