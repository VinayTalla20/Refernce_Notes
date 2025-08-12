#!/bin/bash
set -ex

SOURCE_SA_SAS_KEY="sv=2024-11-04&ss=b&srt=sco&sp=rwdlac"
DESTINATION_SA_SAS_KEY="sv=2024-11-04&ss=bfqt&srt=sco&s"
SOURCE_SA_URL=https://grafanalokistg.blob.core.windows.net/chunks
DESTINATION_SA_URL=https://smartconxstgstorageacceu.blob.core.windows.net/chunks

azcopy copy --include-before  "2025-06-22T00:00:00Z" --include-after  "2025-03-23T00:00:00Z" "$SOURCE_SA_URL/?$SOURCE_SA_SAS_KEY" "$DESTINATION_SA_URL/?$DESTINATION_SA_SAS_KEY" --recursive
# azcopy copy --include-after  "2025-06-17T00:00:00Z" "$SOURCE_SA_URL/?$SOURCE_SA_SAS_KEY" "$DESTINATION_SA_URL/?$DESTINATION_SA_SAS_KEY" --recursive

# azcopy jobs resume 1b438bae-db1c-c645-55b2-589e4108b2b4 --source-sas $SOURCE_SA_SAS_KEY --destination-sas $DESTINATION_SA_SAS_KEY
