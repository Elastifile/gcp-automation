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
  -d capacity 
  -e credentials
Examples:
  ./.sh -n 2 -a 1
E_O_F
  exit 1
}

#variables
SETUP_COMPLETE="false"
LOG="update_efaas.log"
taskid=0

while getopts "h?:a:b:c:d:e:" opt; do
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
    d)  CAPACITY=${OPTARG}
        ;;
    e)  CREDENTIALS=${OPTARG}
        ;;
    esac
done

# Update the efaas capacity
function update_efaas {
  export ELASTIFILE_APPLICATION_CREDENTIALS="$CREDENTIALS"
  source .env/bin/activate
  token=`python3.6 main.py`
  token=`echo "$token"|xargs`


  echo -e "Updating eFaas instance to $CAPACITY \n" | tee -a ${LOG}

  result=$(curl -k -X POST "$EFAAS_END_POINT/api/v1/projects/$PROJECT/instances/$NAME/setCapacity" -H "accept: application/json" -H "Content-Type: application/json" -d "{\"provisionedCapacityUnits\": $CAPACITY,\"capacityUnitType\": \"Steps\"}" -H "$token")

  service_id=`echo $result| cut -d " " -f 3 | cut -d \" -f 2`
  echo $result | tee -a ${LOG}
  job_status $service_id
}

# Function to check running job status
function job_status {
  export ELASTIFILE_APPLICATION_CREDENTIALS="$CREDENTIALS"
  source .env/bin/activate
  token=`python3.6 main.py`
  token=`echo "$token"|xargs`
  
  while true; do
    STATUS=`curl -k -b -X  -H "accept: application/json" GET "$EFAAS_END_POINT/api/v1/projects/$PROJECT/operation/$1" -H "$token"| grep status| cut -d ":" -f2| awk 'NR==1{print $1}'| cut -d \" -f 2`
    echo -e  "update efaas instance capacity : ${STATUS} " | tee -a ${LOG}
    if [[ ${STATUS} == "DONE" ]]; then
      echo -e "update efaas instance capacity Complete! \n" | tee -a ${LOG}
      sleep 5
      break
    fi
    if [[ ${STATUS} == "ERROR" ]]; then
      echo -e "update efaas instance capacity Failed. Exiting..\n" | tee -a ${LOG}
      exit 1
    fi
    sleep 10
  done
}

#MAIN
update_efaas
