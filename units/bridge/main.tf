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
  uri = var.libvirt_uri
}

# Enable IP forwarding
resource "null_resource" "enable_ip_forwarding" {
  provisioner "local-exec" {
    command = "sudo sysctl -w net.ipv4.ip_forward=1"
  }
}

# Create main bridge network for libvirt
# This will create the bridge interface and configure it properly
resource "libvirt_network" "main_bridge" {
  name      = var.bridge_name
  mode      = "bridge"
  bridge    = var.bridge_name
  autostart = true
  
  # Don't use DHCP - MAAS will handle that
  dhcp {
    enabled = false
  }

  # Configure the bridge IP
  addresses = [var.bridge_base_network]
}

# Create VLAN bridge networks
resource "libvirt_network" "vlan_bridges" {
  for_each = var.vlan_networks

  name      = "vlan${each.value.vlan_id}br"
  mode      = "bridge" 
  bridge    = "vlan${each.value.vlan_id}br"
  autostart = true
  
  # Don't use DHCP - MAAS will handle that
  dhcp {
    enabled = false
  }

  # Configure the VLAN bridge IP
  addresses = [each.value.cidr]
}

# Create VLAN interfaces using null_resource as libvirt doesn't support VLAN interfaces directly
resource "null_resource" "vlan_interfaces" {
  for_each = var.vlan_networks

  depends_on = [libvirt_network.main_bridge, libvirt_network.vlan_bridges]

  # Create and configure VLAN interface and attach to bridge
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      # Create VLAN interface if it doesn't exist
      if ! sudo ip link show ${var.bridge_name}.${each.value.vlan_id} >/dev/null 2>&1; then
        sudo ip link add link ${var.bridge_name} name ${var.bridge_name}.${each.value.vlan_id} type vlan id ${each.value.vlan_id}
      fi
      # Bring VLAN interface up
      sudo ip link set ${var.bridge_name}.${each.value.vlan_id} up
      # Attach VLAN interface to its bridge
      sudo ip link set ${var.bridge_name}.${each.value.vlan_id} master vlan${each.value.vlan_id}br
    EOT
  }
}

# Setup NAT for bridge base network
resource "null_resource" "nat_bridge" {
  depends_on = [libvirt_network.main_bridge]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      # Extract network from CIDR
      NETWORK=$(echo ${var.bridge_base_network} | cut -d'/' -f1 | sed 's/\.[0-9]*$/\.0/')
      PREFIX=$(echo ${var.bridge_base_network} | cut -d'/' -f2)
      # Setup NAT masquerading if not already present
      if ! sudo iptables -t nat -C POSTROUTING -s $NETWORK/$PREFIX ! -d $NETWORK/$PREFIX -j MASQUERADE -m comment --comment 'terraform-nat-bridge' 2>/dev/null; then
        sudo iptables -t nat -A POSTROUTING -s $NETWORK/$PREFIX ! -d $NETWORK/$PREFIX -j MASQUERADE -m comment --comment 'terraform-nat-bridge'
      fi
    EOT
  }
}

# Setup NAT for each VLAN network
resource "null_resource" "nat_vlans" {
  for_each = var.vlan_networks

  depends_on = [libvirt_network.vlan_bridges]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      # Extract network from CIDR
      NETWORK=$(echo ${each.value.cidr} | cut -d'/' -f1 | sed 's/\.[0-9]*$/\.0/')
      PREFIX=$(echo ${each.value.cidr} | cut -d'/' -f2)
      # Setup NAT masquerading if not already present
      if ! sudo iptables -t nat -C POSTROUTING -s $NETWORK/$PREFIX ! -d $NETWORK/$PREFIX -j MASQUERADE -m comment --comment 'terraform-nat-vlan${each.value.vlan_id}' 2>/dev/null; then
        sudo iptables -t nat -A POSTROUTING -s $NETWORK/$PREFIX ! -d $NETWORK/$PREFIX -j MASQUERADE -m comment --comment 'terraform-nat-vlan${each.value.vlan_id}'
      fi
    EOT
  }
}
