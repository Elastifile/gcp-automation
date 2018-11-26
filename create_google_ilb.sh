#!/bin/bash
#create_google_ilb.sh, Guy Rinkevich, Nov 2018
#Script to configure Google Internal Load Balancer in single or multizone

set -ux

usage() {
  cat << E_O_F
Usage:
  -z EMS zone
  -n network
  -s subnet
  -c cluster name
  -a availability zones
E_O_F
  exit 1
}

LOG="create_google_ilb.log"

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

REGION=`echo $ZONE | awk -F- '{print $1"-"$2 }'`

echo "REGION: $REGION" | tee ${LOG}
echo "ZONE: $ZONE" | tee -a ${LOG}
echo "NETWORK: $NETWORK" | tee -a ${LOG}
echo "SUBNETWORK: $SUBNETWORK" | tee -a ${LOG}
echo "CLUSTER_NAME: $CLUSTER_NAME" | tee -a ${LOG}
#set -x

# Configure Google Internal Load Balancer
function create_google_ilb {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "Setting Up Internal Load Balancing"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "Creating health check"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    gcloud compute health-checks create tcp $CLUSTER_NAME-tcp-health-check --port 111
    
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "Creating backend service"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    gcloud compute backend-services create $CLUSTER_NAME-int-lb --load-balancing-scheme internal --session-affinity none --region $REGION --health-checks $CLUSTER_NAME-tcp-health-check --protocol tcp
    
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "Adding int-lb tag to all cluster instances"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    for zone in ${AVAILABILITY_ZONES//,/ }; do 
      instances=`gcloud compute instances list --filter="zone:($zone)" | grep $CLUSTER_NAME- | awk '{ print $1"," }'`
      instances=`echo $instances| tr -d ' '`
      instance_group="$CLUSTER_NAME-$zone"
      gcloud compute instance-groups unmanaged create $instance_group  --zone $zone
      gcloud compute instance-groups unmanaged add-instances $instance_group --instances ${instances::-1} --zone $zone
      gcloud compute backend-services add-backend $CLUSTER_NAME-int-lb --instance-group $instance_group --instance-group-zone $zone --region $REGION
    done
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "Creating a forwarding rule"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    gcloud compute forwarding-rules create $CLUSTER_NAME-int-lb-forwarding-rule --load-balancing-scheme internal --ports 111,2049,644,4040,4045 --network $NETWORK --subnet $SUBNETWORK --region $REGION --backend-service $CLUSTER_NAME-int-lb
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "Configure a firewall rule to allow Internal load balancing"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    gcloud compute firewall-rules create $CLUSTER_NAME-allow-internal-lb --network $NETWORK --source-ranges 10.128.0.0/20 --target-tags elastifile-storage-node --allow tcp
    gcloud compute firewall-rules create $CLUSTER_NAME-allow-health-check --network $NETWORK --source-ranges 130.211.0.0/22,35.191.0.0/16 --target-tags elastifile-storage-node --allow tcp
    echo "Checking load balancer IP:"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    sleep 10
    gcloud compute forwarding-rules describe $CLUSTER_NAME-int-lb-forwarding-rule --region $REGION | grep IPAddress
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "Cluster Members Health Check Status:"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    sleep 15
    gcloud compute backend-services get-health $CLUSTER_NAME-int-lb --region $REGION
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo -n
}

# Main
  create_google_ilb
