#cloud-config
repo_update: true
repo_upgrade: all

write_files:
-   encoding: b64
    content: ${config_script_64}
    path: ${config_script_path}
    permissions: '0755'
    owner: root:root

runcmd:
  - bash ${config_script_path}
