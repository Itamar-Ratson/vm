# ADR 0002: Cloud-Init Provisioning Over Ansible

Status: Accepted

## Context

The sandbox needs a first-boot setup path for the desktop, SSH access, sudo policy, and a fixed catalog of DevOps tools.
The setup should run from a single `terraform apply` and finish before the command returns.

## Decision

Use cloud-init user-data plus per-tool shell scripts instead of Ansible.

Terraform renders `cloud-init/user-data.yaml.tftpl`, writes the selected `scripts/install-<name>.sh` files into the VM, and runs them from `runcmd` with `TOOL_VERSION` populated from `tool_versions`.
A Terraform `remote-exec` gate waits for `cloud-init status --wait` over SSH.

## Consequences

Provisioning stays self-contained in Terraform and the guest image.
Collaborators do not need an Ansible control setup, inventory, roles, or a separate provision command.

Each install script owns both installation and post-install configuration for one tool, which keeps catalog changes local: add the script, then add the tool name to the `tools` list.
The tradeoff is that complex orchestration features from Ansible are intentionally unavailable; this project prefers simple first-boot provisioning over a richer configuration-management layer.
