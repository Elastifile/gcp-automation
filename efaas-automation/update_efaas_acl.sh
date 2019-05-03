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
  -d acl range 
  -e credentials
  -f acl access rights

Examples:
  ./.sh -n 2 -a 1
E_O_F
  exit 1
}

#variables
SETUP_COMPLETE="false"
LOG="update_efaas_acl.log"
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
    d)  ACL_RANGE=${OPTARG}
        ;;
    e)  CREDENTIALS=${OPTARG}
        ;;
    f)  ACL_ACCESS_RIGHTS=${OPTARG}
        ;;
    esac
done

# Update the efaas acl
function update_efaas_acl {
  export ELASTIFILE_APPLICATION_CREDENTIALS="$CREDENTIALS"
  source .env/bin/activate
  token=`python3.6 main.py`
  token=`echo "$token"|xargs`
  
  fingerprint=$(curl -k -b -X  -H "accept: application/json" -H "$token" GET "$EFAAS_END_POINT/api/v1/projects/$PROJECT/instances/$NAME"| grep fingerprint| cut -d ":" -f2| awk 'NR==1{print $1}'| cut -d \" -f 2)
  echo -e "Updating eFaas acl to acl_range:$ACL_RANGE and acl_access_rights:$ACL_ACCESS_RIGHTS \n" | tee -a ${LOG}

  result=$(curl -k -X POST "$EFAAS_END_POINT/api/v1/projects/$PROJECT/instances/$NAME/setAccessors" -H "accept: application/json" -H "Content-Type: application/json" -d "{ \"items\": [ { \"sourceRange\": \"$ACL_RANGE\", \"accessRights\": \"$ACL_ACCESS_RIGHTS\" } ], \"fingerprint\": \"$fingerprint\" }" -H "$token")

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
    echo -e  "update efaas acl : ${STATUS} " | tee -a ${LOG}
    if [[ ${STATUS} == "DONE" ]]; then
      echo -e "update efaas acl Complete! \n" | tee -a ${LOG}
      sleep 5
      break
    fi
    if [[ ${STATUS} == "ERROR" ]]; then
      echo -e "update efaas acl Failed. Exiting..\n" | tee -a ${LOG}
      exit 1
    fi
    sleep 10
  done
}

#MAIN
update_efaas_acl
