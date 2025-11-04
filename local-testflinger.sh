#!/bin/bash -e

# Check if LP/GH ID is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <lp/gh:username>"
    echo "Example: $0 lp:username"
    echo "         $0 gh:username"
    exit 1
fi

SSH_ID="$1"

echo "Using Launchpad/GitHub ID: $SSH_ID"

set -x

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR; echo 'Cleaned up temporary file.'" EXIT
cp -rf . $TMP_DIR/repository
pushd $TMP_DIR
tar --exclude=repository/.tox --exclude=repository/.github/workflows/testflinger/repository.tar.gz --exclude=repository/.git -acf   repository.tar.gz repository/
ls -lh repository.tar.gz
popd
export TESTFLINGER_DIR=$(pwd)/testflinger/
cp $TMP_DIR/repository.tar.gz $TESTFLINGER_DIR
export OPENSTACK_SNAP_PATH=$(ls openstack_*.snap 2>/dev/null || echo "")
export SSH_ID
JOB_FILE=$TESTFLINGER_DIR/job.yaml
envsubst '$OPENSTACK_SNAP_PATH $SSH_ID' \
            < $TESTFLINGER_DIR/job.yaml.tpl \
            > $JOB_FILE

test -f $JOB_FILE
echo "Generated job file contents:"
echo "=========================="
cat $JOB_FILE
echo "=========================="
cd $TESTFLINGER_DIR
testflinger-cli -d submit --poll $JOB_FILE
rm -rf $TMP_DIR
