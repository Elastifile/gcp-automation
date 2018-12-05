#!/bin/bash
# destoy_vheads.sh, Andrew Renz, Aug 2018
# bash script to query and delete multiple ECFS GCE resources

# set -x
EMS_NAME=`terraform show | grep metadata.reference_name | cut -d " " -f 5`
VHEAD_NAME="$EMS_NAME-elfs"
ZONE=`terraform show | grep "zone ="| cut -d " " -f 5`
REGION=${ZONE:0:11}
SESSION_FILE=session.txt
PASSWORD=`cat password.txt | cut -d " " -f 1`
EMS_ADDRESS=`terraform show | grep assigned_nat_ip | cut -d " " -f 5`
#CLUSTER_NAME="elastifile-guyr"
#delete the vheads
VMLIST=`gcloud compute instances list --filter="name:$VHEAD_NAME AND zone:$ZONE" | grep $VHEAD_NAME | cut -d " " -f 1`
for i in $VMLIST; do
  gcloud compute instances delete $i --zone=$ZONE --quiet &
done

#if [[ $3 == "true" ]]; then
  #Establish https session
#  curl -k -D $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"user": {"login":"admin","password":"'$PASSWORD'"}}' https://$EMS_ADDRESS/api/sessions 2>&1

  #grab the LB name
  LB_NAME="$EMS_NAME-int-lb"
  #LB_NAME=`curl -k -s -b $SESSION_FILE --request GET --url "https://$EMS_ADDRESS/api/cloud_providers/1" | grep load_balancer_name | cut -d , -f 7 | cut -d \" -f 4`


  #delete the VPC network
#  DEFAULTROUTES=`gcloud compute routes list | grep $LB_NAME | cut -d " " -f 1`
#  for i in $DEFAULTROUTES; do
#  gcloud compute routes delete $i --quiet &
#  done

exit 0
# --quiet --no-user-output-enabled
