# DevOps Sandbox VM

Terraform provisions an ephemeral Ubuntu 24.04 VM on local libvirt. The VM is meant to be created, used for an experiment, and destroyed cleanly.

This first slice creates a headless Ubuntu Server VM, injects your SSH key, creates the `dev` user, grants passwordless sudo, and waits for cloud-init before `terraform apply` returns.
It also installs the selected tool catalog during cloud-init. The default catalog contains Docker and the Docker Compose plugin, KinD, Helm, kubectl, Terraform, Git, GitHub CLI, jq, and yq.

## Prerequisites

- Linux host with KVM support.
- `libvirt`, `qemu-kvm`, and `virt-manager` installed.
- Your host user is in the `libvirt` and `kvm` groups. Log out and back in after changing group membership.
- An SSH public key at `~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub`, or set `ssh_pubkey_path` in `terraform.tfvars`.

The provider connects to `qemu:///system` and uses the libvirt `default` storage pool and default NAT network.

## Usage

Copy the example variables if you want to override defaults:

```sh
cp terraform.tfvars.example terraform.tfvars
```

Create the VM:

```sh
terraform init
terraform apply
```

When the apply finishes, cloud-init has reported `done` inside the VM. Print the SSH command:

```sh
terraform output ssh_command
```

Destroy the VM when you are done:

```sh
terraform destroy
```

## Defaults

- VM name: `devops-sandbox`
- User: `dev`
- vCPU: `6`
- RAM: `8192` MiB
- Disk: `20` GiB thin-provisioned qcow2
- Ubuntu image: `https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img`
- Tools: `["docker", "kind", "helm", "kubectl", "terraform", "git", "gh", "jq", "yq"]`
- Tool version pins: `{}`

On a 16 GB host, the 8 GB VM default leaves limited RAM for the host. Close heavy applications before applying. The 20 GB disk is enough for the initial sandbox, but DevOps workloads can use space quickly; increase `vm_disk_gb` to `30` or more if your host has room.

## Layout

- `versions.tf`: Terraform and provider requirements.
- `providers.tf`: libvirt provider connection.
- `variables.tf`: user-configurable inputs and SSH key detection.
- `cloudinit.tf`: cloud-init rendering and ISO disk.
- `main.tf`: libvirt volumes, domain, and cloud-init readiness gate.
- `outputs.tf`: VM IP and SSH command.
- `cloud-init/user-data.yaml.tftpl`: cloud-init user-data template.
- `scripts/install-<name>.sh`: install-and-configure scripts for catalog tools.

## Tool Catalog

Cloud-init writes each selected `scripts/install-<name>.sh` file into the VM and runs it with `TOOL_VERSION` set from the `tool_versions` map. An empty or missing pin installs the latest available version.

To add a tool, add `scripts/install-<name>.sh`, then add `<name>` to the `tools` list in `variables.tf` or `terraform.tfvars`. Each install script should install and configure the tool, then append one `<name>: <resolved version>` line to `/etc/vm-tool-versions.txt`.

To pin a tool version, set `tool_versions` in `terraform.tfvars`:

```hcl
tool_versions = {
  kind = "v0.32.0"
}
```

## Testing Install Scripts

Run an install script in the same base container used by CI-style checks:

```sh
docker run --rm -v "$PWD/scripts:/scripts:ro" ubuntu:24.04 bash -c \
  'apt-get update && apt-get install -y curl ca-certificates sudo && /scripts/install-kind.sh && kind --version && grep "^kind: " /etc/vm-tool-versions.txt'
```

To test a pinned version, pass `TOOL_VERSION`:

```sh
docker run --rm -e TOOL_VERSION=v0.32.0 -v "$PWD/scripts:/scripts:ro" ubuntu:24.04 bash -c \
  'apt-get update && apt-get install -y curl ca-certificates sudo && /scripts/install-kind.sh && kind --version && grep "^kind: " /etc/vm-tool-versions.txt'
```
