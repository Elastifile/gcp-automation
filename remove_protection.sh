#!/bin/bash
# bash script to remove delete protection

usage() {
  cat << E_O_F
Usage:
  -c cluster name
  -a availability zones
  -b ems zone

E_O_F
  exit 1
}

# set -x

while getopts "h?:c:a:b:" opt; do
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
    esac
done

# remove ems delete protection
gcloud compute instances update $CLUSTER_NAME --zone=$EMS_ZONE --no-deletion-protection --quiet &
sleep 5
VHEAD_NAME="$CLUSTER_NAME-elfs"
RA_NAME="$CLUSTER_NAME-ra"
for zone in ${AVAILABILITY_ZONES//,/ }; do
  VMLIST=`gcloud compute instances list --filter="name:$VHEAD_NAME AND ZONE:$zone" | grep $VHEAD_NAME | cut -d " " -f 1`
  RALIST=`gcloud compute instances list --filter="name:$RA_NAME AND ZONE:$zone" | grep $RA_NAME | cut -d " " -f 1`
    for i in $VMLIST; do
      # remove vhead delete protection
      gcloud compute instances update $i --zone=$zone --no-deletion-protection --quiet &
    done
    for i in $RALIST; do
      # remove ra delete protection
      gcloud compute instances update $i --zone=$zone --no-deletion-protection --quiet &
    done
done
