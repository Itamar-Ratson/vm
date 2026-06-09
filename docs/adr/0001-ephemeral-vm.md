# ADR 0001: Ephemeral VM Lifecycle

Status: Accepted

## Context

The sandbox is meant for trying DevOps-heavy projects without coupling their dependencies, caches, or partial state to the host laptop.
The host should only need libvirt, KVM, Terraform, and an SSH key.

## Decision

The VM lifecycle is ephemeral.
`terraform apply` creates a fresh VM and `terraform destroy` removes it.
No persistence, snapshots, resume flow, or in-place upgrade path is part of the contract.

Project sources are cloned by the operator inside the VM for each experiment.
Long-lived source history remains on the host or in Git, not in the sandbox disk.

## Consequences

This keeps experiments repeatable because old Docker images, KinD clusters, ArgoCD state, Terraform state, and ad-hoc package changes do not survive a destroy and recreate cycle.

Operators who need different tools or VM sizing change Terraform variables, then recreate the VM.
Any data that matters must be pushed to Git, copied out, or otherwise preserved before `terraform destroy`.
