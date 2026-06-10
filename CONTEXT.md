# Project Context

This project provisions an Ephemeral VM for local DevOps experiments. An Ephemeral VM is created from a known image, used for a bounded task, and destroyed instead of being repaired in place.

The Tool catalog is the set of installable command-line tools maintained by the repository. Each Install script lives at `scripts/install-<name>.sh` and can be run by the Packer image build or by the install-script CI matrix.

A Pre-baked image is the qcow2 artifact produced by Packer. It contains the desktop, the `dev` user, SPICE/qxl support, and the Tool catalog before Terraform runs.

A Clean-slate environment means a fresh libvirt domain created from the same Pre-baked image with runtime identity regenerated at first boot. SSH host keys, cloud-init state, and the operator's authorized key are not sealed into the image.
