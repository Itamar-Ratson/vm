const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");

function read(file) {
  return fs.readFileSync(path.join(root, file), "utf8");
}

[
  ".github/workflows/install-scripts.yml",
  ".github/workflows/cleanup-image.yml",
  "CONTEXT.md",
  "docs/adr/0001-ephemeral-vm.md",
  "docs/adr/0002-cloud-init-over-ansible.md",
  "packer/cleanup.sh",
  "packer/build.sh",
  "packer/devops-sandbox.pkr.hcl",
  "packer/seed/meta-data",
  "packer/seed/user-data.tpl",
  "packer/.gitignore",
  "terraform/versions.tf",
  "terraform/providers.tf",
  "terraform/variables.tf",
  "terraform/main.tf",
  "terraform/cloudinit.tf",
  "terraform/outputs.tf",
  "terraform/terraform.tfvars.example",
  "terraform/cloud-init/user-data.yaml.tftpl",
  "terraform/seclabel-none.xsl",
].forEach((file) => {
  assert.ok(fs.existsSync(path.join(root, file)), `${file} should exist`);
});

const variables = read("terraform/variables.tf");
const expectedTools = ["docker", "kind", "helm", "kubectl", "terraform", "git", "gh", "jq", "yq"];
const installWorkflow = read(".github/workflows/install-scripts.yml");
assert.match(installWorkflow, /on:\s+[\s\S]*push:/);
assert.match(installWorkflow, /on:\s+[\s\S]*pull_request:/);
assert.match(installWorkflow, /ubuntu:24\.04/);
assert.match(installWorkflow, /apt-get update/);
assert.match(installWorkflow, /apt-get install -y curl ca-certificates sudo/);
assert.match(installWorkflow, /variant:\s+\["latest", "pinned"\]/);
for (const tool of expectedTools) {
  assert.match(installWorkflow, new RegExp(`tool: ${tool}\\b`), `install workflow should include ${tool}`);
  assert.match(installWorkflow, new RegExp(`script: scripts/install-${tool}\\.sh`), `install workflow should run install-${tool}.sh`);
}
assert.match(installWorkflow, /docker compose version/);
assert.match(installWorkflow, /\/etc\/vm-tool-versions\.txt/);

const cleanupWorkflow = read(".github/workflows/cleanup-image.yml");
assert.match(cleanupWorkflow, /container:\s+ubuntu:24\.04/);
assert.match(cleanupWorkflow, /useradd[\s\S]*builder/);
assert.match(cleanupWorkflow, /\/etc\/ssh\/ssh_host_ed25519_key/);
assert.match(cleanupWorkflow, /\/var\/lib\/cloud\/data\/instance-id/);
assert.match(cleanupWorkflow, /packer\/cleanup\.sh/);
assert.match(cleanupWorkflow, /test ! -e \/etc\/ssh\/ssh_host_ed25519_key/);
assert.match(cleanupWorkflow, /test ! -d \/home\/builder/);
assert.match(cleanupWorkflow, /test ! -s \/etc\/machine-id/);
assert.match(cleanupWorkflow, /\/etc\/vm-build-info\.txt/);

const packerBuildPath = path.join(root, "packer", "build.sh");
const packerBuildMode = fs.statSync(packerBuildPath).mode;
assert.equal(packerBuildMode & 0o111, 0o111, "packer/build.sh should be executable");
const packerBuild = fs.readFileSync(packerBuildPath, "utf8");
assert.match(packerBuild, /set -euo pipefail/);
assert.match(packerBuild, /ssh-keygen -t ed25519/);
assert.match(packerBuild, /\.build/);
assert.match(packerBuild, /builder_id/);
assert.match(packerBuild, /cleanup\(\)[\s\S]*rm -rf/);
assert.match(packerBuild, /trap cleanup EXIT/);
assert.match(packerBuild, /sed[\s\S]*@SSH_PUBKEY@/);
assert.match(packerBuild, /packer build/);
assert.match(packerBuild, /source_cloud_image_sha256/);

