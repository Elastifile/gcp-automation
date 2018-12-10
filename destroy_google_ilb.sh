#!/bin/bash

set -ux


usage() {
  cat << E_O_F
Usage:
  -z zone
  -n network
  -s subnet
  -c cluster name
  -a availability zones
E_O_F
  exit 1
}

#variables
LOG="destroy_google_ilb.log"

while getopts "h?:z:n:s:c:a:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    z)  ZONE=${OPTARG}
        ;;
    n)  NETWORK=${OPTARG}
        ;;
    s)  SUBNETWORK=${OPTARG}
        ;;
    c)  CLUSTER_NAME=${OPTARG}
        ;;
    a)  AVAILABILITY_ZONES=${OPTARG}
        ;;
    esac
done

#capture computed variables
EMS_NAME=`terraform show | grep reference_name | cut -d " " -f 5`
EMS_HOSTNAME="${EMS_NAME}.local"
#if [[ $USE_PUBLIC_IP -eq 1 ]]; then
#  EMS_ADDRESS=`terraform show | grep assigned_nat_ip | cut -d " " -f 5`
#else
#  EMS_ADDRESS=`terraform show | grep network_ip | cut -d " " -f 5`
#fi
REGION=`echo $ZONE | awk -F- '{print $1"-"$2 }'`

echo "REGION: $REGION" | tee ${LOG}
echo "ZONE: $ZONE" | tee -a ${LOG}
echo "NETWORK: $NETWORK" | tee -a ${LOG}
echo "SUBNETWORK: $SUBNETWORK" | tee -a ${LOG}
echo "CLUSTER_NAME: $CLUSTER_NAME" | tee -a ${LOG}
#set -x

# Destroy Google Internal Load Balancer
function destroy_google_ilb {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    gcloud compute firewall-rules delete $CLUSTER_NAME-allow-health-check --quiet 
    gcloud compute firewall-rules delete $CLUSTER_NAME-allow-internal-lb --quiet
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    gcloud compute forwarding-rules delete $CLUSTER_NAME-int-lb-forwarding-rule --region $REGION --quiet
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    for zone in ${AVAILABILITY_ZONES//,/ }; do
      instances=`gcloud compute instances list --filter="zone:($zone)" | grep $CLUSTER_NAME- | awk '{ print $1"," }'`
      instances=`echo $instances| tr -d ' '|sed s'/[,]$//'`
      instance_group="$CLUSTER_NAME-$zone"
      gcloud compute backend-services remove-backend $CLUSTER_NAME-int-lb --instance-group $instance_group --instance-group-zone $zone --region $REGION --quiet
      gcloud compute instance-groups unmanaged remove-instances $instance_group --instances ${instances} --zone $zone --quiet
      gcloud compute instance-groups unmanaged delete $instance_group --zone $zone --quiet
    done
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    gcloud compute backend-services delete $CLUSTER_NAME-int-lb --region $REGION --quiet
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    gcloud compute health-checks delete $CLUSTER_NAME-tcp-health-check --quiet
}

# Main
  destroy_google_ilb
