#!/bin/bash
# bash script to query and delete multiple ECFS GCE resources

# set -x
EMS_NAME=`terraform show | grep metadata.reference_name | cut -d " " -f 5`
VHEAD_NAME="$EMS_NAME-elfs"
ZONE=`terraform show | grep "zone ="| cut -d " " -f 5`
REGION=${ZONE:0:11}
#CLUSTER_NAME="elastifile-guyr"

#delete the vheads
VMLIST=`gcloud compute instances list --filter="name:$VHEAD_NAME AND zone:$ZONE" | grep $VHEAD_NAME | cut -d " " -f 1`
for i in $VMLIST; do
  gcloud compute instances delete $i --zone=$ZONE --quiet &
done

#delete the VPC load balancing routes
DEFAULTROUTES=`gcloud compute routes list | grep $EMS_NAME | cut -d " " -f 1`
for i in $DEFAULTROUTES; do
  gcloud compute routes delete $i --quiet &
done

exit 0
# --quiet --no-user-output-enabled
