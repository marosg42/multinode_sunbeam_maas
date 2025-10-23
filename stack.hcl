locals {
  units = {
    bridge = {
      source = "./bridge"
    }

    virtualnodes = {
      source = "./virtualnodes"
      dependencies = ["bridge"]
    }

    maas = {
      source = "./maas"
      dependencies = ["virtualnodes"]
    }
  }

  # Stack-wide variables
  stack_config = {
    ssh_private_key_path = "~/.ssh/passwordless"
    ssh_public_key_path  = "~/.ssh/passwordless.pub"
    libvirt_uri          = get_env("LIBVIRT_DEFAULT_URI", "qemu:///system")
    maas_hostname        = "maas-controller"

    node_mem             = "8192"      # 4 GB per node
    node_vcpu            = 4           # 4 vCPUs per node
    maas_controller_mem  = "8192"      # 8 GB for MAAS controller
    maas_controller_vcpu = 4

  }
}
