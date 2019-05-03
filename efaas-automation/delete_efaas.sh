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
  -a efaas end point
  -b project
  -c name
  -p credentials
Examples:
  ./.sh -n 2 -a 1
E_O_F
  exit 1
}

#variables
#SESSION_FILE=session.txt
#PASSWORD=`cat password.txt | cut -d " " -f 1`
SETUP_COMPLETE="false"
#NUM_OF_VMS=1
#EMS_ADDRESS="127.0.0.1"
LOG="destroy_efaas.log"
taskid=0

while getopts "h?:n:a:b:c:p:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    a)  EFAAS_END_POINT=${OPTARG}
        ;;
    b)  PROJECT=${OPTARG}
        ;;
    c)  NAME=${OPTARG}
        ;;
    p)  CREDENTIALS=${OPTARG}
        ;;
    esac
done


# Destroy efaas instance job
function destroy_efaas {
  export ELASTIFILE_APPLICATION_CREDENTIALS="$CREDENTIALS"
  source .env/bin/activate
  token=`python3.6 main.py`
  token=`echo "$token"|xargs`

  echo -e "Destroying eFaas instance\n" | tee -a ${LOG}
  result=$(curl -k -X DELETE "$EFAAS_END_POINT/api/v1/projects/$PROJECT/instances/$NAME" -H "accept: application/json" -H "Content-Type: application/json" -H "$token")
  echo $result | tee -a ${LOG}
  #taskid=$(echo $result | jsonValue id | sed s'/[,]$//')
  #echo "taskid: $taskid" | tee -a ${LOG}
}

# Function to check running job status
#function job_status {
#  while true; do
#    STATUS=`curl -k -s -b ${SESSION_FILE} --request GET --url "https://${EMS_ADDRESS}/api/control_tasks/$taskid" | grep status | cut -d , -f 7 | cut -d \" -f 4`
#    echo -e  "$1 : ${STATUS} " | tee -a ${LOG}
#    if [[ ${STATUS} == "success" ]]; then
#      echo -e "$1 Complete! \n" | tee -a ${LOG}
#      sleep 5
#      break
#    fi
#    if [[ ${STATUS} == "error" ]]; then
#      echo -e "$1 Failed. Exiting..\n" | tee -a ${LOG}
#      exit 1
#    fi
#    sleep 10
#  done
#}

#MAIN
#establish_token ${PASSWORD}
destroy_efaas
#add_capacity ${NUM_OF_VMS}
