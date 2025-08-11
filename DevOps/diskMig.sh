#!/bin/bash
set -ex

TARGET_DISK_TARGET_RESOURCE_GROUP=-DEV-RG-EU
TARGET_DISK_NAME=Prometheus-Dev
TARGET_DISK_SKU=StandardSSD_ZRS
TARGET_DISK_LOCATION=germanywestcentral
#Provide the size of the disks in GB. It should be greater than the VHD file size.
TARGET_DISK_SIZE=26

SOURCE_DISK_NAME=prometheus-dev
SOURCE_DISK_RESOURCE_GROUP=S-Dev-RG

DURATION_SECONDS=3600
STORAGE_ACCOUNT_NAME=smartconxdevstorageacceu
STORAGE_ACCOUNT_RESOURCE_GROUP=${TARGET_DISK_TARGET_RESOURCE_GROUP}
STORAGE_ACCOUNT_CONTAINER_NAME=${SOURCE_DISK_NAME}
STORAGE_ACCOUNT_BLOB_VHD_FILE_NAME="${STORAGE_ACCOUNT_CONTAINER_NAME}.vhd"



SAS_URL=$(az disk grant-access --resource-group $SOURCE_DISK_RESOURCE_GROUP --name $SOURCE_DISK_NAME --duration-in-seconds $DURATION_SECONDS --query [accessSas] -o tsv)

echo "Using SAS URL: $SAS_URL"

STORAGE_ACCOUNT_KEY=$(az storage account keys list \
 --account-name $STORAGE_ACCOUNT_NAME \
 --resource-group $STORAGE_ACCOUNT_RESOURCE_GROUP \
 --query "[0].value" \
 --output tsv)

# Create Container
az storage container create --name $STORAGE_ACCOUNT_CONTAINER_NAME --account-key $STORAGE_ACCOUNT_KEY --account-name $STORAGE_ACCOUNT_NAME

az storage blob copy start \
 --account-name $STORAGE_ACCOUNT_NAME \
 --account-key $STORAGE_ACCOUNT_KEY \
 --destination-container $STORAGE_ACCOUNT_CONTAINER_NAME \
 --destination-blob $STORAGE_ACCOUNT_BLOB_VHD_FILE_NAME \
 --source-uri $SAS_URL

## CHECK FOR STATUS TO BE SUCCESS 
while true; do
  copy_status=$(az storage blob show \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --container-name "$STORAGE_ACCOUNT_CONTAINER_NAME" \
    --name "$STORAGE_ACCOUNT_BLOB_VHD_FILE_NAME" \
    --query "properties.copy.status" \
    --output tsv)

  echo "Current copy status: $copy_status"

  if [[ "$copy_status" == "success" ]]; then
    echo "✅ Copy completed successfully."
    break
  elif [[ "$copy_status" == "failed" || "$copy_status" == "aborted" ]]; then
    echo "❌ Copy failed or was aborted."
    exit 1
  fi

  sleep 10  # Wait 10 seconds before checking again
done

vhd_blob_url=https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net/${STORAGE_ACCOUNT_CONTAINER_NAME}/${STORAGE_ACCOUNT_BLOB_VHD_FILE_NAME}

echo "using vhd_blob_url: ${vhd_blob_url}"

# create Disk from Blob VHD
az disk create --resource-group $TARGET_DISK_TARGET_RESOURCE_GROUP --name $TARGET_DISK_NAME --sku $TARGET_DISK_SKU --location $TARGET_DISK_LOCATION --size-gb $TARGET_DISK_SIZE --source $vhd_blob_url
