output "bridge_name" {
  description = "Name of the created bridge"
  value       = var.bridge_name
}

output "bridge_network" {
  description = "Bridge base network"
  value       = var.bridge_base_network
}

output "libvirt_network_main" {
  description = "Main libvirt network resource"
  value       = libvirt_network.main_bridge.name
}

output "libvirt_networks_vlan" {
  description = "VLAN libvirt network resources"
  value = {
    for k, v in libvirt_network.vlan_bridges : k => v.name
  }
}

output "vlan_networks" {
  description = "Configured VLAN networks"
  value = {
    for k, v in var.vlan_networks : k => {
      interface      = "${var.bridge_name}.${v.vlan_id}"
      bridge         = "vlan${v.vlan_id}br"
      libvirt_network = libvirt_network.vlan_bridges[k].name
      vlan_id        = v.vlan_id
      network        = v.cidr
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
    virsh net-info ${var.bridge_name}
    ${join("\n    ", [for k, v in var.vlan_networks : "virsh net-info vlan${v.vlan_id}br"])}
  EOT
}

output "cleanup_commands" {
  description = "Commands to manually clean up VLAN interfaces if needed"
  value = <<-EOT
    If you need to manually clean up VLAN interfaces, run:

    ${join("\n    ", [for k, v in var.vlan_networks : "sudo ip link delete ${var.bridge_name}.${v.vlan_id} 2>/dev/null || true"])}
  EOT
}
