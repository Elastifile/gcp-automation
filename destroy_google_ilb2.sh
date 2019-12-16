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
  -e service email
  -p project
E_O_F
  exit 1
}

#variables
LOG="destroy_google_ilb.log"

while getopts "h?:z:n:s:c:a:e:p:" opt; do
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
    e)  SERVICE_EMAIL=${OPTARG}
        ;;
    p)  PROJECT=${OPTARG}
        ;;
    esac
done

#capture computed variables
EMS_HOSTNAME="${CLUSTER_NAME}.local"
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
    gcloud compute firewall-rules delete $CLUSTER_NAME-allow-health-tcp-check --quiet --account=$SERVICE_EMAIL --project=$PROJECT
    gcloud compute firewall-rules delete $CLUSTER_NAME-allow-health-udp-check --quiet --account=$SERVICE_EMAIL --project=$PROJECT
    gcloud compute firewall-rules delete $CLUSTER_NAME-allow-tcp-internal-lb --quiet --account=$SERVICE_EMAIL --project=$PROJECT
    gcloud compute firewall-rules delete $CLUSTER_NAME-allow-udp-internal-lb --quiet --account=$SERVICE_EMAIL --project=$PROJECT
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    gcloud compute forwarding-rules delete $CLUSTER_NAME-int-lb-tcp-forwarding-rule --region $REGION --quiet --account=$SERVICE_EMAIL --project=$PROJECT
    gcloud compute forwarding-rules delete $CLUSTER_NAME-int-lb-udp-forwarding-rule --region $REGION --quiet --account=$SERVICE_EMAIL --project=$PROJECT
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    for zone in ${AVAILABILITY_ZONES//,/ }; do
      instances=`gcloud compute instances list --filter="zone:($zone)" --account=$SERVICE_EMAIL --project=$PROJECT | grep $CLUSTER_NAME- | awk '{ print $1"," }'`
      instances=`echo $instances| tr -d ' '|sed s'/[,]$//'`
      instance_group="$CLUSTER_NAME-$zone"
      gcloud compute backend-services remove-backend $CLUSTER_NAME-int-tcp-lb --instance-group $instance_group --instance-group-zone $zone --region $REGION --quiet --account=$SERVICE_EMAIL --project=$PROJECT
      gcloud compute backend-services remove-backend $CLUSTER_NAME-int-udp-lb --instance-group $instance_group --instance-group-zone $zone --region $REGION --quiet --account=$SERVICE_EMAIL --project=$PROJECT
      gcloud compute instance-groups unmanaged remove-instances $instance_group --instances ${instances} --zone $zone --quiet --account=$SERVICE_EMAIL --project=$PROJECT
      gcloud compute instance-groups unmanaged delete $instance_group --zone $zone --quiet --account=$SERVICE_EMAIL --project=$PROJECT
    done
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    gcloud compute backend-services delete $CLUSTER_NAME-int-tcp-lb --region $REGION --quiet --account=$SERVICE_EMAIL --project=$PROJECT
    gcloud compute backend-services delete $CLUSTER_NAME-int-udp-lb --region $REGION --quiet --account=$SERVICE_EMAIL --project=$PROJECT
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    gcloud compute health-checks delete $CLUSTER_NAME-tcp-health-check --quiet --account=$SERVICE_EMAIL --project=$PROJECT
}

# Main
  destroy_google_ilb