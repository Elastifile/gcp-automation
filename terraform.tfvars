# Elastifile image version
IMAGE = "elastifile-storage-3-2-1-19-ems"
# Company name - No spaces allowed
COMPANY_NAME = "elastifile"
# Contact person name - No spaces allowed
CONTACT_PERSON_NAME = "Guy_Rinkevich"
# Contact person email address
EMAIL_ADDRESS = "guy.rinkevich@elastifile.com"
# "small" "medium" "medium-plus" "large" "standard" "small standard" "local" "small local" "custom"
TEMPLATE_TYPE = "large"
# number of vheads exclusive of EMS
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
CLUSTER_NAME = "elastifile-guyr"
# GCP region
REGION = "us-central1"
# GCP zone
EMS_ZONE = "us-central1-f"
# GCP project
PROJECT = "booming-mission-107807"
# GCP project subnetwork - use full path when deploying in a SVPC env
SUBNETWORK = "elastifile-subnet"
# GCP project network - use full path when deploying in a SVPC and Google iLB env
NETWORK = "elastifile-network"
# GCP service account credential filename
CREDENTIALS = "booming-mission-107807-0e99db2e1ce2.json"
SERVICE_EMAIL = "cloud-performance@booming-mission-107807.iam.gserviceaccount.com"
# true false
USE_PUBLIC_IP = true
# deployment type - single, dual, multizone
DEPLOYMENT_TYPE = "single"
# availability zones for multizone selection, for example:  us-central1-f,us-central1-c,us-central1-d
NODES_ZONES = "us-central1-f"
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
EMS_ONLY = "false"
#kms - customer managed encryption key
KMS_KEY = ""
# image Project
IMAGE_PROJECT = "elastifle-public-196717"
