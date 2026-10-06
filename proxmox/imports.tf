# Adopt the VMs that already exist instead of creating new ones.
# Import ID format: <node>/<vm_id>. Safe to delete after the first apply.

import {
  to = proxmox_virtual_environment_vm.homeassistant
  id = "pve1/100"
}

import {
  to = proxmox_virtual_environment_vm.talos["talos-cp-1"]
  id = "pve1/1111"
}

import {
  to = proxmox_virtual_environment_vm.talos["talos-worker-1"]
  id = "pve1/1112"
}
