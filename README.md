# Terraform-Elastifile-GCP

Terraform to create, configure and deploy a Elastifile Cloud Filesystem (ECFS) cluster in Google Compute (GCE)

## Note:
Follow the Elastifile Cloud Deployment GCP Installation Guide to make sure ECFS can be successfully deployed in GCE before using this.

## Use:
1. Create password.txt file with a password to use for eManage  (.gitignore skips this file)
2. Specify configuration variables in terraform.tvars:
- NUM_OF_VMS = Number of ECFS virtual controllers, 3 minimum
- DISKTYPE = "persistent" or "local"
- NUM_OF_DISKS = Number of disks per virtual controller. 1-5 for local SSD, 1-10 for persistent SSD
- CLUSTER_NAME = Name for ECFS service
- ZONE = Zone
- PROJECT = Project name
- IMAGE = EMS image name
- CREDENTIALS = path to service account credentials .json file
- SERVICE_EMAIL = service account email address
3. Run 'terraform init' then 'terraform apply'

## Components:

**google_ecfs.tf**
Main terraform configuration file.

**create_vheads.sh**
Bash script to configure Elastifile EManage (EMS) Server, and deploy cluster of ECFS virtual controllers (vheads). Uses Elastifile REST API. Called as null_provider from google_ecfs.tf

**destroy_vheads.sh**
Bash script to query and delete multiple GCE instances simultaneously. Called as null_provider destroy from google_ecfs.tf

**password.txt**
Plaintext file with EMS password
