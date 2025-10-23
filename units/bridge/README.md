# Bridge Network Setup with Terraform

This Terraform configuration creates a Linux bridge with VLAN interfaces and NAT configuration for hosting VMs.

## What It Creates

- **Bridge Interface**: `maasbr0` with IP `172.16.0.1/24`
- **7 VLAN Interfaces** attached to the bridge:
  - maasbr0.101 → 172.16.1.1/24
  - maasbr0.102 → 172.16.2.1/24
  - maasbr0.103 → 172.16.3.1/24
  - maasbr0.2743 → 172.16.10.1/24
  - maasbr0.2744 → 172.16.11.1/24
  - maasbr0.2745 → 172.16.12.1/24
  - maasbr0.2746 → 172.16.13.1/24
- **NAT Configuration**: MASQUERADE rules for all networks (1 for bridge + 7 for VLANs)
- **IP Forwarding**: Enabled (`net.ipv4.ip_forward = 1`)
- **Dummy Interface**: A dummy interface attached to the bridge to keep it in UP state
- **Libvirt Network**: `maasbr0-net` configured in bridge mode to use the `maasbr0` bridge

## Files

- `main-local.tf` - Main Terraform configuration (uses local-exec for running on the server)
- `variables.tf` - Variable definitions
- `terraform.tfvars` - Network configuration
- `outputs.tf` - Outputs and verification commands

## Usage

### On the Remote Server (ubuntu@10.241.21.38)

1. The files are located in `~/terraform-bridge/`

2. To apply the configuration:
   ```bash
   cd ~/terraform-bridge
   terraform apply
   ```

3. To destroy the configuration:
   ```bash
   cd ~/terraform-bridge
   terraform destroy
   ```

### On Your Local Machine

1. Update `terraform.tfvars` if you want different networks or VLAN IDs

2. Copy files to remote server:
   ```bash
   scp *.tf *.tfvars ubuntu@10.241.21.38:~/terraform-bridge/
   ssh ubuntu@10.241.21.38 "cd ~/terraform-bridge && terraform apply"
   ```

## Customization

Edit `terraform.tfvars` to customize:

- Bridge name
- Bridge base network
- VLAN IDs and networks

Example:
```hcl
bridge_name = "mybr0"
bridge_base_network = "172.16.0.1/24"

vlan_networks = {
  "vlan100" = {
    vlan_id = 100
    cidr    = "172.16.1.1/24"
  }
  "vlan200" = {
    vlan_id = 200
    cidr    = "172.16.2.1/24"
  }
}
```

## Verification

After applying, verify the configuration:

```bash
# Show all interfaces
ip -br a

# Show bridge details
brctl show

# Show VLAN interfaces
ip -d link show type vlan

# Show NAT rules
sudo iptables -t nat -L POSTROUTING -n -v --line-numbers

# Check IP forwarding
sysctl net.ipv4.ip_forward

# Show libvirt networks
sudo virsh net-list --all
sudo virsh net-info maasbr0-net
```

## Using the Libvirt Network

To create VMs that use this bridge network, specify the network in your libvirt domain XML or Terraform configuration:

**In virsh/XML:**
```xml
<interface type='network'>
  <source network='maasbr0-net'/>
  <model type='virtio'/>
</interface>
```

**In Terraform with dmacvicar/libvirt provider:**
```hcl
resource "libvirt_domain" "vm" {
  name   = "my-vm"
  memory = "2048"
  vcpu   = 2

  network_interface {
    network_name = "maasbr0-net"
  }

  # ... other configuration
}
```

## Important Notes

- **Not Persistent**: This configuration does NOT survive reboots. You need to reapply after a reboot.
- **Dummy Interface**: The configuration creates a `dummy0` interface to keep the bridge UP even without VMs attached.
- **VMs**: When you attach VMs to the bridge (via libvirt vnet interfaces), they will automatically get connectivity and NAT.
- **Cleanup**: Use `terraform destroy` to clean up all interfaces and NAT rules.

## Example: Successful Verification

```
ubuntu@cuegle:~$ ip -br a | grep maasbr0
maasbr0          UP             172.16.0.1/24
maasbr0.103@maasbr0 UP             172.16.3.1/24
maasbr0.102@maasbr0 UP             172.16.2.1/24
maasbr0.101@maasbr0 UP             172.16.1.1/24
maasbr0.2744@maasbr0 UP             172.16.11.1/24
maasbr0.2743@maasbr0 UP             172.16.10.1/24
maasbr0.2746@maasbr0 UP             172.16.13.1/24
maasbr0.2745@maasbr0 UP             172.16.12.1/24

ubuntu@cuegle:~$ brctl show
bridge name    bridge id        STP enabled    interfaces
maasbr0        8000.0a215f31ad18    no        dummy0

ubuntu@cuegle:~$ sudo iptables -t nat -L POSTROUTING -n -v
Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MASQUERADE  0    --  *      *       172.16.0.0/24       !172.16.0.0/24        /* terraform-nat-bridge */
    0     0 MASQUERADE  0    --  *      *       172.16.10.0/24      !172.16.10.0/24       /* terraform-nat-vlan2743 */
    0     0 MASQUERADE  0    --  *      *       172.16.3.0/24       !172.16.3.0/24        /* terraform-nat-vlan103 */
    0     0 MASQUERADE  0    --  *      *       172.16.12.0/24      !172.16.12.0/24       /* terraform-nat-vlan2745 */
    0     0 MASQUERADE  0    --  *      *       172.16.13.0/24      !172.16.13.0/24       /* terraform-nat-vlan2746 */
    0     0 MASQUERADE  0    --  *      *       172.16.1.0/24       !172.16.1.0/24        /* terraform-nat-vlan101 */
    0     0 MASQUERADE  0    --  *      *       172.16.11.0/24      !172.16.11.0/24       /* terraform-nat-vlan2744 */
    0     0 MASQUERADE  0    --  *      *       172.16.2.0/24       !172.16.2.0/24        /* terraform-nat-vlan102 */
```
