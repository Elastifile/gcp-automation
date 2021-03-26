#!/bin/bash
# bash script to query and delete multiple ECFS GCE resources

usage() {
  cat << E_O_F
Usage:
  -c cluster name
  -a availability zones
  -b ems zone
  -p project name
E_O_F
  exit 1
}

# set -x

while getopts "h?:c:a:b:p:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    c)  CLUSTER_NAME=${OPTARG}
        ;;
    a)  AVAILABILITY_ZONES=${OPTARG}
        ;;
    b)  EMS_ZONE=${OPTARG}
        ;;
    p)  PROJECT=${OPTARG}
        ;;
    esac
done

# find the host project
HOSTPROJECT=`gcloud compute instances describe --zone=$EMS_ZONE $CLUSTER_NAME | grep subnetwork | awk -F/ '{print $7}'`

# delete the vheads
# remove ems delete protection
gcloud compute instances update $CLUSTER_NAME --zone=$EMS_ZONE --project $PROJECT --no-deletion-protection --quiet &
sleep 5
VHEAD_NAME="$CLUSTER_NAME-elfs"
RA_NAME="$CLUSTER_NAME-ra"
for zone in ${AVAILABILITY_ZONES//,/ }; do
  VMLIST=`gcloud compute instances list --project $PROJECT --filter="name ~ ${VHEAD_NAME}* AND zone:$zone" | grep $VHEAD_NAME | cut -d " " -f 1`
  RALIST=`gcloud compute instances list --project $PROJECT --filter="name ~ ${RA_NAME}* AND zone:$zone" | grep $RA_NAME | cut -d " " -f 1`
  for i in $VMLIST $RALIST; do
    (gcloud compute instances update $i --project $PROJECT --zone=$zone --no-deletion-protection --quiet; gcloud compute instances delete $i --project $PROJECT --zone=$zone --quiet) &
  done
done

# delete the VPC routes
DEFAULTROUTES=`gcloud compute routes list --project $HOSTPROJECT --filter="name: elfs-route-$CLUSTER_NAME" | cut -d " " -f 1 | awk 'NR>1'| cut -d " " -f 1`
 for i in $DEFAULTROUTES; do
   gcloud compute routes delete --project $HOSTPROJECT $i --quiet
done

exit 0
