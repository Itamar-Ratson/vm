# Ephemeral VM, no persistence

The VM exists to give the operator an isolated clean-slate environment for trying projects like `backstage-k8s-full`. We deliberately chose an ephemeral lifecycle — every `terraform apply` produces a fresh VM, and there is no supported way to stop, snapshot, or resume one. The cleanroom guarantee is the product; persistence would erode it (cached image layers, stale Kubernetes clusters, edited dotfiles silently changing the outcome of "the same" experiment).

The cost is real: cloud-init + `ubuntu-desktop-minimal` + tool installs takes ~5–8 min on every recreation. We accept that cost in exchange for reproducibility. Anything the operator wants to keep across sessions belongs in the host repo (e.g., a fork of the project they're trying), not in the VM.
