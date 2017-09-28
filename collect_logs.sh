#/bin/bash

gcloud compute instances list --project "elastifile-sa"

gcloud compute --project "elastifile-sa" ssh --zone "us-central1-a" "ecfsterraform2-elfs-776cc4d4" --command "tar -zcvf ./10-128-0-3.tar.gz /elastifile/log"

gcloud compute --project "elastifile-sa" scp --zone "us-central1-a" "ecfsterraform2-elfs-776cc4d4":/home/andrew/10-128-0-3.tar.gz .
