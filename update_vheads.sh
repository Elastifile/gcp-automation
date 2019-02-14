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
  -a IP address
  -l lb type
  -e service email
  -p project
Examples:
  ./update_vheads.sh -n 2 -a 1 -l elastifile -e <service-account> -p <project id>
E_O_F
  exit 1
}

#variables
SESSION_FILE=session.txt
PASSWORD=`cat password.txt | cut -d " " -f 1`
LOG="update_vheads.log"

while getopts "h?:n:a:l:e:p:ir:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    n)  NUM_OF_VMS=${OPTARG}
        ;;
    a)  EMS_ADDRESS=${OPTARG}
        ;;
    l)  LB_TYPE=${OPTARG}
        ;;
    e)  SERVICE_EMAIL=${OPTARG}
        ;;
    p)  PROJECT=${OPTARG}
        ;;
    r)  CLUSTER_NAME=${OPTARG}
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

function update_vheads {
  PRE_IPS=$(curl -k -b ./session.txt -H "Content-Type: application/json" https://${EMS_ADDRESS}/api/enodes/ 2> /dev/null | jsonValue external_ip | sed s'/[,]$//')
  PRE_NUM_OF_VMS=$(echo $PRE_IPS | awk -F"," '{print NF}')
  echo "PRE_NUM_OF_VMS: ${PRE_NUM_OF_VMS}" | tee -a ${LOG}
  if [[ ${NUM_OF_VMS} > ${PRE_NUM_OF_VMS} ]]; then
    let NUM=${NUM_OF_VMS}-${PRE_NUM_OF_VMS}
    ./add_vheads.sh -n $NUM -a $EMS_ADDRESS
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
        ./update_google_ilb.sh -a $ADDED_IPS -e $SERVICE_EMAIL -p $PROJECT -r $CLUSTER_NAME
      fi
  else
    let NUM=${PRE_NUM_OF_VMS}-${NUM_OF_VMS}
    ./remove_vheads.sh -n $NUM -a $EMS_ADDRESS
fi
}

#MAIN
establish_session ${PASSWORD}
update_vheads



