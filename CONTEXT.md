# Project Context

This repository builds a local DevOps sandbox VM for short-lived experiments.

## Terms

- **Ephemeral VM**: the libvirt VM created by Terraform for an operator experiment. It is destroyed and recreated rather than stopped, resumed, or treated as durable.
- **Clean-slate environment**: the expected starting state after creating an Ephemeral VM from a known image, with no carry-over from previous experiments.
- **Pre-baked image**: the qcow2 image produced by Packer with the desktop, SPICE guest support, `dev` user, and Tool catalog already installed.
- **Builder VM**: the transient VM Packer boots to create and seal the Pre-baked image.
- **Tool catalog**: the supported set of DevOps tools installed into the sandbox image.
- **Install script**: a `scripts/install-<name>.sh` shell script that installs one catalog tool and records its resolved version.

See `docs/adr/0001-ephemeral-vm.md`, `docs/adr/0002-cloud-init-over-ansible.md`, and `docs/adr/0003-prebaked-image.md` for the design rationale.
