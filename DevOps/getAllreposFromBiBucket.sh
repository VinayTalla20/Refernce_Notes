#!/bin/bash

set -ex
# === Config ===
BASE_URL='https://api.bitbucket.org/2.0/repositories/italentdev?q=project.key%3D%22XCOP%22'
AUTH_HEADER='Authorization: Basic eWVzaHdhbnRoNDpBVEJCeTNIcDNlVU15M0J5YVJ4WndFVlFXYXlyOEQzODAxRkU='  # Replace with your actual token if needed
OUTPUT_FILE="repos.txt"

# === Clear the output file ===
> "$OUTPUT_FILE"

# === Start pagination ===
next_url="$BASE_URL"

while [ -n "$next_url" ]; do
    echo "Fetching: $next_url"

    response=$(curl -s --request GET --url "$next_url" --header "$AUTH_HEADER")

    # Extract repo names and append to file
    echo "$response" | jq -r '.values[].name' >> "$OUTPUT_FILE"

    # Get the next URL for pagination (if any)
    next_url=$(echo "$response" | jq -r '.next // empty')
done

echo "✅ All repository names saved to $OUTPUT_FILE"