#!/bin/bash
set -e

# === Config ===
BITBUCKET_USER="vinayt2"
BITBUCKET_PASSWORD=ATBBpMghxwUpcrNSCtFzFxpP95YU043102BB  # Set via prompt or env
BITBUCKET_ORG="italentdev"
SOURCE_BRANCH="XCC-3523-final-mig"
DEST_BRANCH="dev"
REPO_FILE="repos.txt"
PR_URL_FILE="pull_requests.txt"

# === Clear output file ===
> "$PR_URL_FILE"

# === Loop through each repo ===
while IFS= read -r REPO_NAME; do
    [[ -z "$REPO_NAME" ]] && continue

    # Construct the HTTPS Git URL
    REPO_URL="https://$BITBUCKET_USER:$BITBUCKET_PASSWORD@bitbucket.org/$BITBUCKET_ORG/$REPO_NAME.git"
    echo "🔗 REPO_URL: $REPO_URL"

    echo "🔍 Checking if branch '$SOURCE_BRANCH' exists in $REPO_NAME..."

    # Check if the branch exists
    BRANCH_EXISTS=$(curl -s -u "$BITBUCKET_USER:$BITBUCKET_PASSWORD" \
      "https://api.bitbucket.org/2.0/repositories/$BITBUCKET_ORG/$REPO_NAME/refs/branches/$SOURCE_BRANCH" \
      | jq -r '.name // empty')

    if [[ "$BRANCH_EXISTS" != "$SOURCE_BRANCH" ]]; then
        echo "$REPO_NAME: ⚠️ Branch '$SOURCE_BRANCH' not found" | tee -a "$PR_URL_FILE"
        continue
    fi

    echo "✅ Branch exists — creating pull request..."

    # Create pull request
    RESPONSE=$(curl -s -u "$BITBUCKET_USER:$BITBUCKET_PASSWORD" \
      -H "Content-Type: application/json" \
      -X POST "https://api.bitbucket.org/2.0/repositories/$BITBUCKET_ORG/$REPO_NAME/pullrequests" \
      -d "{
            \"title\": \"Merge $SOURCE_BRANCH to $DEST_BRANCH\",
            \"source\": { \"branch\": { \"name\": \"$SOURCE_BRANCH\" } },
            \"destination\": { \"branch\": { \"name\": \"$DEST_BRANCH\" } }
          }")

    PR_LINK=$(echo "$RESPONSE" | jq -r '.links.html.href // empty')

    if [[ -n "$PR_LINK" ]]; then
        echo "$REPO_NAME: $PR_LINK" | tee -a "$PR_URL_FILE"
    else
        echo "$REPO_NAME: ❌ Failed to create PR" | tee -a "$PR_URL_FILE"
    fi

done < "$REPO_FILE"

echo "🎉 Done! Pull request results saved in $PR_URL_FILE"
