#/bin/bash
# destoy_vheads.sh, Andrew Renz, Oct 10 2017
# bash script to query and delete multiple GCE instances simultaneously

#set -x

VHEAD_NAME="$1-elfs"
ZONE=$2

LIST=`gcloud compute instances list --filter="name:$VHEAD_NAME AND zone:$ZONE" | grep $VHEAD_NAME | cut -d " " -f 1`

for i in $LIST; do
gcloud compute instances delete $i --zone=$ZONE --quiet &
done
# --quiet --no-user-output-enabled
