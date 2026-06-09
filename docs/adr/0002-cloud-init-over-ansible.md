# cloud-init + per-tool scripts, no Ansible

A reader expecting a "DevOps VM" project will reasonably wonder where Ansible is. We considered it and chose cloud-init + per-tool shell scripts instead.

The tool catalog is tight (~9 entries) and the post-install configuration surface is genuinely small: two lines for Docker (group + systemctl), nothing for KinD/Helm/kubectl/Terraform (their config is generated at runtime by the projects we run inside the VM), and `gh auth` is interactive by design. Ansible's value proposition — idempotent reconciliation, role composition, templated multi-service config — is wasted here because the VM is ephemeral (idempotency is moot) and there are no multi-service config files to template.

The cost of adding Ansible would be a real extra layer in the boot chain (Terraform → libvirt → cloud-init → Ansible → tools), with the corresponding extra failure mode and an inventory/push-vs-pull decision. cloud-init runs the scripts directly via `runcmd`; each script is self-contained install-and-configure for one tool. We will revisit this decision if (a) the catalog grows past ~20 tools, or (b) the same toolset needs to be applied to bare-metal or non-libvirt hosts.
