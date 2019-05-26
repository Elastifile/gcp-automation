# Elastifile image version
IMAGE = "emanage-3-1-0-34-e09a72d09641"
# Company name - No spaces allowed
COMPANY_NAME = "elastifile"
# Contact person name - No spaces allowed
CONTACT_PERSON_NAME = "Guy_Toledano"
# Contact person email address
EMAIL_ADDRESS = "guy.toledano@elastifile.com"
# "small" "medium" "medium-plus" "large" "standard" "small standard" "local" "small local" "custom"
TEMPLATE_TYPE = "small local"
# number of vheads exlusive of EMS
NUM_OF_VMS = "3"
#<cpucores>_<ram> default: 4_42
VM_CONFIG = "4_60"
#local,persistent,hdd
DISK_TYPE = "persistent"
# <num_of_disks>_<disk_size>
DISK_CONFIG = "4_1000"
# Load Balance mode - "none" "dns" "elastifile" "google"
LB_TYPE = "elastifile"
# instance prefix
CLUSTER_NAME = "elastifile-guyt"
# GCP region
REGION = "us-east2"
# GCP zone
EMS_ZONE = "us-east2-a"
# GCP project
PROJECT = "canary-support"
# GCP project subnetwork
SUBNETWORK = "mcp-clone01"
# GCP project network
NETWORK = "mcp-clone01"
# GCP service account credential filename
CREDENTIALS = "canary-support-8ae8eefb786c.json"
SERVICE_EMAIL = "canary-support-admin@canary-support.iam.gserviceaccount.com"
# true false
USE_PUBLIC_IP = false
# deployment type - single, dual, multizone
DEPLOYMENT_TYPE = "single"
# availability zones for multizone selection, for example:  us-central1-f,us-central1-c,us-central1-d
NODES_ZONES = "us-east2-a"
# setup complete - false for initial deployment, true for add/remove nodes
SETUP_COMPLETE = "false"
# Clear Tier - true false
ILM = "false"
# AsyncDR - true false
ASYNC_DR = "false"
# GCP ECMP LB override
# provide IP for LB to prevent auto-select
#LB_VIP = "10.128.11.99"
LB_VIP = "auto"
# Data Container name
DATA_CONTAINER = "DC01"
#create EMS only
EMS_ONLY = "true"
#kms - customer managed encryption key
KMS_KEY = ""
# path to key file
SSH_CREDENTIALS = "~/elastifile.pem"
#proxy params
NO_PROXY = "127.0.0.1,169.254.169.254,metadata,metadata.google.insternal,localhost,*.google.internal"
PROXY_IP = "http://172.16.1.3"
PROXY_PORT = "3128"
DNS_SERVER_1 = "172.16.1.4"
DNS_SERVER_2 = "172.16.1.2"
DOMAIN_NAME = "mpclone.local"
DOMAIN_SEARCH = "mpclone.local"
