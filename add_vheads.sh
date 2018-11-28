#!/usr/bin/env bash
set -u

# function code from https://gist.github.com/cjus/1047794 by itstayyab
function jsonValue() {
KEY=$1
 awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'${KEY}'\042/){print $(i+1)}}}' | tr -d '"'| tr '\n' ','
}


usage() {
  cat << E_O_F
Usage:
Parameters:
  -n number of enode instances (cluster size): eg 3
  -a use public ip (true=1/false=0)
Examples:
  ./add_vheads.sh -n 2 -a 1
E_O_F
  exit 1
}

#variables
SESSION_FILE=session.txt
PASSWORD=`cat password.txt | cut -d " " -f 1`
SETUP_COMPLETE="false"
NUM_OF_VMS=1
EMS_ADDRESS="127.0.0.1"
WEB=https
LOG="add_vheads.log"
taskid=0

while getopts "h?:n:a:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    n)  NUM_OF_VMS=${OPTARG}
        ;;
    a)  USE_PUBLIC_IP=${OPTARG}
        ;;
    esac
done

#capture computed variables
if [[ ${USE_PUBLIC_IP} -eq 1 ]]; then
  EMS_ADDRESS=`terraform show | grep assigned_nat_ip | cut -d " " -f 5`
else
  EMS_ADDRESS=`terraform show | grep network_ip | cut -d " " -f 5`
fi

#capture computed variables
echo "EMS_ADDRESS: ${EMS_ADDRESS}" | tee ${LOG}
echo "NUM_OF_VMS: ${NUM_OF_VMS}" | tee -a ${LOG}

#establish https session
function establish_session {
echo -e "Establishing https session..\n" | tee -a ${LOG}
curl -k -D ${SESSION_FILE} -H "Content-Type: application/json" -X POST -d '{"user": {"login":"admin","password":"'$1'"}}' https://${EMS_ADDRESS}/api/sessions >> ${LOG} 2>&1
}

# Provision  and deploy
function add_capacity {
  if [[ ${1} == 0 ]]; then
    echo -e "0 VMs configured, skipping create instances\n"
  fi
  create_instances ${1}
  job_status ecs_task
}

# Kickoff a create enode instances job
function create_instances {
  echo -e "Creating ${1} ECFS instances\n" | tee -a ${LOG}
  result=$(curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X POST -d '{"instances":'${1}',"async":true,"auto_start":true}' https://${EMS_ADDRESS}/api/hosts/create_instances)
  echo $result | tee -a ${LOG}
  taskid=$(echo $result | jsonValue id | sed s'/[,]$//')
  echo "taskid: $taskid" | tee -a ${LOG}
}

# Function to check running job status
function job_status {
  while true; do
    STATUS=`curl -k -s -b ${SESSION_FILE} --request GET --url "https://${EMS_ADDRESS}/api/control_tasks/$taskid" | grep status | cut -d , -f 7 | cut -d \" -f 4`
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
establish_session ${PASSWORD}
add_capacity ${NUM_OF_VMS}
