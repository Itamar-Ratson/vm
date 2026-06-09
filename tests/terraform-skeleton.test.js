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
  ".github/workflows/packer.yml",
  "CONTEXT.md",
  "docs/adr/0001-ephemeral-vm.md",
  "docs/adr/0002-cloud-init-over-ansible.md",
  "docs/adr/0003-prebaked-image.md",
  "packer/.gitignore",
  "packer/build.sh",
  "packer/cleanup.sh",
  "packer/devops-sandbox.pkr.hcl",
  "packer/seed/meta-data",
  "packer/seed/user-data.tpl",
  "versions.tf",
  "providers.tf",
  "variables.tf",
  "main.tf",
  "cloudinit.tf",
  "outputs.tf",
  "terraform.tfvars.example",
  "cloud-init/user-data.yaml.tftpl",
].forEach((file) => {
  assert.ok(fs.existsSync(path.join(root, file)), `${file} should exist`);
});

const variables = read("variables.tf");
const versions = read("versions.tf");
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

const packerWorkflow = read(".github/workflows/packer.yml");
assert.match(packerWorkflow, /hashicorp\/setup-packer/);
assert.match(packerWorkflow, /packer init packer\/devops-sandbox\.pkr\.hcl/);
assert.match(packerWorkflow, /packer validate[\s\S]*packer\/devops-sandbox\.pkr\.hcl/);

