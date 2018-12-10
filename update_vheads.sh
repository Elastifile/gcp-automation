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
  -l lb type
Examples:
  ./update_vheads.sh -n 2 -a 1 -l elastifile
E_O_F
  exit 1
}

#variables
SESSION_FILE=session.txt
PASSWORD=`cat password.txt | cut -d " " -f 1`
LOG="update_vheads.log"

while getopts "h?:n:a:l:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    n)  NUM_OF_VMS=${OPTARG}
        ;;
    a)  USE_PUBLIC_IP=${OPTARG}
        ;;
    l)  LB_TYPE=${OPTARG}
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

function update_vheads {
  PRE_IPS=$(curl -k -b ./session.txt -H "Content-Type: application/json" https://${EMS_ADDRESS}/api/enodes/ 2> /dev/null | jsonValue external_ip | sed s'/[,]$//')
  PRE_NUM_OF_VMS=$(echo $PRE_IPS | awk -F"," '{print NF}')
  echo "PRE_NUM_OF_VMS: ${PRE_NUM_OF_VMS}" | tee -a ${LOG}
  if [[ ${NUM_OF_VMS} > ${PRE_NUM_OF_VMS} ]]; then
    let NUM=${NUM_OF_VMS}-${PRE_NUM_OF_VMS}
    ./add_vheads.sh -n $NUM -a $USE_PUBLIC_IP
     if [[ $LB_TYPE == "google" ]]; then
        POST_IPS=$(curl -k -b ./session.txt -H "Content-Type: application/json" https://${EMS_ADDRESS}/api/enodes/ 2> /dev/null | jsonValue external_ip | sed s'/[,]$//')
        ADDED_IPS=""
        for IP in ${POST_IPS//,/ }; do
          ip_exists=`echo $PRE_IPS | grep $IP`
          if [[ ${ip_exists} == "" ]]; then
            ADDED_IPS=$ADDED_IPS","$IP
          fi
        done
        ADDED_IPS=$(echo $ADDED_IPS | sed s'/[,]//')
        echo "ADDED_IPS: ${ADDED_IPS}" | tee ${LOG}    
        ./update_google_ilb.sh -a $ADDED_IPS
      fi
  else
    let NUM=${PRE_NUM_OF_VMS}-${NUM_OF_VMS}
    ./remove_vheads.sh -n $NUM -a $USE_PUBLIC_IP
fi
}

#MAIN
establish_session ${PASSWORD}
update_vheads



