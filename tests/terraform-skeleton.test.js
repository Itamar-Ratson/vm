const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");

function read(file) {
  return fs.readFileSync(path.join(root, file), "utf8");
}

[
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
const expectedTools = ["docker", "kind", "helm", "kubectl", "terraform", "git", "gh", "jq", "yq"];
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

const main = read("main.tf");
assert.match(main, /resource "libvirt_volume" "ubuntu_base"/);
assert.match(main, /source\s+= var\.ubuntu_image_url/);
assert.match(main, /resource "libvirt_volume" "root"/);
assert.match(main, /base_volume_id\s+= libvirt_volume\.ubuntu_base\.id/);
assert.match(main, /network_name\s+= "default"/);
assert.match(main, /wait_for_lease\s+= true/);
assert.match(main, /graphics\s+\{[\s\S]*type\s+= "spice"/);
assert.match(main, /video\s+\{[\s\S]*type\s+= "qxl"/);
assert.match(main, /channel\s+\{[\s\S]*type\s+= "spicevmc"[\s\S]*target_type\s+= "virtio"[\s\S]*target_name\s+= "com\.redhat\.spice\.0"/);
assert.match(main, /cloud-init status --wait/);

const cloudinit = read("cloudinit.tf");
assert.match(cloudinit, /resource "terraform_data" "ssh_pubkey_check"/);
assert.match(cloudinit, /No SSH public key was found/);
assert.match(cloudinit, /resource "libvirt_cloudinit_disk" "user_data"/);
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

  const script = fs.readFileSync(scriptPath, "utf8");
  assert.match(script, /set -euo pipefail/, `install-${tool}.sh should fail fast`);
  assert.match(script, /TOOL_VERSION/, `install-${tool}.sh should read TOOL_VERSION`);
  assert.match(script, new RegExp(`\\[install-${tool}\\]`), `install-${tool}.sh should use the logging convention`);
  assert.match(script, /vm-tool-versions\.txt/, `install-${tool}.sh should write the version file`);
  assert.match(script, new RegExp(`${tool}: %s`), `install-${tool}.sh should record a ${tool} line`);
}

const readme = read("README.md");
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
