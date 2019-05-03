# Elastifile Site Types
EFAAS_END_POINT="https://silver-eagle.gcp.elastifile.com"
# GCP Project Number
PROJECT="533242302368"
# Efaas Name
NAME="guyr"
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
ACL_RANGE="0.0.0.0/0"
# ACL Access rights, readOnly or readWrite
ACL_ACCESS_RIGHTS="readWrite"
# Snapshot, true or false
SNAPSHOT="true"
# Snapshot scheduler, Daily, Weekly, Monthly
SNAPSHOT_SCHEDULER="Weekly"
# Snapshot Retention, deletes snapshot every X days.
SNAPSHOT_RETENTION="7"
# Capacity - min 6 for multizone instances or 3 for single zone
CAPACITY="3"
# GCP service account credential filename
CREDENTIALS="booming-mission-107807-0e99db2e1ce2.json"
# Multizone - true or false
MULTIZONE="false"
# setup complete - false for initial deployment, true for add/remove nodes, modify the capacity size...
SETUP_COMPLETE = "false"
