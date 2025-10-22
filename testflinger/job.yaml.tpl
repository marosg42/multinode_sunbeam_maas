# -*- mode: yaml -*-
job_queue: openstack
provision_data:
  distro: noble
global_timeout: 21600
output_timeout: 21600
reserve_data:
    ssh_keys:
      - lp:marosg
    timeout: 21600

test_data:
  attachments:
    - local: repository.tar.gz
  test_cmds: |
    set -ex
    scp ./attachments/test/repository.tar.gz "ubuntu@${DEVICE_IP}:"
    if ssh "ubuntu@${DEVICE_IP}" '
        set -ex
        ssh-import-id lp:marosg
        timeout_loop () {
            local TIMEOUT=90
            while [ "$TIMEOUT" -gt 0 ]; do
              if "$@" > /dev/null 2>&1; then
                  echo "OK"
                  return 0
              fi
              TIMEOUT=$((TIMEOUT - 1))
              sleep 1
            done
            echo "ERROR: $* FAILED"
            ret=1
            return 1
        }
        # http://pad.lv/2093303
        sudo mv -v /etc/apt/sources.list{,.bak}
        # Workaround for:
        #   E: Failed to fetch http://...  Hash Sum mismatch
        timeout_loop sudo apt-get update -q

        # include ~/.local/bin in PATH
        source  ~/.profile
        set -o pipefail
        # LP: #2097451
        # LP: #2102175
        tar xzvf repository.tar.gz
        cd repository

        # generate passwordless key if needed
        test -f ~/.ssh/passwordless || ssh-keygen -b 2048 -t rsa -f ~/.ssh/passwordless -q -N ""

        # Allow ssh connections to the virtual nodes without having host fingerprint issues.
        echo "Host 172.16.1.* 172.16.2.*" >> ~/.ssh/config
        echo "    UserKnownHostsFile /dev/null" >> ~/.ssh/config
        echo "    StrictHostKeyChecking no" >> ~/.ssh/config

        # Install depependencies in the hypervisor.
        ./install_deps.sh

        # Prepare the testing bed running terragrunt
        # make the libvirt group effective in this shell, so terraform can talk to the libvirt unix socket
        sudo su - ubuntu -c $(realpath ./deploy.sh)

    '; then
        echo "DONE"
    fi
