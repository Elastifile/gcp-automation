!/bin/bash
set -ux

usage() {
  cat << E_O_F
Usage:
  -z zone
  -n network
  -s subnet
  -c cluster name
  -a availability zones
  -e account email
  -p project
  -v vip
  -q host_project
E_O_F
  exit 1
}

#variables
LOG="create_google_ilb.log"

while getopts "h?:z:n:s:c:a:e:p:v:q:" opt; do
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
    v)  VIP=${OPTARG}
        ;;
    q)  HOST_PROJECT=${OPTARG}
        ;;
    esac
done

REGION=`echo $ZONE | awk -F- '{print $1"-"$2 }'`

echo "REGION: $REGION" | tee ${LOG}
echo "ZONE: $ZONE" | tee -a ${LOG}
echo "NETWORK: $NETWORK" | tee -a ${LOG}
echo "SUBNETWORK: $SUBNETWORK" | tee -a ${LOG}
echo "CLUSTER_NAME: $CLUSTER_NAME" | tee -a ${LOG}
echo "SERVICE_EMAIL: $SERVICE_EMAIL" | tee -a ${LOG}
echo "PROJECT: $PROJECT" | tee -a ${LOG}
echo "VIP: $VIP" | tee -a ${LOG}
echo "HOST PROJECT: $HOST_PROJECT" | tee -a ${LOG}
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
    echo "Creating backend services"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    gcloud compute backend-services create $CLUSTER_NAME-int-tcp-lb --load-balancing-scheme internal --protocol tcp --region $REGION --health-checks $CLUSTER_NAME-tcp-health-check --session-affinity CLIENT_IP
    gcloud compute backend-services create $CLUSTER_NAME-int-udp-lb --load-balancing-scheme internal --protocol udp --region $REGION --health-checks $CLUSTER_NAME-tcp-health-check
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "Adding int-lb tag to all cluster instances"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    for zone in ${AVAILABILITY_ZONES//,/ }; do
      instances=`gcloud compute instances list --filter="zone:($zone)" --account=$SERVICE_EMAIL --project=$PROJECT | grep $CLUSTER_NAME-elfs | awk '{ print $1"," }'`
      instances=`echo $instances| tr -d ' '|sed s'/[,]$//'`
      instance_group="$CLUSTER_NAME-$zone"
      gcloud compute instance-groups unmanaged create $instance_group  --zone $zone --account=$SERVICE_EMAIL --project=$PROJECT
      gcloud compute instance-groups unmanaged add-instances $instance_group --instances ${instances} --zone $zone --account=$SERVICE_EMAIL --project=$PROJECT
      gcloud compute backend-services add-backend $CLUSTER_NAME-int-tcp-lb --instance-group $instance_group --instance-group-zone $zone --region $REGION --account=$SERVICE_EMAIL --project=$PROJECT
      gcloud compute backend-services add-backend $CLUSTER_NAME-int-udp-lb --instance-group $instance_group --instance-group-zone $zone --region $REGION --account=$SERVICE_EMAIL --project=$PROJECT

    done
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "Creating a forwarding rule"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    if [[ ${VIP} == "auto" ]]; then
        gcloud compute forwarding-rules create $CLUSTER_NAME-int-lb-forwarding-rule --load-balancing-scheme internal --ports 111,2049,644,4040,4045 --network $NETWORK --subnet $SUBNETWORK --region $REGION --backend-service $CLUSTER_NAME-int-lb --account=$SERVICE_EMAIL --project=$PROJECT
    else
        gcloud compute forwarding-rules create $CLUSTER_NAME-int-lb-tcp-forwarding-rule --load-balancing-scheme internal --ports 111,2049,644,4040,4045 --network $NETWORK --subnet $SUBNETWORK --region $REGION --address=$VIP --ip-protocol TCP --backend-service $CLUSTER_NAME-int-tcp-lb --account=$SERVICE_EMAIL --project=$PROJECT
        gcloud compute forwarding-rules create $CLUSTER_NAME-int-lb-udp-forwarding-rule --load-balancing-scheme internal --ports 111,2049,644,4040,4045 --network $NETWORK --subnet $SUBNETWORK --region $REGION --address=$VIP --ip-protocol UDP --backend-service $CLUSTER_NAME-int-udp-lb --account=$SERVICE_EMAIL --project=$PROJECT
    fi
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "Configure a firewall rule to allow Internal load balancing"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    cidr_range=$(gcloud compute networks subnets describe $SUBNETWORK --region $REGION --format="value(ipCidrRange)")
    gcloud compute firewall-rules create $CLUSTER_NAME-allow-tcp-internal-lb --network $NETWORK --source-ranges $cidr_range --target-tags elastifile-storage-node-$CLUSTER_NAME --allow tcp --account=$SERVICE_EMAIL --project=$HOST_PROJECT
    gcloud compute firewall-rules create $CLUSTER_NAME-allow-udp-internal-lb --network $NETWORK --source-ranges $cidr_range --target-tags elastifile-storage-node-$CLUSTER_NAME --allow udp --account=$SERVICE_EMAIL --project=$HOST_PROJECT
    gcloud compute firewall-rules create $CLUSTER_NAME-allow-health-tcp-check --network $NETWORK --source-ranges 130.211.0.0/22,35.191.0.0/16 --target-tags elastifile-storage-node-$CLUSTER_NAME --allow tcp --account=$SERVICE_EMAIL --project=$HOST_PROJECT
    gcloud compute firewall-rules create $CLUSTER_NAME-allow-health-udp-check --network $NETWORK --source-ranges 130.211.0.0/22,35.191.0.0/16 --target-tags elastifile-storage-node-$CLUSTER_NAME --allow udp --account=$SERVICE_EMAIL --project=$HOST_PROJECT
    echo "Checking load balancer IP:"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    sleep 10
    gcloud compute forwarding-rules describe $CLUSTER_NAME-int-lb-tcp-forwarding-rule --region $REGION --account=$SERVICE_EMAIL --project=$PROJECT | grep IPAddress
    gcloud compute forwarding-rules describe $CLUSTER_NAME-int-lb-udp-forwarding-rule --region $REGION --account=$SERVICE_EMAIL --project=$PROJECT | grep IPAddress
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "Cluster Members Health Check Status:"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    sleep 15
    gcloud compute backend-services get-health $CLUSTER_NAME-int-tcp-lb --region $REGION --account=$SERVICE_EMAIL --project=$PROJECT
    gcloud compute backend-services get-health $CLUSTER_NAME-int-udp-lb --region $REGION --account=$SERVICE_EMAIL --project=$PROJECT
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo -n
}

# Main
  create_google_ilb
