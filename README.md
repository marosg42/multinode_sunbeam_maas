# Multinode Sunbeam MAAS Testing with Testflinger

This is a copy from freyes PR and some modifications. Focus is to run with testflinger using CLI.

## Divergences from freyes PR

- not building snap, using existing snap from store
- only local Tetstflinger deploment
- not using libvirt netwroks because they use mode nat which always starts a DHCP server which conflicts with MAAS DHCP server

## What works

- `./local_testflinger_deploy.sh` deployes a Testflinger machine and runs terragrunt apply
  - MAAS is installed and configured
  - tags for Sunbeam deployment are created and assigned
- testflinger job stays in reserved state showing IP to ssh to
- ssh and running `./runit.sh` will install sunbeam snap and run the deployment

## Known Issues

- currently `sunbeam cluster deploy` fails with microceph complaining it cannot find a disk
- nothing after that was tested yet
- when machines are defined they have second interface in wrong fabric, there is extra fabric created for each (6 useless fabrics which should not be there)
- there is a high chance external network will not work
- there are several more networks defined and they should be used in deployment (internal, ceph etc)

## Things to improve

- there are several null providers used which just run bunch of commands
- assigning tags to disks and NICs in MAAS is prime example of part that should be using MAAS provider properly
- it would be nicer to use libvirt provider to define networks but there was the issue with DHCP servers conflicting
- solve the issue with extra fabrics created for second nic of each node