const packerTemplate = read("packer/devops-sandbox.pkr.hcl");
assert.match(packerTemplate, /source "qemu" "devops_sandbox"/);
assert.match(packerTemplate, /accelerator\s+= "kvm"/);
assert.match(packerTemplate, /headless\s+= true/);
assert.match(packerTemplate, /cpus\s+= 6/);
assert.match(packerTemplate, /memory\s+= 6144/);
assert.match(packerTemplate, /disk_size\s+= "12G"/);
assert.match(packerTemplate, /iso_checksum\s+= "none"/);
assert.match(packerTemplate, /cd_files\s+= \[[\s\S]*seed\/meta-data[\s\S]*seed\/user-data/);
assert.match(packerTemplate, /cloud-init status --wait/);
assert.match(packerTemplate, /ubuntu-desktop-minimal[\s\S]*spice-vdagent[\s\S]*firefox/);
assert.match(packerTemplate, /AutomaticLogin=dev/);
assert.match(packerTemplate, /useradd[\s\S]*dev/);
assert.match(packerTemplate, /\/tmp\/install-scripts/);
for (const tool of expectedTools) {
  assert.match(packerTemplate, new RegExp(`"${tool}"`), `packer tools default should include ${tool}`);
}
assert.match(packerTemplate, /install-\$\{tool\}\.sh/);
assert.match(packerTemplate, /SOURCE_CLOUD_IMAGE_URL/);
assert.match(packerTemplate, /SOURCE_CLOUD_IMAGE_SHA256/);
assert.match(packerTemplate, /BUILD_TIMESTAMP_RFC3339/);
assert.match(packerTemplate, /GIT_SHORT_SHA/);
assert.match(packerTemplate, /qemu-img convert -c -O qcow2/);
assert.match(packerTemplate, /devops-sandbox-base\.qcow2/);

const packerBuildPath = path.join(root, "packer", "build.sh");
const packerBuildMode = fs.statSync(packerBuildPath).mode;
assert.equal(packerBuildMode & 0o111, 0o111, "packer/build.sh should be executable");
const packerBuild = fs.readFileSync(packerBuildPath, "utf8");
assert.match(packerBuild, /ssh-keygen -q -t ed25519/);
assert.match(packerBuild, /trap cleanup EXIT/);
assert.match(packerBuild, /rm -rf "\$build_dir"/);
assert.match(packerBuild, /@SSH_PUBKEY@/);
assert.match(packerBuild, /packer build/);
assert.match(packerBuild, /ssh_private_key_file=\$build_dir\/builder_id/);
assert.match(packerBuild, /devops-sandbox-base\.qcow2/);

const packerMetaData = read("packer/seed/meta-data");
assert.match(packerMetaData, /instance-id: builder/);
assert.match(packerMetaData, /local-hostname: builder-vm/);

const packerSeedTemplate = read("packer/seed/user-data.tpl");
assert.match(packerSeedTemplate, /name: builder/);
assert.match(packerSeedTemplate, /@SSH_PUBKEY@/);
assert.match(packerSeedTemplate, /sudo: ALL=\(ALL\) NOPASSWD:ALL/);

const packerGitignore = read("packer/.gitignore");
assert.match(packerGitignore, /^output\/$/m);
assert.match(packerGitignore, /^\.build\/$/m);
assert.match(packerGitignore, /^cache\/$/m);

assert.match(variables, /variable "vm_name"[\s\S]*default\s+= "devops-sandbox"/);
assert.match(variables, /variable "vm_vcpus"[\s\S]*default\s+= 6/);
assert.match(variables, /variable "vm_memory_mib"[\s\S]*default\s+= 8192/);
assert.match(variables, /variable "vm_disk_gb"[\s\S]*default\s+= 20/);
assert.match(variables, /variable "username"[\s\S]*default\s+= "dev"/);
assert.match(variables, /variable "ubuntu_image_url"[\s\S]*noble-server-cloudimg-amd64\.img/);
const toolsDefaultMatch = variables.match(/variable "tools"[\s\S]*?default\s+= \[([\s\S]*?)\]/);
assert.ok(toolsDefaultMatch, "tools default should be present");
const toolsDefault = [...toolsDefaultMatch[1].matchAll(/"([^"]+)"/g)].map((match) => match[1]);
assert.deepEqual(toolsDefault, expectedTools);
assert.match(variables, /variable "tool_versions"[\s\S]*type\s+= map\(string\)[\s\S]*default\s+= \{\}/);
assert.match(variables, /~\/\.ssh\/id_ed25519\.pub/);
assert.match(variables, /~\/\.ssh\/id_rsa\.pub/);

assert.match(versions, /version\s+= "~> 0\.9\.0"/);

const main = read("main.tf");
assert.match(main, /resource "libvirt_volume" "ubuntu_base"/);
assert.match(main, /create\s+= \{[\s\S]*content\s+= \{[\s\S]*url\s+= var\.ubuntu_image_url/);
assert.match(main, /resource "libvirt_volume" "root"/);
assert.match(main, /backing_store\s+= \{[\s\S]*path\s+= libvirt_volume\.ubuntu_base\.path[\s\S]*format\s+= \{[\s\S]*type\s+= "qcow2"/);
assert.match(main, /capacity\s+= var\.vm_disk_gb \* 1024 \* 1024 \* 1024/);
assert.match(main, /resource "libvirt_volume" "cloudinit_iso"/);
assert.match(main, /url\s+= libvirt_cloudinit_disk\.user_data\.path/);
assert.match(main, /type\s+= "kvm"/);
assert.match(main, /os\s+= \{[\s\S]*type\s+= "hvm"[\s\S]*arch\s+= "x86_64"[\s\S]*machine\s+= "q35"/);
assert.match(main, /devices\s+= \{/);
assert.match(main, /disks\s+= \[/);
assert.match(main, /volume\s+= libvirt_volume\.root\.name/);
assert.match(main, /volume\s+= libvirt_volume\.cloudinit_iso\.name/);
assert.match(main, /interfaces\s+= \[[\s\S]*network\s+= "default"[\s\S]*wait_for_ip\s+= \{/);
assert.match(main, /graphics\s+= \[[\s\S]*spice\s+= \{/);
assert.match(main, /videos\s+= \[[\s\S]*type\s+= "qxl"/);
assert.match(main, /consoles\s+= \[[\s\S]*type\s+= "pty"/);
assert.match(main, /channels\s+= \[[\s\S]*spice_vmc\s+= true[\s\S]*virt_io\s+= \{[\s\S]*name\s+= "com\.redhat\.spice\.0"/);
assert.match(main, /data "libvirt_domain_interface_addresses" "vm"/);
assert.match(main, /cloud-init status --wait/);
assert.doesNotMatch(main, /disk\s+\{/);
assert.doesNotMatch(main, /network_interface\s+\{/);

const cloudinit = read("cloudinit.tf");
assert.match(cloudinit, /resource "terraform_data" "ssh_pubkey_check"/);
assert.match(cloudinit, /No SSH public key was found/);
assert.match(cloudinit, /resource "libvirt_cloudinit_disk" "user_data"/);
assert.match(cloudinit, /meta_data\s+= yamlencode/);
assert.match(cloudinit, /install_scripts\s+= local\.install_scripts/);
assert.match(cloudinit, /tool_versions\s+= var\.tool_versions/);

const outputs = read("outputs.tf");
assert.match(outputs, /output "vm_ip"/);
assert.match(outputs, /output "ssh_command"/);
assert.match(outputs, /ssh \$\{var\.username\}@/);
assert.match(outputs, /output "virt_viewer_command"/);
assert.match(outputs, /virt-viewer --connect qemu:\/\/\/system \$\{var\.vm_name\}/);

const userData = read("cloud-init/user-data.yaml.tftpl");
assert.match(userData, /name: \$\{username\}/);
assert.match(userData, /sudo: ALL=\(ALL\) NOPASSWD:ALL/);
assert.match(userData, /ssh_authorized_keys:/);
assert.match(userData, /packages:\s+[\s\S]*ubuntu-desktop-minimal[\s\S]*spice-vdagent[\s\S]*firefox/);
assert.match(userData, /\/etc\/gdm3\/custom\.conf/);
assert.match(userData, /AutomaticLoginEnable=true/);
assert.match(userData, /AutomaticLogin=\$\{username\}/);
assert.match(userData, /\/usr\/local\/sbin\/install-\$\{tool\}\.sh/);
assert.match(userData, /TOOL_VERSION=\$\{lookup\(tool_versions, tool, ""\)\}/);

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
  assert.ok(
    !fs.existsSync(path.join(root, "terraform", "scripts", `install-${tool}.sh`)),
    `terraform/scripts/install-${tool}.sh should not exist`,
  );

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
assert.match(readme, /virt-viewer/);
assert.match(readme, /GNOME/);
assert.match(readme, /autologin/);
assert.match(readme, /ubuntu-desktop-minimal/);
assert.doesNotMatch(readme, /headless Ubuntu Server VM/);
assert.match(readme, /scripts\/install-<name>\.sh/);
assert.match(readme, /tools/);
assert.match(readme, /docker run/);

const tfvarsExample = read("terraform.tfvars.example");
for (const tool of expectedTools) {
  assert.match(tfvarsExample, new RegExp(`"${tool}"`), `terraform.tfvars.example should list ${tool}`);
}
assert.match(tfvarsExample, /tool_versions\s+= \{/);

const gitignore = read(".gitignore");
assert.match(gitignore, /^terraform\.tfvars$/m);
assert.match(gitignore, /^\*\.tfstate$/m);
assert.match(gitignore, /^\*\.tfstate\.\*$/m);
assert.match(gitignore, /^\.terraform\/\*\*$/m);

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
