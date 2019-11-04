#!/bin/bash
DEPLOYMENT="main"
gcloud compute instances create velo-mgr \
  --project=${GOOGLE_PROJECT} \
  --image=velostrata-mgmt-4-5-1-27955-20129-os \
  --image-project=velossandbox \
  --zone=us-central1-a \
  --machine-type=n1-standard-4 \
  --boot-disk-size=60 \
  --metadata=apiPassword=velo1234,defaultServiceAccount=velos-cloud-extension-${DEPLOYMENT}@${GOOGLE_PROJECT}.iam.gserviceaccount.com,secretsEncKey=qwiklabs \
  --service-account=velos-manager-${DEPLOYMENT}@${GOOGLE_PROJECT}.iam.gserviceaccount.com \
  --tags=https-server \
  --scopes="https://www.googleapis.com/auth/cloud-platform","rpc://phrixus.googleapis.com/auth/cloudrpc"
