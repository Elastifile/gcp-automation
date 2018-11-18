#!/bin/bash
# destoy_enodes.sh, Andrew Renz, Aug 2018
# bash script to query and delete multiple ECFS GCE resources

# set -x

ENODE_NAME="$1-elfs"
ZONE=$2
REGION=${ZONE:0:8}
SESSION_FILE=session.txt
PASSWORD=`cat password.txt | cut -d " " -f 1`
EMS_ADDRESS=`terraform show | grep assigned_nat_ip | cut -d " " -f 5`
PROJECT=$7

function finish {
  gcloud  config set project ${GCLOUD_PROJECT}

}
trap finish EXIT

# Verify provided project exists:
gcloud projects describe ${PROJECT} &>/dev/null
RET_VAL=$?
if [[ ${RET_VAL} -ne 0 ]]; then
    echo "Error: Project '${PROJECT}' doesn't exists."
    exit 1
fi

#get the current gcloud project
GCLOUD_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
gcloud  config set project ${PROJECT}

#delete the enodes
VMLIST=`gcloud compute instances list --project=${PROJECT} --filter="name:$ENODE_NAME AND zone:${ZONE}" | grep ${ENODE_NAME} | cut -d " " -f 1`
for i in ${VMLIST}; do
gcloud compute instances delete ${i} --project=${PROJECT} --zone=${ZONE} --quiet &
done

if [[ $3 == "true" ]]; then
  #Establish https session
  curl -k -D ${SESSION_FILE} -H "Content-Type: application/json" -X POST -d '{"user": {"login":"admin","password":"'${PASSWORD}'"}}' https://${EMS_ADDRESS}/api/sessions 2>&1

  #grab the LB name
  LB_NAME=loadbalancername
  LB_NAME=`curl -k -s -b ${SESSION_FILE} --request GET --url "https://${EMS_ADDRESS}/api/cloud_providers/1" | grep load_balancer_name | cut -d , -f 7 | cut -d \" -f 4`

  #delete the instance group
  gcloud compute instance-groups unmanaged delete "${LB_NAME}-ig" --project=${PROJECT} --zone=${ZONE} --quiet &

  #delete the VPC network
  DEFAULTROUTES=`gcloud compute routes list --project=${PROJECT} | grep ${LB_NAME} | cut -d " " -f 1`
  for i in ${DEFAULTROUTES}; do
  gcloud compute routes delete ${i} --quiet --project=${PROJECT} &
  done
  gcloud compute addresses delete "${LB_NAME}-ip" --region ${REGION} --project=${PROJECT} --quiet
  gcloud compute networks subnets delete "${LB_NAME}-ip-net-sub" --region ${REGION} --project=${PROJECT} --quiet
  gcloud compute networks delete "${LB_NAME}-ip-net" --project=${PROJECT} --quiet
fi

gcloud compute instances delete $1 --zone=${ZONE} --project=${PROJECT} --quiet &

exit 0
# --quiet --no-user-output-enabled