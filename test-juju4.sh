#!/bin/bash -eux

export COLUMNS=256


TEST_JUJU_CHANNEL=${TEST_JUJU_CHANNEL:-3.6}

if [[ -z "$TEST_MAAS_API_KEY" ]];then
    echo "Error: Please define the TEST_MAAS_API_KEY environment variable" >&1
    exit 1
fi

if [[ -z "$TEST_MAAS_URL" ]];then
    echo "Error: Please define the TEST_MAAS_URL environment variable" >&1
    exit 1
fi

if [[ ! -f "$HOME/.ssh/passwordless" ]]; then
    ssh-keygen -b 2048 -t rsa -f $HOME/.ssh/passwordless -q -N ""
fi

function run_snap_daemon {
    sg snap_daemon -c "$*"
}

sudo snap install --channel ${TEST_JUJU_CHANNEL} juju
cat <<EOF > mycloud.yaml
clouds:
    maas_cloud:
        type: maas
        auth-types: [oauth1]
        endpoint: ${TEST_MAAS_URL}
        regions:
            default:
                endpoint: ${TEST_MAAS_URL}
EOF

cat <<EOF > credentials.yaml
credentials:
    maas_cloud:
        maas_cloud_credentials:
            auth-type: oauth1
            maas-oauth: ${TEST_MAAS_API_KEY}
EOF

cat <<EOF > model_defaults.yaml
cloudinit-userdata: "write_files:\n  - content: |\n      kernel.keys.maxkeys = 2000\n\
    \    owner: \"root:root\"\n    path: /etc/sysctl.d/10-maxkeys.conf\n    permissions:\
    \ \"0644\"\npostruncmd:\n  - sysctl --system\n"
juju-no-proxy: 10.0.0.0/8,192.168.0.0/16,172.16.0.0/12,127.0.0.1,localhost
logging-config: <root>=DEBUG
EOF


juju add-cloud maas_cloud mycloud.yaml --client
juju add-credential maas_cloud -f credentials.yaml --client
juju bootstrap --bootstrap-constraints "arch=amd64 tags=juju" --config caas-image-repo=ghcr.io/juju --config bootstrap-timeout=1800 --model-default model_defaults.yaml maas_cloud juju-controller
juju add-model test
juju deploy --force --channel 16/edge  -n 3 postgresql
sleep 60
juju status