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
  -b projects
  -c name
  -d credentials
  -e dc name to be deleted

Examples:
  ./.sh -n 2 -a 1
E_O_F
  exit 1
}

#variables
SETUP_COMPLETE="false"
LOG="delete_dc.log"

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
    d)  CREDENTIALS=${OPTARG}
        ;;
    e)  DC=${OPTARG}
        ;;
    esac
done

# Update the efaas dc
function delete_dc {
  export ELASTIFILE_APPLICATION_CREDENTIALS="$CREDENTIALS"
  source .env/bin/activate
  token=`python3.6 main.py`
  token=`echo "$token"|xargs`
  
  if [[ $DC == "none" ]]; then
        exit
  fi
 
# checking the dc id
  dc_id=$(curl -k -b -X  -H "accept: application/json" -H "$token" GET "$EFAAS_END_POINT/api/v2/projects/$PROJECT/instances/$NAME"| grep -B 3 -A 4 '"name": "'$DC'"',| grep "id"| cut -d ":" -f 2| cut -d \" -f 2)
  echo "$dc_id"

# deleting the filesystem
  echo -e "Deleting filesystem $DC.." | tee -a ${LOG}
  result=$(curl -k -X DELETE "$EFAAS_END_POINT/api/v2/projects/$PROJECT/instances/$NAME/filesystem/$dc_id" -H "accept: application/json" -H "Content-Type: application/json" -H "$token") 

# checking the filesystem delete status
  service_id=`echo $result| cut -d " " -f 3 | cut -d \" -f 2`
  echo $result | tee -a ${LOG}
  job_status $service_id
  sleep 5

}

# Function to check running job status
function job_status {
  export ELASTIFILE_APPLICATION_CREDENTIALS="$CREDENTIALS"
  source .env/bin/activate
  token=`python3.6 main.py`
  token=`echo "$token"|xargs`
  
  while true; do
    STATUS=`curl -k -b -X  -H "accept: application/json" GET "$EFAAS_END_POINT/api/v2/projects/$PROJECT/operation/$1" -H "$token"| grep status| cut -d ":" -f2| awk 'NR==1{print $1}'| cut -d \" -f 2`
    echo -e  "delete filesystem $DC : ${STATUS} " | tee -a ${LOG}
    
    if [[ ${STATUS} == "DONE" ]]; then
      echo -e "delete filesystem $DC Complete! \n" | tee -a ${LOG}
      sleep 5
      break
    fi
    if [[ ${STATUS} == "ERROR" ]]; then
      echo -e "delete filesystem $DC Failed. Exiting..\n" | tee -a ${LOG}
      exit 1
    fi
    sleep 10
  done
}

#MAIN
delete_dc
