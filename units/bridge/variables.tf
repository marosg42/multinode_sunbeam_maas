variable "bridge_name" {
  description = "Name of the bridge interface"
  type        = string
  default     = "maasbr0"
}

variable "bridge_base_network" {
  description = "Base network CIDR for the bridge"
  type        = string
  default     = "172.16.0.1/24"
}

variable "vlan_networks" {
  description = "Map of VLAN ID to network CIDR"
  type = map(object({
    vlan_id = number
    cidr    = string
  }))
  default = {
    "vlan101" = {
      vlan_id = 101
      cidr    = "172.16.1.1/24"
    }
    "vlan102" = {
      vlan_id = 102
      cidr    = "172.16.2.1/24"
    }
    "vlan103" = {
      vlan_id = 103
      cidr    = "172.16.3.1/24"
    }
  }
}
