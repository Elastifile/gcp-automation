#!/usr/bin/env bash
set -u

#impliment command-line options
#imported from EMS /elastifile/emanage/deployment/cloud/add_hosts_google.sh

# function code from https://gist.github.com/cjus/1047794 by itstayyab
function jsonValue() {
KEY=${1}
 /
 awk -F"[,:}]" '{for(i=1;i<=NF;i++){if(${i}~/'${KEY}'\042/){print $(i+1)}}}' | tr -d '"'| tr '\n' ','
}


usage() {
  cat << E_O_F
Usage:
Parameters:
  -n number of enode instances (cluster size): eg 3
  -a ems address: ems.elastifile.com
Examples:
  ./add_enode.sh -n 2 -a  "35.233.159.121"
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
LOG="add_enodes.log"

while getopts "h?:n:a:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    n)  NUM_OF_VMS=${OPTARG}
        ;;
    a)  EMS_ADDRESS=${OPTARG}
        ;;
    esac
done

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
  job_status "add_instances_job"
}

# Kickoff a create enode instances job
function create_instances {
  echo -e "Creating ${1} ECFS instances\n" | tee -a ${LOG}
  curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X POST -d '{"instances":'${1}',"async":true,"auto_start":true}' https://${EMS_ADDRESS}/api/hosts/create_instances >> ${LOG} 2>&1
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
establish_session ${PASSWORD}
add_capacity ${NUM_OF_VMS}