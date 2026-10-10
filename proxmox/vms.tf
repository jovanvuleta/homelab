# VMs on pve1, matching what's running. Changing a value here and running
# `tofu apply` reconfigures the real VM.

resource "proxmox_virtual_environment_vm" "homeassistant" {
  node_name = "pve1"
  vm_id     = 100
  name      = "homeassistant"
  tags      = ["community-script"]

  on_boot = true
  started = true
  # Never reboot a VM to apply a change; it takes effect on the next restart.
  reboot_after_update = false
  bios                = "ovmf"
  machine             = "q35"
  scsi_hardware       = "virtio-scsi-pci"
  boot_order          = ["scsi0"]
  tablet_device       = false

  agent {
    enabled = true
  }

  cpu {
    cores = 6
  }

  memory {
    dedicated = 4096 # uses ~1.8 GB; HA OS needs 2 GB minimum
  }

  efi_disk {
    datastore_id = "local-lvm"
    type         = "4m"
  }

  disk {
    interface    = "scsi0"
    datastore_id = "local-lvm"
    size         = 32
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
    mac_address = "02:E0:14:5E:1D:66"
  }

  operating_system {
    type = "l26"
  }

  serial_device {
    device = "socket"
  }

  lifecycle {
    # HTML blurb from the community script that created this VM.
    ignore_changes = [description]
  }
}

locals {
  talos_vms = {
    "talos-cp-1" = {
      vm_id  = 1111
      cores  = 4
      memory = 6144
      mac    = "BC:24:11:10:AC:DE"
    }
    "talos-worker-1" = {
      vm_id  = 1112
      cores  = 8
      memory = 16384
      mac    = "BC:24:11:66:AF:81"
    }
  }
}

resource "proxmox_virtual_environment_vm" "talos" {
  for_each = local.talos_vms

  node_name = "pve1"
  vm_id     = each.value.vm_id
  name      = each.key

  on_boot = true
  started = true
  # Never reboot a VM to apply a change; it takes effect on the next restart.
  reboot_after_update = false
  scsi_hardware       = "virtio-scsi-single"
  boot_order          = ["scsi0", "ide2", "net0"]

  agent {
    enabled = true
    # Agent comes from the siderolabs/qemu-guest-agent extension in the Talos
    # image (schematic ce4c9805…, see README). Short timeout so a plan doesn't
    # stall if a node is mid-reboot.
    timeout = "15s"
  }

  cpu {
    cores   = each.value.cores
    sockets = 1
    type    = "host"
    numa    = false
  }

  memory {
    dedicated = each.value.memory
    floating  = 0 # ballooning off
  }

  disk {
    interface    = "scsi0"
    datastore_id = "local-lvm"
    size         = 64
    iothread     = true
  }

  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
    mac_address = each.value.mac
    firewall    = true
  }

  operating_system {
    type = "l26"
  }
}
