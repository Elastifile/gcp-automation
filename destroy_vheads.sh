#!/bin/bash
# destoy_vheads.sh, Andrew Renz, June 2018
# bash script to query and delete multiple ECFS GCE resources

# set -x

VHEAD_NAME="$1-elfs"
ZONE=$2
REGION=${ZONE:0:8}
SESSION_FILE=session.txt
PASSWORD=`cat password.txt | cut -d " " -f 1`
EMS_ADDRESS=`terraform show | grep assigned_nat_ip | cut -d " " -f 5`

#Establish https session
curl -k -D $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"user": {"login":"admin","password":"'$PASSWORD'"}}' https://$EMS_ADDRESS/api/sessions 2>&1

#grab the LB name
LB_NAME=`curl -k -s -b $SESSION_FILE --request GET --url "https://$EMS_ADDRESS/api/cloud_providers/1" | grep load_balancer_name | cut -d , -f 7 | cut -d \" -f 4`

#delete the vheads
VMLIST=`gcloud compute instances list --filter="name:$VHEAD_NAME AND zone:$ZONE" | grep $VHEAD_NAME | cut -d " " -f 1`
for i in $VMLIST; do
gcloud compute instances delete $i --zone=$ZONE --quiet &
done

#delete the instance group
gcloud compute instance-groups unmanaged delete "$LB_NAME-ig" --zone=$ZONE --quiet &

#delete the VPC network
DEFAULTROUTES=`gcloud compute routes list | grep $LB_NAME | cut -d " " -f 1`
for i in $DEFAULTROUTES; do
gcloud compute routes delete $i --quiet &
done
gcloud compute addresses delete "$LB_NAME-ip" --region $REGION --quiet
gcloud compute networks subnets delete "$LB_NAME-ip-net-sub" --region $REGION --quiet
gcloud compute networks delete "$LB_NAME-ip-net" --quiet

# --quiet --no-user-output-enabled
