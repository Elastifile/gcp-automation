#!/bin/bash

set -ux

#impliment command-line options
usage() {
  cat << E_O_F
Usage:
  -a list of node ips
  -e service email
  -p project
  -r cluster name
  example: update_google_ilb.sh -a 10.0.0.1,10.0.0.2 -e <service account> -p <project id>
E_O_F
  exit 1
}

#variables
LOG="update_google_ilb.log"
while getopts "h?:a:e:p:r:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    a)  IPS=${OPTARG}
        ;;
    e)  SERVICE_EMAIL=${OPTARG}
        ;;
    p)  PROJECT=${OPTARG}
        ;;
    r)  CLUSTER_NAME=${OPTARG}
        ;;
    esac
done

echo "CLUSTER_NAME: $CLUSTER_NAME" | tee -a ${LOG}
echo "IPS: $IPS" | tee -a ${LOG}

# Configure Google Internal Load Balancer
function update_google_ilb {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "Updating Load Balancer Instance Group"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    for ip in ${IPS//,/ }; do 
      instance_name=`gcloud compute instances list --filter="($ip)" --account=$SERVICE_EMAIL --project=$PROJECT | grep -v NAME | awk '{ print $1 }'`
      instance_zone=`gcloud compute instances list --filter="($ip)" --account=$SERVICE_EMAIL --project=$PROJECT | grep -v NAME | awk '{ print $2 }'`
      instance_group="$CLUSTER_NAME-$instance_zone"
      gcloud compute instance-groups unmanaged add-instances $instance_group --instances $instance_name --zone $instance_zone --account=$SERVICE_EMAIL --project=$PROJECT
      echo "$instance_name $instance_zone $instance_group"
    done
}

# Main
  update_google_ilb
