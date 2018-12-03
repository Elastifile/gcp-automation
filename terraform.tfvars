# Elastifile image version
IMAGE = "elastifile-storage-3-0-0-101-ems"
# "small" "medium" "large" "standard" "small standard" "local" "small local" "custom"
TEMPLATE_TYPE = "small"
# number of vheads exlusive of EMS
NUM_OF_VMS = "3"
# <cpucores>_<ram> default: 4_42
VM_CONFIG = "16_96"
#local,persistent,hdd
DISK_TYPE = "persistent"
# <num_of_disks>_<disk_size>
DISK_CONFIG = "4_1000"
# Load Balance mode - "none" "dns" "elastifile" "google"
LB_TYPE = "google"
# numberof nodes to create
MIN_CLUSTER = "3"
# instance prefix
CLUSTER_NAME = "elastifile-guyr"
# GCP region
REGION = "us-central1"
# GCP zone
EMS_ZONE = "us-central1-f"
# GCP project
PROJECT = "booming-mission-107807"
# GCP project subnetwork
SUBNETWORK = "elastifile-subnet"
# GCP project network
NETWORK = "elastifile-network"
# GCP service account credential filename
CREDENTIALS = "booming-mission-107807-ba9123136b7f.json"
SERVICE_EMAIL = "cloud-performance@booming-mission-107807.iam.gserviceaccount.com"
# true false
USE_PUBLIC_IP = true
# deployment type - single, dual, multizone
DEPLOYMENT_TYPE = "single"
# availability zones for multizone selection, for example:  us-central1-f,us-central1-c,us-central1-d
NODES_ZONES = "us-central1-f"
# setup comoplete - false for initail deployment, true for add/remove nodes
SETUP_COMPLETE = "true"

