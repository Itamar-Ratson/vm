# Project Context

This repository provisions a disposable local DevOps sandbox VM with Terraform and libvirt.

## Glossary

### Ephemeral VM

A single Ubuntu 24.04 virtual machine created by `terraform apply` and removed by `terraform destroy`.
The VM is intentionally disposable: no snapshots, no resume workflow, and no persistence contract beyond the current Terraform-managed lifetime.

### Tool catalog

The Terraform `tools` list that selects which DevOps tools cloud-init installs on first boot.
The default catalog is Docker with the Compose plugin, KinD, Helm, kubectl, Terraform, Git, GitHub CLI, jq, and yq.

### Install script

A self-contained `scripts/install-<name>.sh` file that installs and configures one catalog tool.
Each script reads `TOOL_VERSION` from the environment, treats an empty value as latest, supports pins where the upstream package source allows it, and appends the resolved version to `/etc/vm-tool-versions.txt`.

### Clean-slate environment

The operating state inside a newly created VM before an operator runs an experiment.
The host provides libvirt, storage, networking, and SSH access, but project dependencies and caches live inside the VM and disappear when the VM is destroyed.

## Operating Model

Operators run `terraform apply`, wait for the cloud-init readiness gate, then enter the VM through SSH or the SPICE desktop.
Experiments such as `backstage-k8s-full` are cloned and run inside the VM, not baked into provisioning.
When the run is complete, `terraform destroy` removes the domain, cloud-init disk, and root disk from the libvirt default pool.
