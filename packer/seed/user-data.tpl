#cloud-config
users:
  - default
  - name: builder
    groups:
      - adm
      - sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh_authorized_keys:
      - @SSH_PUBKEY@
ssh_pwauth: false
disable_root: true
