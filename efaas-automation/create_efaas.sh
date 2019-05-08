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
  -d description
  -e region
  -f zone
  -g service class
  -i network
  -j acl range
  -k acl access rights
  -l snapshots
  -m snapshots scheduler
  -n snapshots retention
  -o capacity
  -p credentials
Examples:
  ./.sh -n 2 -a 1
E_O_F
  exit 1
}

#variables
SETUP_COMPLETE="false"
LOG="create_efaas.log"
taskid=0

while getopts "h?:a:b:c:d:e:f:g:i:j:k:l:m:n:o:p:" opt; do
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
    d)  DESCRIPTION=${OPTARG}
        ;;
    e)  REGION=${OPTARG}
        ;;
    f)  ZONE=${OPTARG}
        ;;
    g)  SERVICE_CLASS=${OPTARG}
        ;;
    i)  NETWORK=${OPTARG}
        ;;
    j)  ACL_RANGE=${OPTARG}
        ;;
    k)  ACL_ACCESS_RIGHTS=${OPTARG}
        ;;
    l)  SNAPSHOT=${OPTARG}
        ;;
    m)  SNAPSHOT_SCHEDULER=${OPTARG}
        ;;
    n)  SNAPSHOT_RETENTION=${OPTARG}
        ;;
    o)  CAPACITY=${OPTARG}
        ;;
    p)  CREDENTIALS=${OPTARG}
        ;;
    esac
done

# Kickoff a create enode instances job
function create_efaas {
  export ELASTIFILE_APPLICATION_CREDENTIALS="$CREDENTIALS"
  source .env/bin/activate
  token=`python3.6 main.py`
  token=`echo "$token"|xargs`

  capacity_unit=$(curl -k -b -X  -H "accept: application/json" -H "$token" GET "$EFAAS_END_POINT/api/v1/projects/$PROJECT/service-class/$SERVICE_CLASS"|grep unitSize| cut -d ":" -f2| awk 'NR==1{print $1}'| cut -d \" -f 2| tr -d ',')
  echo -e "capacity unit $capacity_unit"
  tb=$((1024*1024*1024*1024))
  node_capacity=$(echo - | awk "{print $capacity_unit / $tb}")
  echo -e " node capacity $node_capacity"
  needed_nodes=$(echo - | awk "{print $CAPACITY / $node_capacity}")
  needed_nodes=$(echo $needed_nodes | awk '{print int($1)}')
  needed_nodes=$((needed_nodes + 1))
  echo -e "Creating eFaas instance\n" | tee -a ${LOG}
  result=$(curl -k -X POST "$EFAAS_END_POINT/api/v1/projects/$PROJECT/instances" -H "accept: application/json" -H "Content-Type: application/json" -d "{ \"name\": \"$NAME\", \"description\": \"$DESCRIPTION\", \"serviceClass\": \"$SERVICE_CLASS\", \"provisionedCapacityUnits\": $needed_nodes, \"capacityUnitType\": \"Steps\", \"region\": \"$REGION\", \"zone\": \"$ZONE\", \"network\": \"$NETWORK\", \"snapshot\": { \"enable\": $SNAPSHOT, \"schedule\": \"$SNAPSHOT_SCHEDULER\", \"retention\": $SNAPSHOT_RETENTION }, \"accessors\": { \"items\": [ { \"sourceRange\": \"$ACL_RANGE\", \"accessRights\": \"$ACL_ACCESS_RIGHTS\" } ] }}" -H "$token")
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
    STATUS=`curl -k -b -X  -H "accept: application/json" GET "$EFAAS_END_POINT/api/v1/projects/$PROJECT/operation/$service_id" -H "$token"| grep status| cut -d ":" -f2| awk 'NR==1{print $1}'| cut -d \" -f 2`
    echo -e  "efaas instance $1 : ${STATUS} " | tee -a ${LOG}
    if [[ ${STATUS} == "DONE" ]]; then
      echo -e "$1 Complete! \n" | tee -a ${LOG}
      sleep 5
      break
    fi
    if [[ ${STATUS} == "ERROR" ]]; then
      echo -e "$1 Failed. Exiting..\n" | tee -a ${LOG}
      exit 1
    fi
    sleep 10
  done
}

#MAIN
#establish_token ${PASSWORD}
create_efaas
#add_capacity ${NUM_OF_VMS}
