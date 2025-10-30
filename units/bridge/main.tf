terraform {
  required_version = ">= 1.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.8.3"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Create bridge interface
resource "null_resource" "bridge" {
  # Create and configure bridge
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      # Create bridge if it doesn't exist
      sudo ip link show ${var.bridge_name} >/dev/null 2>&1 || sudo ip link add ${var.bridge_name} type bridge
      # Bring bridge up
      sudo ip link set ${var.bridge_name} up
      # Add IP address to bridge if not already present
      if ! sudo ip addr show ${var.bridge_name} | grep -q "${var.bridge_base_network}"; then
        sudo ip addr add ${var.bridge_base_network} dev ${var.bridge_name}
      fi
      # Enable IP forwarding
      sudo sysctl -w net.ipv4.ip_forward=1
    EOT
  }
}

# Create VLAN bridges
resource "null_resource" "vlan_bridges" {
  for_each = var.vlan_networks

  depends_on = [null_resource.bridge]

  # Create VLAN bridge
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      # Create VLAN bridge if it doesn't exist
      sudo ip link show vlan${each.value.vlan_id}br >/dev/null 2>&1 || sudo ip link add vlan${each.value.vlan_id}br type bridge
      # Bring VLAN bridge up
      sudo ip link set vlan${each.value.vlan_id}br up
    EOT
  }
}

# Create VLAN interfaces
resource "null_resource" "vlan_interfaces" {
  for_each = var.vlan_networks

  depends_on = [null_resource.vlan_bridges]

  # Create and configure VLAN interface and attach to bridge
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      # Create VLAN interface
      sudo ip link show ${var.bridge_name}.${each.value.vlan_id} >/dev/null 2>&1 || sudo ip link add link ${var.bridge_name} name ${var.bridge_name}.${each.value.vlan_id} type vlan id ${each.value.vlan_id}
      # Bring VLAN interface up
      sudo ip link set ${var.bridge_name}.${each.value.vlan_id} up
      # Attach VLAN interface to its bridge
      sudo ip link set ${var.bridge_name}.${each.value.vlan_id} master vlan${each.value.vlan_id}br
      # Add IP address to VLAN bridge if not already present
      if ! sudo ip addr show vlan${each.value.vlan_id}br | grep -q "${each.value.cidr}"; then
        sudo ip addr add ${each.value.cidr} dev vlan${each.value.vlan_id}br
      fi
    EOT
  }
}

# Setup NAT for bridge base network
resource "null_resource" "nat_bridge" {
  depends_on = [null_resource.bridge]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      # Extract network from CIDR
      NETWORK=$(echo ${var.bridge_base_network} | cut -d'/' -f1 | sed 's/\.[0-9]*$/\.0/')
      PREFIX=$(echo ${var.bridge_base_network} | cut -d'/' -f2)
      # Setup NAT masquerading
      sudo iptables -t nat -A POSTROUTING -s $NETWORK/$PREFIX ! -d $NETWORK/$PREFIX -j MASQUERADE -m comment --comment 'terraform-nat-bridge'
    EOT
  }
}

# Setup NAT for each VLAN network
resource "null_resource" "nat_vlans" {
  for_each = var.vlan_networks

  depends_on = [null_resource.vlan_interfaces]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      # Extract network from CIDR
      NETWORK=$(echo ${each.value.cidr} | cut -d'/' -f1 | sed 's/\.[0-9]*$/\.0/')
      PREFIX=$(echo ${each.value.cidr} | cut -d'/' -f2)
      # Setup NAT masquerading
      sudo iptables -t nat -A POSTROUTING -s $NETWORK/$PREFIX ! -d $NETWORK/$PREFIX -j MASQUERADE -m comment --comment 'terraform-nat-vlan${each.value.vlan_id}'
    EOT
  }
}

# Create libvirt network using the bridge
# resource "libvirt_network" "bridge_network" {
#   name      = "${var.bridge_name}-net"
#   mode      = "bridge"
#   bridge    = var.bridge_name
#   autostart = true

#   lifecycle {
#     ignore_changes = [bridge]
#   }
# }
