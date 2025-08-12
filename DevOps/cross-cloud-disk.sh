#!/bin/bash

set -e  # Exit on any error

# installation 
# sudo apt-get install qemu-utils

# === Logging Function ===
log() {
  echo "[📅 $(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# === CONFIGURATION ===
AZURE_RG="SMARTCONX-DEV-RG-EU"
AZURE_DISK_NAME="smartconx-dev-mongodb-EU"
AZURE_SNAPSHOT_NAME="mongodbdev-eu-snapshot-$(date +%Y%m%d%H%M%S)"
AZURE_LOCATION="Germany West Central"
SNAPSHOT_DURATION_SECONDS=6600

VHD_FILE="azure-mongodb-dev-test.vhd"
RAW_FILE="azure-mongodb-dev-test.raw"
TAR_FILE="azure-mongodb-dev-test.tar.gz"

BUCKET_NAME="my-azure-disk-images"
GCP_IMAGE_NAME="mongodb-gcp-dev-test"
GCP_DISK_NAME="mongodb-dev-gcp-eu-test"
GCP_ZONE="europe-west3-a"
GCP_BUCKET_LOCATION="EU"

# === STEP 0: Prerequisites Check ===
log "🔍 Checking for required tools..."
for cmd in qemu-img gsutil gcloud wget; do
  if ! command -v $cmd &>/dev/null; then
    echo "❌ $cmd not found. Please install it." >&2
    exit 1
  fi
done
log "✅ All required tools are available."

# === STEP 1: Create Azure Snapshot ===
log "📸 Creating Azure snapshot from disk '$AZURE_DISK_NAME'..."
az snapshot create \
  --resource-group "$AZURE_RG" \
  --name "$AZURE_SNAPSHOT_NAME" \
  --source "$AZURE_DISK_NAME" \
  --location "$AZURE_LOCATION" \
  --incremental true
log "✅ Azure snapshot '$AZURE_SNAPSHOT_NAME' created."

# === STEP 2: Generate Export URL for Snapshot ===
log "🔗 Generating SAS URL for snapshot..."
AZURE_SNAPSHOT_URL=$(az snapshot grant-access \
  --resource-group "$AZURE_RG" \
  --name "$AZURE_SNAPSHOT_NAME" \
  --duration-in-seconds "$SNAPSHOT_DURATION_SECONDS" \
  --query accessSAS \
  --output tsv)

if [[ -z "$AZURE_SNAPSHOT_URL" ]]; then
  log "❌ Failed to get snapshot SAS URL."
  exit 1
fi
log "✅ Snapshot export URL retrieved."

# === STEP 3: Download Azure VHD snapshot ===
log "⬇️  Downloading Azure VHD snapshot..."
wget "$AZURE_SNAPSHOT_URL" -O "$VHD_FILE"
log "✅ Download completed: $VHD_FILE"

# === STEP 4: Create GCS bucket if not exists ===
log "📁 Checking/creating GCS bucket '$BUCKET_NAME'..."
if ! gsutil ls -b "gs://${BUCKET_NAME}" &>/dev/null; then
  gsutil mb -l "$GCP_BUCKET_LOCATION" "gs://${BUCKET_NAME}"
  log "✅ GCS bucket created."
else
  log "✅ GCS bucket already exists."
fi

# === STEP 5: Convert VHD to RAW ===
log "🔄 Converting VHD to RAW..."
qemu-img convert -f vpc -O raw "$VHD_FILE" "$RAW_FILE"
log "✅ Conversion completed: $RAW_FILE"

# === STEP 6: Compress RAW disk ===
log "📦 Compressing RAW disk to TAR..."
mv "$RAW_FILE" disk.raw
tar -Szcf "$TAR_FILE" disk.raw
log "✅ Compression completed: $TAR_FILE"

# === STEP 7: Upload to GCS ===
log "☁️ Uploading TAR file to Google Cloud Storage..."
gsutil cp "$TAR_FILE" "gs://${BUCKET_NAME}/"
log "✅ Upload completed."

# === STEP 8: Create GCP Image from TAR ===
log "🖼️ Creating GCP image '$GCP_IMAGE_NAME'..."
gcloud compute images create "$GCP_IMAGE_NAME" \
  --source-uri="gs://${BUCKET_NAME}/${TAR_FILE}" \
  --guest-os-features=UEFI_COMPATIBLE
log "✅ GCP image created."

# === STEP 9: Create GCP Disk from Image ===
log "💽 Creating GCP disk '$GCP_DISK_NAME' in zone '$GCP_ZONE'..."
gcloud compute disks create "$GCP_DISK_NAME" \
  --image="$GCP_IMAGE_NAME" \
  --zone="$GCP_ZONE"
log "✅ GCP disk created."

log "🎉 Migration completed successfully!"
