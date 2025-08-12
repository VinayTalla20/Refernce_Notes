#!/bin/bash
set -ex

# Variables
BITBUCKET_USER="vinayt2"
BITBUCKET_PASSWORD=ATBBpMghxwUpcrNSCtFzFxpP95YU043102BB  # Set this securely, consider reading from env or prompt
BITBUCKET_ORG="italentdev"
BASE_BRANCH="dev"
BRANCH_NAME="bitbucket-backup"
REPO_FILE="repos.txt"  # Text file containing repo names (one per line) 

# Check if repo list file exists
if [[ ! -f "$REPO_FILE" ]]; then
    echo "Error: $REPO_FILE not found!"
    exit 1
fi

# Loop through each repository name in repos.txt
while IFS= read -r REPO_NAME; do
    if [[ -z "$REPO_NAME" ]]; then
        continue  # Skip empty lines
    fi

    REPO_URL="https://$BITBUCKET_USER:$BITBUCKET_PASSWORD@bitbucket.org/$BITBUCKET_ORG/$REPO_NAME.git"
    echo "Cloning repository: $REPO_NAME"

    # Check if dev branch exists before cloning
    if ! git ls-remote --exit-code --heads "$REPO_URL" "$BASE_BRANCH" > /dev/null; then
        echo "⚠️  Skipping $REPO_NAME: '$BASE_BRANCH' branch not found."
        continue
    fi

    # Clone the repository
    git clone "$REPO_URL"
    wait
    sleep 5

    # Enter the repository directory
    cd "$REPO_NAME" || { echo "Failed to enter $REPO_NAME"; continue; }

    # Create a new branch from dev
    git checkout -b "$BRANCH_NAME" origin/"$BASE_BRANCH"

    # Commit and push changes
    git add .
    git commit -m "dev code backup for gitlab migration" || echo "No changes to commit in $REPO_NAME"
    git push origin "$BRANCH_NAME"

    # Go back to the parent directory
    cd ..

done < "$REPO_FILE"

echo "✅ All repositories processed!"