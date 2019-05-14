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
  -f service class
Examples:
  ./.sh -n 2 -a 1
E_O_F
  exit 1
}

#variables
SETUP_COMPLETE="false"
LOG="update_efaas.log"
taskid=0

while getopts "h?:a:b:c:d:e:f:" opt; do
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
    f)  SERVICE_CLASS=${OPTARG}
        ;;
    esac
done

# Update the efaas capacity
function update_efaas {
  export ELASTIFILE_APPLICATION_CREDENTIALS="$CREDENTIALS"
  source .env/bin/activate
  token=`python3.6 main.py`
  token=`echo "$token"|xargs`
  
  current_capacity=$(curl -k -X GET "$EFAAS_END_POINT/api/v2/projects/$PROJECT/instances/$NAME" -H "accept: application/json" -H "Content-Type: application/json" -H "$token"| grep allocatedCapacity| cut -d ":" -f2| awk 'NR==1{print $1}'| cut -d \" -f 2| tr -d ',')
  echo -e "Current Capacity $current_capacity B \n" | tee -a ${LOG}
  capacity_unit=$(curl -k -b -X GET "$EFAAS_END_POINT/api/v2/projects/$PROJECT/service-class/$SERVICE_CLASS" -H "accept: application/json" -H "$token" |grep unitSize| cut -d ":" -f2| awk 'NR==1{print $1}'| cut -d \" -f 2| tr -d ',')
  tb=$((1024*1024*1024*1024))
  requested_capacity=$(echo - | awk "{print $CAPACITY * $tb}")
  needed_capacity=$(echo - | awk "{print $requested_capacity - $current_capacity}")
  if [[ $needed_capacity -le $capacity_unit ]]; then
        echo -e "The eFaas instance capacity is already as requested, please add more capacity if needed .." | tee -a ${LOG}
        exit
  fi  


  node_capacity=$(echo - | awk "{print $capacity_unit / $tb}")
  echo -e " node capacity $node_capacity TB"
  needed_nodes=$(echo - | awk "{print $CAPACITY / $node_capacity}")
  needed_nodes=$(echo $needed_nodes | awk '{print int($1)}')
  needed_nodes=$((needed_nodes + 1))
  echo -e " Updating the eFaas instance to $needed_nodes nodes"
  echo -e "Updating eFaas instance to $CAPACITY \n" | tee -a ${LOG}
  result=$(curl -k -X POST "$EFAAS_END_POINT/api/v2/projects/$PROJECT/instances/$NAME/setCapacity" -H "accept: application/json" -H "Content-Type: application/json" -d "{\"provisionedCapacityUnits\": $needed_nodes,\"capacityUnitType\": \"Steps\"}" -H "$token")

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
    STATUS=`curl -k -b -X  -H "accept: application/json" GET "$EFAAS_END_POINT/api/v2/projects/$PROJECT/operation/$1" -H "$token"| grep status| cut -d ":" -f2| awk 'NR==1{print $1}'| cut -d \" -f 2`
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
