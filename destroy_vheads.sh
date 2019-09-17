#!/bin/bash
# bash script to query and delete multiple ECFS GCE resources

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

#delete the vheads
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
      sleep 5
      gcloud compute instances delete $i --zone=$zone --quiet &
    done
    for i in $RALIST; do
      # remove ra delete protection
      gcloud compute instances update $i --zone=$zone --no-deletion-protection --quiet &
      sleep 5
      gcloud compute instances delete $i --zone=$zone --quiet &
    done
done


 #delete the VPC network
 DEFAULTROUTES=`gcloud compute routes list --filter="name: elfs-route-$CLUSTER_NAME" |cut -d " " -f 1 |awk 'NR>1'| cut -d " " -f 1`
 for i in $DEFAULTROUTES; do
   gcloud compute routes delete $i --quiet
done

exit 0
