#!/usr/bin/env bash
set -ux

#impliment command-line options
#imported from EMS /elastifile/emanage/deployment/cloud/add_hosts_google.sh

# function code from https://gist.github.com/cjus/1047794 by itstayyab
function jsonValue() {
KEY=$1
 /
 awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'$KEY'\042/){print $(i+1)}}}' | tr -d '"'| tr '\n' ','
}


usage() {
  cat << E_O_F
Usage:
  -n number of vhead instances (cluster size): eg 3
E_O_F
  exit 1
}

#variables
SESSION_FILE=session.txt
PASSWORD=`cat password.txt | cut -d " " -f 1`
SETUP_COMPLETE="false"
NUM_OF_VMS=3
WEB=https
LOG="create_vheads.log"

while getopts "h?:n:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    n)  NUM_OF_VMS=${OPTARG}
        [[ ${NUM_OF_VMS} -eq ${NUM_OF_VMS} ]] || usage
        ;;
    esac
done

#capture computed variables
EMS_NAME=`terraform show | grep reference_name | cut -d " " -f 5`
EMS_HOSTNAME="${EMS_NAME}.local"
if [[ ${USE_PUBLIC_IP} -eq 1 ]]; then
  EMS_ADDRESS=`terraform show | grep assigned_nat_ip | cut -d " " -f 5`
else
  EMS_ADDRESS=`terraform show | grep network_ip | cut -d " " -f 5`
fi

echo "EMS_ADDRESS: ${EMS_ADDRESS}" | tee ${LOG}
echo "EMS_NAME: ${EMS_NAME}" | tee -a ${LOG}
echo "EMS_HOSTNAME: ${EMS_HOSTNAME}" | tee -a ${LOG}
echo "NUM_OF_VMS: ${NUM_OF_VMS}" | tee -a ${LOG}

# Provision  and deploy
function add_capacity {
  if [[ ${NUM_OF_VMS} == 0 ]]; then
    echo -e "0 VMs configured, skipping create instances\n"
  else
    create_instances ${NUM_OF_VMS}
    job_status "create_instances_job"
    echo "Start cluster deployment\n" | tee -a ${LOG}
    job_status "activate_emanage_job"
  fi
}

# Kickoff a create vhead instances job
function create_instances {
  echo -e "Creating ${NUM_OF_VMS} ECFS instances\n" | tee -a ${LOG}
  curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X POST -d '{"instances":'$1',"async":true,"auto_start":true}' https://${EMS_ADDRESS}/api/hosts/create_instances >> ${LOG} 2>&1
}


# Function to check running job status
function job_status {
  while true; do
    STATUS=`curl -k -s -b ${SESSION_FILE} --request GET --url "https://${EMS_ADDRESS}/api/control_tasks/recent?task_type=$1" | grep status | cut -d , -f 7 | cut -d \" -f 4`
    echo -e  "$1 : ${STATUS} " | tee -a ${LOG}
    if [[ ${STATUS} == "success" ]]; then
      echo -e "$1 Complete! \n" | tee -a ${LOG}
      sleep 5
      break
    fi
    if [[ ${STATUS} == "error" ]]; then
      echo -e "$1 Failed. Exiting..\n" | tee -a ${LOG}
      exit 1
    fi
    sleep 10
  done
}

#MAIN
add_capacity
