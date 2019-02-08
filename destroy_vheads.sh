#!/bin/bash
# bash script to query and delete multiple ECFS GCE resources

usage() {
  cat << E_O_F
Usage:
  -c cluster name
  -a availability zones
E_O_F
  exit 1
}

# set -x

while getopts "h?:c:a:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    c)  CLUSTER_NAME=${OPTARG}
        ;;
    a)  AVAILABILITY_ZONES=${OPTARG}
        ;;
    esac
done

#delete the vheads
VHEAD_NAME="$CLUSTER_NAME-elfs"
RA_NAME="$CLUSTER_NAME-ra"
for zone in ${AVAILABILITY_ZONES//,/ }; do
  VMLIST=`gcloud compute instances list --filter="name:$VHEAD_NAME AND ZONE:$zone" | grep $VHEAD_NAME | cut -d " " -f 1`
  RALIST=`gcloud compute instances list --filter="name:$RA_NAME AND ZONE:$zone" | grep $RA_NAME | cut -d " " -f 1`
    for i in $VMLIST; do
      gcloud compute instances delete $i --zone=$zone --quiet &
    done
    for i in $RALIST; do
      gcloud compute instances delete $i --zone=$zone --quiet &
    done
done


 #delete the VPC network
 DEFAULTROUTES=`gcloud compute routes list | grep $CLUSTER_NAME | cut -d " " -f 1`
 for i in $DEFAULTROUTES; do
   gcloud compute routes delete $i --quiet
done

exit 0
