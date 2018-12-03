#!/bin/bash
#create vheads.sh, Andrew Renz, Sept 2017, June 2018
#Script to configure Elastifile EManage (EMS) Server, and deploy cluster of ECFS virtual controllers (vheads) in Google Compute Platform (GCE)
#Requires terraform to determine EMS address and name (Set EMS_ADDRESS and EMS_NAME to use standalone)

set -ux

#impliment command-line options
#imported from EMS /elastifile/emanage/deployment/cloud/add_hosts_google.sh

# function code from https://gist.github.com/cjus/1047794 by itstayyab
function jsonValue() {
KEY=$1
 awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'$KEY'\042/){print $(i+1)}}}' | tr -d '"'| tr '\n' ','
}


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
#LOGIN=admin
SESSION_FILE=session.txt
PASSWORD=`cat password.txt | cut -d " " -f 1`
SETUP_COMPLETE="false"
DISKTYPE=local
NUM_OF_VMS=3
NUM_OF_DISKS=1
WEB=https
LOG="create_google_ilb.log"
#LOG=/dev/null
#DISK_SIZE=

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