const packerTemplate = read("packer/devops-sandbox.pkr.hcl");
assert.match(packerTemplate, /source "qemu" "ubuntu_noble"/);
assert.match(packerTemplate, /iso_checksum\s+= "none"/);
assert.match(packerTemplate, /memory\s+= 6144/);
assert.match(packerTemplate, /cpus\s+= 6/);
assert.match(packerTemplate, /disk_size\s+= "12G"/);
assert.match(packerTemplate, /cd_files\s+= \[/);
assert.match(packerTemplate, /seed\/user-data/);
assert.match(packerTemplate, /seed\/meta-data/);
assert.match(packerTemplate, /ssh_username\s+= "builder"/);
assert.match(packerTemplate, /ubuntu-desktop-minimal/);
assert.match(packerTemplate, /spice-vdagent/);
assert.match(packerTemplate, /AutomaticLogin=dev/);
assert.match(packerTemplate, /useradd[\s\S]*dev/);
assert.match(packerTemplate, /scripts\//);
assert.match(packerTemplate, /for tool in var\.tools/);
assert.match(packerTemplate, /install-\$\{tool\}\.sh/);
for (const tool of expectedTools) {
  assert.match(packerTemplate, new RegExp(`"${tool}"`), `Packer default catalog should include ${tool}`);
}
assert.match(packerTemplate, /cleanup\.sh/);
assert.match(packerTemplate, /qemu-img convert -c -O qcow2/);

const seedMetaData = read("packer/seed/meta-data");
assert.match(seedMetaData, /instance-id: builder/);
assert.match(seedMetaData, /local-hostname: builder-vm/);

const seedUserData = read("packer/seed/user-data.tpl");
assert.match(seedUserData, /#cloud-config/);
assert.match(seedUserData, /name: builder/);
assert.match(seedUserData, /@SSH_PUBKEY@/);
assert.match(seedUserData, /sudo: ALL=\(ALL\) NOPASSWD:ALL/);

const packerGitignore = read("packer/.gitignore");
assert.match(packerGitignore, /^output\/$/m);
assert.match(packerGitignore, /^\.build\/$/m);
assert.match(packerGitignore, /^cache\/$/m);

for (const removedVariable of ["tools", "tool_versions", "username", "vm_name"]) {
  assert.doesNotMatch(
    variables,
    new RegExp(`variable "${removedVariable}"\\s+\\{`),
    `${removedVariable} should not be a Terraform runtime variable`,
  );
}
assert.match(variables, /variable "vm_vcpus"[\s\S]*default\s+= 6/);
assert.match(variables, /variable "vm_memory_mib"[\s\S]*default\s+= 8192/);
assert.match(variables, /variable "vm_disk_gb"[\s\S]*default\s+= 20/);
assert.match(variables, /variable "image_path"[\s\S]*default\s+= "\$\{path\.module\}\/\.\.\/packer\/output\/devops-sandbox-base\.qcow2"/);
assert.match(variables, /~\/\.ssh\/id_ed25519\.pub/);
assert.match(variables, /~\/\.ssh\/id_rsa\.pub/);

const main = read("terraform/main.tf");
assert.match(main, /resource "libvirt_volume" "ubuntu_base"/);
assert.match(main, /source\s+= pathexpand\(var\.image_path\)/);
assert.match(main, /resource "libvirt_volume" "root"/);
assert.match(main, /base_volume_id\s+= libvirt_volume\.ubuntu_base\.id/);
assert.match(main, /name\s+= "devops-sandbox"/);
assert.match(main, /network_name\s+= "default"/);
assert.match(main, /wait_for_lease\s+= true/);
assert.match(main, /graphics\s+\{[\s\S]*type\s+= "spice"/);
assert.match(main, /video\s+\{[\s\S]*type\s+= "qxl"/);
assert.match(main, /xml\s+\{[\s\S]*xslt\s+= file\("\$\{path\.module\}\/seclabel-none\.xsl"\)/);
assert.match(main, /cloud-init status --wait/);

const cloudinit = read("terraform/cloudinit.tf");
assert.match(cloudinit, /resource "terraform_data" "ssh_pubkey_check"/);
assert.match(cloudinit, /No SSH public key was found/);
assert.match(cloudinit, /resource "libvirt_cloudinit_disk" "user_data"/);
assert.match(cloudinit, /meta_data\s+= yamlencode\(/);
assert.doesNotMatch(cloudinit, /install_scripts\s+=/);
assert.doesNotMatch(cloudinit, /tool_versions\s+=/);

const outputs = read("terraform/outputs.tf");
assert.match(outputs, /output "vm_ip"/);
assert.match(outputs, /output "ssh_command"/);
assert.match(outputs, /ssh dev@\$\{libvirt_domain\.vm\.network_interface\[0\]\.addresses\[0\]\}/);
assert.match(outputs, /output "hostname"/);
assert.match(outputs, /value\s+= "devops-sandbox"/);
assert.match(outputs, /output "virt_viewer_command"/);
assert.match(outputs, /virt-viewer --connect qemu:\/\/\/system devops-sandbox/);

const userData = read("terraform/cloud-init/user-data.yaml.tftpl");
assert.match(userData, /path: \/home\/dev\/\.ssh\/authorized_keys/);
assert.match(userData, /owner: dev:dev/);
assert.match(userData, /permissions: "0600"/);
assert.match(userData, /\$\{ssh_public_key\}/);
assert.doesNotMatch(userData, /packages:/);
assert.doesNotMatch(userData, /\/usr\/local\/sbin\/install-\$\{tool\}\.sh/);
assert.doesNotMatch(userData, /TOOL_VERSION=\$\{lookup\(tool_versions, tool, ""\)\}/);

const dockerScriptPath = path.join(root, "scripts", "install-docker.sh");
assert.ok(fs.existsSync(dockerScriptPath), "scripts/install-docker.sh should exist");
const dockerScript = fs.readFileSync(dockerScriptPath, "utf8");
assert.match(dockerScript, /TOOL_VERSION/);
assert.match(dockerScript, /download\.docker\.com\/linux\/ubuntu/);
assert.match(dockerScript, /docker-compose-plugin/);
assert.match(dockerScript, /usermod -aG docker/);
assert.match(dockerScript, /vm-tool-versions\.txt/);

for (const tool of expectedTools) {
  const scriptPath = path.join(root, "scripts", `install-${tool}.sh`);
  assert.ok(fs.existsSync(scriptPath), `scripts/install-${tool}.sh should exist`);

  const script = fs.readFileSync(scriptPath, "utf8");
  assert.match(script, /set -euo pipefail/, `install-${tool}.sh should fail fast`);
  assert.match(script, /TOOL_VERSION/, `install-${tool}.sh should read TOOL_VERSION`);
  assert.match(script, new RegExp(`\\[install-${tool}\\]`), `install-${tool}.sh should use the logging convention`);
  assert.match(script, /vm-tool-versions\.txt/, `install-${tool}.sh should write the version file`);
  assert.match(script, new RegExp(`${tool}: %s`), `install-${tool}.sh should record a ${tool} line`);
}

const cleanupScriptPath = path.join(root, "packer", "cleanup.sh");
const cleanupMode = fs.statSync(cleanupScriptPath).mode;
assert.equal(cleanupMode & 0o111, 0o111, "packer/cleanup.sh should be executable");
const cleanupScript = fs.readFileSync(cleanupScriptPath, "utf8");
assert.match(cleanupScript, /set -euo pipefail/);
assert.match(cleanupScript, /\/etc\/vm-build-info\.txt/);
for (const key of [
  "source_cloud_image_url",
  "source_cloud_image_sha256",
  "build_timestamp",
  "git_sha",
  "tools",
  "tool_versions",
]) {
  assert.match(cleanupScript, new RegExp(`^${key}=`, "m"), `cleanup.sh should write ${key}`);
}
assert.match(cleanupScript, /apt-get clean/);
assert.match(cleanupScript, /\/var\/lib\/apt\/lists/);
assert.match(cleanupScript, /\/tmp/);
assert.match(cleanupScript, /\/var\/tmp/);
assert.match(cleanupScript, /\/var\/log/);
assert.match(cleanupScript, /userdel -r builder/);
assert.match(cleanupScript, /\/var\/lib\/cloud/);
assert.match(cleanupScript, /\/var\/log\/cloud-init/);
assert.match(cleanupScript, /: >\/etc\/machine-id/);
assert.match(cleanupScript, /\/var\/lib\/dbus\/machine-id/);
assert.match(cleanupScript, /\/etc\/ssh\/ssh_host_/);
assert.match(cleanupScript, /fstrim -av/);

const readme = read("README.md");
assert.match(readme, /CONTEXT\.md/);
assert.match(readme, /docs\/adr\/0001-ephemeral-vm\.md/);
assert.match(readme, /docs\/adr\/0002-cloud-init-over-ansible\.md/);
assert.match(readme, /docs\/adr\/0003-prebaked-image\.md/);
assert.match(readme, /## Build the image/);
assert.match(readme, /Packer/);
assert.match(readme, /\.\/packer\/build\.sh/);
assert.match(readme, /10-15 minutes/);
assert.match(readme, /packer\/output\/devops-sandbox-base\.qcow2/);
assert.match(readme, /## Usage[\s\S]*terraform apply/);
assert.match(readme, /appl(?:y|ies)[\s\S]*seconds/);
assert.match(readme, /virt-viewer/);
assert.match(readme, /GNOME/);
assert.match(readme, /autologin/);
assert.match(readme, /ubuntu-desktop-minimal/);
assert.doesNotMatch(readme, /headless Ubuntu Server VM/);
assert.match(readme, /scripts\/install-<name>\.sh/);
assert.match(readme, /tools/);
assert.match(readme, /docker run/);
assert.match(readme, /vm_vcpus\s+= 6/);
assert.match(readme, /vm_memory_mib\s+= 8192/);
assert.match(readme, /vm_disk_gb\s+= 20/);
assert.match(readme, /ssh_pubkey_path\s+= null/);
assert.match(readme, /image_path\s+= "\.\.\/packer\/output\/devops-sandbox-base\.qcow2"/);
assert.match(readme, /vm_disk_gb[\s\S]*12 GB/);
assert.match(readme, /growpart[\s\S]*only grows/);
assert.match(readme, /image_path[\s\S]*A\/B/);
assert.match(readme, /packer\//);
assert.match(readme, /scripts\//);
assert.match(readme, /terraform\//);
assert.doesNotMatch(readme, /tools\s+=/);
assert.doesNotMatch(readme, /tool_versions\s+=/);
assert.doesNotMatch(readme, /username\s+=/);
assert.doesNotMatch(readme, /vm_name\s+=/);

const tfvarsExample = read("terraform/terraform.tfvars.example");
assert.match(tfvarsExample, /vm_vcpus/);
assert.match(tfvarsExample, /vm_memory_mib/);
assert.match(tfvarsExample, /vm_disk_gb/);
assert.match(tfvarsExample, /ssh_pubkey_path/);
assert.match(tfvarsExample, /image_path/);
assert.doesNotMatch(tfvarsExample, /tool_versions\s+= \{/);
assert.doesNotMatch(tfvarsExample, /tools\s+= \[/);

const gitignore = read(".gitignore");
assert.match(gitignore, /^terraform\.tfvars$/m);
assert.match(gitignore, /^\*\.tfstate$/m);
assert.match(gitignore, /^\*\.tfstate\.\*$/m);
assert.match(gitignore, /^\.terraform\/\*\*$/m);
assert.match(gitignore, /^!CONTEXT\.md$/m);
assert.match(gitignore, /^!packer\/seed\/meta-data$/m);

const context = read("CONTEXT.md");
assert.match(context, /Ephemeral VM/);
assert.match(context, /Tool catalog/);
assert.match(context, /Install script/);
assert.match(context, /Clean-slate environment/);

const ephemeralAdr = read("docs/adr/0001-ephemeral-vm.md");
assert.match(ephemeralAdr, /[Ee]phemeral VM/);
assert.match(ephemeralAdr, /no persistence/i);

const cloudInitAdr = read("docs/adr/0002-cloud-init-over-ansible.md");
assert.match(cloudInitAdr, /cloud-init/);
assert.match(cloudInitAdr, /Ansible/);
