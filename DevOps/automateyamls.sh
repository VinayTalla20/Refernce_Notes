#!/bin/bash
set -ex
 
# Variables
BITBUCKET_USER="VinayTalla20"
BITBUCKET_ORG="italentdev"
BASE_BRANCH="dev"
BRANCH_NAME="XCC-3523-final-mig"
POM_FILE="pom.xml"
REPO_FILE="reponames.txt"  # Text file containing repo names (one per line)
LOCAL_CI_FILE_PATH="./.gitlab-ci.yml"  # Local GitLab CI file to copy
BUILD_PIPELINES_FILE="azure-build-pipelines.yml"
 
# Check if repo list file exists
if [[ ! -f "$REPO_FILE" ]]; then
    echo "Error: $REPO_FILE not found!"
    exit 1
fi
 
# Check if local .gitlab-ci.yml file exists
if [[ ! -f "$LOCAL_CI_FILE_PATH" ]]; then
    echo "Error: Local .gitlab-ci.yml file not found!"
    exit 1
fi
 
# Loop through each repository name in repos.txt
while IFS= read -r REPO_NAME; do
    if [[ -z "$REPO_NAME" ]]; then
        continue  # Skip empty lines
    fi
 
    REPO_URL="https://$BITBUCKET_USER@bitbucket.org/$BITBUCKET_ORG/$REPO_NAME.git"
    echo "Cloning repository: $REPO_NAME"
   
    # Clone the repository
    git clone "$REPO_URL"
    wait
    sleep 10
   
    # Enter the repository directory
    cd "$REPO_NAME" || { echo "Failed to enter $REPO_NAME"; continue; }
 
    # Create a new branch from dev
    git checkout -b "$BRANCH_NAME" origin/"$BASE_BRANCH"
 
    # Read pom.xml file if it exists
    if [[ -f "$POM_FILE" ]]; then
        echo "Reading $POM_FILE..."
       
        # Properly comment out entire XML blocks
        sed -i '/<repositories>/,/<\/repositories>/ {s/^/<!-- /; s/$/ -->/}' "$POM_FILE"
        sed -i '/<distributionManagement>/,/<\/distributionManagement>/ {s/^/<!-- /; s/$/ -->/}' "$POM_FILE"
        sed -i '/<pluginRepositories>/,/<\/pluginRepositories>/ {s/^/<!-- /; s/$/ -->/}' "$POM_FILE"
       
        # Insert new repositories and distributionManagement blocks before </project>
        sed -i '/<\/project>/i \
<repositories>\
    <repository>\
        <id>gitlab-maven</id>\
        <url>https://gitlab-italent.com/api/v4/projects/${PROJECT_ID}/packages/maven</url>\
    </repository>\
</repositories>\
<distributionManagement>\
    <repository>\
        <id>gitlab-maven</id>\
        <url>https://gitlab-italent.com/api/v4/projects/${PROJECT_ID}/packages/maven</url>\
    </repository>\
    <!--  <snapshotRepository>\
            <id>gitlab-maven</id>\
            <url>https://gitlab-italent.com/api/v4/projects/${PROJECT_ID}/packages/maven</url>\
        </snapshotRepository>  -->\
</distributionManagement>' "$POM_FILE"
 
# Insert <commonservice.version> inside <properties> before </properties>
        sed -i '/<\/properties>/i \
    <commonservice.version>${commonservice.version}</commonservice.version>' "$POM_FILE"
 
        cat "$POM_FILE"
    else
        echo "$POM_FILE not found!"
    fi
 
    # Extract SERVICE_NAME from azure-build-pipelines.yml
    if [[ -f "$BUILD_PIPELINES_FILE" ]]; then
        SERVICE_NAME=$(grep -A1 "name: SERVICE_NAME" azure-build-pipelines.yml | grep "value:" | awk -F'"' '{print $2}')
        echo "Extracted SERVICE_NAME: $SERVICE_NAME"
    else
        echo "Error: $BUILD_PIPELINES_FILE not found in $REPO_NAME"
        SERVICE_NAME=""
    fi
 
    # Copy .gitlab-ci.yml to the repository
    cp ../.gitlab-ci.yml .
 
    # Update SERVICE_NAME in .gitlab-ci.yml
    if [[ -n "$SERVICE_NAME" ]]; then
        sed -i "s/service_name:.*/service_name: \"$SERVICE_NAME\"/" .gitlab-ci.yml
    fi
   
    # Commit and push changes
    git add .gitlab-ci.yml "$POM_FILE"
    git commit -m "Updated pom.xml: Commented out repositories, distributionManagement, and pluginRepositories. Added new GitLab repository details inside </project>. Updated .gitlab-ci.yml with SERVICE_NAME: $SERVICE_NAME"
    git push origin "$BRANCH_NAME"
 
    # Go back to the parent directory
    cd ..
   
done < "$REPO_FILE"
 
echo "All repositories processed!"