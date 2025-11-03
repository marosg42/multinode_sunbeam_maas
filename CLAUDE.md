# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This project automates the deployment of a multinode OpenStack Sunbeam environment using MAAS (Metal as a Service) for bare-metal provisioning. It uses Terragrunt/OpenTofu to orchestrate infrastructure on libvirt/KVM with custom bridge networking to avoid conflicts with MAAS DHCP.

The infrastructure is designed for testing OpenStack Sunbeam deployments with Testflinger, creating virtual nodes managed by MAAS and configured for Sunbeam cluster deployment.

## Architecture

The deployment is structured as a Terragrunt stack with three dependent units:

1. **bridge** - Creates Linux bridges and VLAN interfaces for networking without libvirt's built-in NAT/DHCP (which conflicts with MAAS)
2. **virtualnodes** - Provisions libvirt VMs including a MAAS controller and compute nodes
3. **maas** - Configures MAAS (networks, spaces, machines, tags) and tags resources for OpenStack deployment

Dependencies flow: `bridge` → `virtualnodes` → `maas`

### Key Design Decisions

- **Custom bridge networking**: Uses Linux bridges (`vlan101br`, `vlan102br`) instead of libvirt networks with mode=nat to avoid DHCP conflicts with MAAS
- **MAAS spaces**: Two spaces defined - `space-generic` (172.16.1.0/24) and `space-external` (172.16.2.0/24)
- **Node tagging**: Machines are tagged for different roles: `juju-controller`, `sunbeam`, `control`, `compute`, `storage`
- **Resource tagging**: Uses null_resource provisioners to tag MAAS block devices (for Ceph) and NICs (for Neutron) since MAAS Terraform provider doesn't fully support this
- **Reserved IP ranges**: Separate ranges for internal API (172.16.1.10-29) and public API (172.16.1.30-49) are configured in MAAS

### Network Layout

- **generic_net** (172.16.1.0/24): Main management/PXE network on vlan101br
  - MAAS controller: 172.16.1.2
  - DHCP range: 172.16.1.200-254
  - Reserved: 172.16.1.1-5
  - Internal API: 172.16.1.10-29
  - Public API: 172.16.1.30-49
- **external_net** (172.16.2.0/24): External network on vlan102br
  - MAAS controller secondary: 172.16.2.2

### VM Configuration

- **MAAS controller**: 8GB RAM, 4 vCPUs, Ubuntu Noble (24.04), dual-NIC
- **Compute nodes**: 6 nodes, 8GB RAM, 4 vCPUs each, PXE boot enabled
  - node-0: juju-controller
  - node-1: sunbeam deployment node
  - node-2: OpenStack control plane
  - node-3,4,5: compute + storage nodes (each with secondary disk for Ceph)

## Development Commands

### Setup and Dependencies

```bash
# Install required tools (terragrunt, tofu/terraform, libvirt)
./install_deps.sh
```

### Deployment

```bash
# Full stack deployment (runs all units in dependency order)
./deploy.sh

# Deploy specific unit
cd units/bridge && terragrunt apply
cd units/virtualnodes && terragrunt apply
cd units/maas && terragrunt apply

# Destroy infrastructure
terragrunt run-all destroy
```

### Local Testflinger Workflow

```bash
# Submit job to local Testflinger
./local-testflinger.sh

# After Testflinger reserves machine, SSH in and run:
./runit.sh  # Installs Sunbeam snap and deploys cluster
```

### MAAS Access

After deployment, MAAS is accessible at:
- URL: http://172.16.1.2:5240/MAAS
- API key: Stored in `~/api.key` (created by virtualnodes unit)
- SSH: `ssh -i ~/.ssh/passwordless ubuntu@172.16.1.2`

### Sunbeam Testing

The `test-multinode-maas.sh` script runs a full Sunbeam deployment test:

```bash
# Set environment variables
export TEST_MAAS_API_KEY="$(cat ~/api.key)"
export TEST_MAAS_URL=http://172.16.1.2:5240/MAAS

# Run test (args: openstack_channel juju_channel)
./test-multinode-maas.sh 2024.1/beta 3/stable
```

### Debugging

```bash
# Check MAAS controller status
ssh -i ~/.ssh/passwordless ubuntu@172.16.1.2
sudo snap services maas

# View libvirt VMs
virsh list --all
virsh console maas-controller

# Check bridge networking
ip addr show vlan101br
ip addr show vlan102br

# Terragrunt debugging
export TERRAGRUNT_LOG_LEVEL=trace
export TF_LOG=TRACE
terragrunt apply

# Collect logs
./collect-logs.sh
```

## Key Files

- `stack.hcl` - Stack-wide configuration (VM sizes, network config, SSH keys)
- `units/*/terragrunt.hcl` - Unit-specific Terragrunt configuration with dependencies
- `units/*/main.tf` - Terraform resources for each unit
- `units/virtualnodes/templates/` - Cloud-init and network config templates for MAAS controller

## Current Known Issues

- `sunbeam cluster deploy` fails with microceph disk detection issues
- Extra fabrics are created in MAAS for second NIC of each node (should only have 2 fabrics total)
- External network may not work correctly
- Several null_resource provisioners should be replaced with proper MAAS provider resources when supported

## Environment Requirements

- SSH key at `~/.ssh/passwordless` (auto-generated if missing)
- Libvirt/KVM access (uses qemu:///system by default)
- User in `libvirt` and `snap_daemon` groups
- Storage path: `~/sunbeam_storage` (created automatically with proper permissions)
