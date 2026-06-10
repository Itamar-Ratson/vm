# Project Context

This repository builds a local DevOps sandbox VM for short-lived experiments.

## Terms

- **Ephemeral VM**: the libvirt VM created by Terraform for an operator experiment. It is destroyed and recreated rather than stopped, resumed, or treated as durable.
- **Clean-slate environment**: a fresh libvirt domain created from the same Pre-baked image with runtime identity regenerated at first boot. SSH host keys, cloud-init state, and the operator's authorized key are not sealed into the image.
- **Pre-baked image**: the qcow2 image produced by Packer with the desktop, SPICE guest support, `dev` user, and Tool catalog already installed.
- **Builder VM**: the transient VM Packer boots to create and seal the Pre-baked image.
- **Tool catalog**: the supported set of DevOps tools installed into the sandbox image.
- **Install script**: a `scripts/install-<name>.sh` shell script that installs one catalog tool and records its resolved version. Each script can be run by the Packer image build or by the install-script CI matrix.

See `docs/adr/0001-ephemeral-vm.md`, `docs/adr/0002-cloud-init-over-ansible.md`, and `docs/adr/0003-prebaked-image.md` for the design rationale.
