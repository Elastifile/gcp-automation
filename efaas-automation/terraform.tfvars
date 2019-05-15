# Elastifile Site Types
EFAAS_END_POINT="https://bronze-eagle.gcp.elastifile.com"
# GCP Project Number
PROJECT="533242302368"
# Efaas Name
NAME="guyr-efaas-1"
# Efaas Description
DESCRIPTION="guys-cluster"
# Efaas Region
REGION="us-central1"
# Efaas Zone
ZONE="us-central1-f"
# Efaas Class Types:
# high-performance
# high-performance-az
# capacity-optimized
# capacity-optimized-az
# general-use
# general-use-az
SERVICE_CLASS="high-performance"
# Efaas Network
NETWORK="elastifile-network"
# ACL IP Address Range or all
ACL_RANGE="all,0.0.0.0/0,192.178.0.0/24"
# ACL Access rights, readOnly or readWrite
ACL_ACCESS_RIGHTS="readWrite,readWrite,readOnly"
# Snapshot, true or false
SNAPSHOT="true"
# Snapshot scheduler, Daily, Weekly, Monthly
SNAPSHOT_SCHEDULER="Weekly"
# Snapshot Retention, deletes snapshot every X days.
SNAPSHOT_RETENTION="7"
# Capacity in TB
CAPACITY="8"
# GCP service account credential filename
CREDENTIALS="booming-mission-107807-0e99db2e1ce2.json"
# Multizone - true or false
MULTIZONE="false"
# setup complete - false for initial deployment, true for add/remove nodes, modify the capacity size...
SETUP_COMPLETE = "false"
# filesystem name
DC="filesystem_4"
# filesystem description
DC_DESCRIPTION="forth_filesystem"
# quota type auto or fixed
QUOTA_TYPE="fixed"
# hard quota when quota type is fixed - in Bytes, min 15,000,000,000 (15GB)
HARD_QUOTA="40000000000"
