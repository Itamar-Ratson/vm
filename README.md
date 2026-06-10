# DevOps Sandbox VM

Terraform provisions an ephemeral Ubuntu 24.04 VM on local libvirt from a pre-baked qcow2 image. The VM is meant to be created, used for an experiment, and destroyed cleanly.

The image already contains `ubuntu-desktop-minimal`, Firefox, SPICE guest support, qxl video, the Tool catalog, and GDM autologin for the `dev` user. Runtime cloud-init only injects your SSH key, so `terraform apply` works against a ready image instead of installing a desktop and tools during first boot.

Project terms are defined in `CONTEXT.md`. The lifecycle and provisioning decisions are recorded in `docs/adr/0001-ephemeral-vm.md`, `docs/adr/0002-cloud-init-over-ansible.md`, and `docs/adr/0003-prebaked-image.md`.

## Prerequisites

- Linux host with KVM support.
- `libvirt`, `qemu-kvm`, `virt-manager`, and `virt-viewer` installed.
- Packer installed for local image builds.
- Your host user is in the `libvirt` and `kvm` groups. Log out and back in after changing group membership.
- An SSH public key at `~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub`, or set `ssh_pubkey_path` in `terraform/terraform.tfvars`.

Terraform connects to `qemu:///system` and uses the libvirt `default` storage pool and default NAT network.

## Build the image

Build the pre-baked image before the first Terraform apply, and rebuild it whenever you want to pick up upstream package changes or Tool catalog changes:

```sh
./packer/build.sh
```

The build is a one-time cost for each image revision and usually takes about 10-15 minutes. The output lands at `packer/output/devops-sandbox-base.qcow2`.

ADR-0003 explains the rationale: slow desktop and tool installs happen once in Packer, while Terraform creates fresh Ephemeral VMs quickly from the sealed image.

## Usage

Work from the Terraform module:

```sh
cd terraform
terraform init
terraform apply
```

Applies should complete in seconds against a pre-built image because runtime cloud-init only writes `/home/dev/.ssh/authorized_keys`.

Copy the example variables if you want to override defaults:

```sh
cp terraform.tfvars.example terraform.tfvars
```

Print the GUI command:

```sh
terraform output virt_viewer_command
```

Run the printed command to open the SPICE display. GDM logs in as `dev` automatically, Firefox is available from the GNOME desktop, and `spice-vdagent` enables SPICE clipboard sharing.

Print the SSH command:

```sh
terraform output ssh_command
```

Destroy the VM when you are done:

```sh
terraform destroy
```

## Defaults

```hcl
vm_vcpus        = 6
vm_memory_mib   = 8192
vm_disk_gb      = 20
ssh_pubkey_path = null
image_path      = "../packer/output/devops-sandbox-base.qcow2"
```

The pre-baked image is allocated at 12 GB. `vm_disk_gb` cannot be lower than that image allocation because cloud-init `growpart` only grows the root partition on first boot.

Use `image_path` as the escape hatch when testing a new build before promoting it. Point one Terraform apply at a candidate qcow2, then switch back to the known-good qcow2 to A/B between builds.

On a 16 GB host, the 8 GB VM default leaves limited RAM for the host. Close heavy applications before applying. The 20 GB disk is enough for the initial sandbox, but DevOps workloads can use space quickly; increase `vm_disk_gb` to `30` or more if your host has room.

## Layout

- `packer/`: Packer template, build wrapper, cleanup script, seed files, and local image output.
- `scripts/`: install-and-configure scripts for catalog tools, named `scripts/install-<name>.sh`.
- `terraform/`: libvirt VM module, cloud-init template, variables, outputs, and example tfvars.
- `docs/adr/`: project architecture decisions.

## Tool Catalog

Packer runs each selected `scripts/install-<name>.sh` file while building the image. An empty or missing pin installs the latest available version for that script.

To add a tool, add `scripts/install-<name>.sh`, then update the Packer catalog configuration and rebuild the image. Each install script should install and configure the tool, then append one `<name>: <resolved version>` line to `/etc/vm-tool-versions.txt`.

## Testing Install Scripts

The GitHub Actions workflow in `.github/workflows/install-scripts.yml` runs every install script in a fresh `ubuntu:24.04` container twice: once with `TOOL_VERSION=""` for latest, and once with a known-good pin from the workflow matrix.

Run the same latest-style assertion locally with Docker:

```sh
docker run --rm -v "$PWD/scripts:/scripts:ro" ubuntu:24.04 bash -c \
  'set -euo pipefail
   apt-get update
   apt-get install -y curl ca-certificates sudo
   TOOL_VERSION="" /scripts/install-kind.sh
   test -n "$(kind --version)"
   grep -E "^kind: .*[0-9]" /etc/vm-tool-versions.txt'
```

To test a pinned version, pass `TOOL_VERSION` and assert the reported version and version-file line:

```sh
docker run --rm -e TOOL_VERSION=v0.32.0 -v "$PWD/scripts:/scripts:ro" ubuntu:24.04 bash -c \
  'set -euo pipefail
   apt-get update
   apt-get install -y curl ca-certificates sudo
   /scripts/install-kind.sh
   kind --version | grep -F "v0.32.0"
   grep -E "^kind: .*v0.32.0" /etc/vm-tool-versions.txt'
```
