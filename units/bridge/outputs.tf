output "bridge_name" {
  description = "Name of the created bridge"
  value       = var.bridge_name
}

output "bridge_network" {
  description = "Bridge base network"
  value       = var.bridge_base_network
}

output "vlan_networks" {
  description = "Configured VLAN networks"
  value = {
    for k, v in var.vlan_networks : k => {
      interface    = "${var.bridge_name}.${v.vlan_id}"
      bridge       = "vlan${v.vlan_id}br"
      vlan_id      = v.vlan_id
      network      = v.cidr
    }
  }
}

output "verification_commands" {
  description = "Commands to verify the configuration locally"
  value = <<-EOT
    Run these commands to verify the configuration:

    # Show all interfaces
    ip -br a

    # Show bridge details
    ip link show type bridge
    brctl show

    # Show VLAN interfaces
    ip -d link show type vlan

    # Show NAT rules
    sudo iptables -t nat -L POSTROUTING -n -v --line-numbers

    # Check IP forwarding
    sysctl net.ipv4.ip_forward

    # Show libvirt networks
    virsh net-list --all
    virsh net-info ${var.bridge_name}-net
  EOT
}
