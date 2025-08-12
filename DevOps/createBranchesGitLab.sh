#!/bin/bash

BASE_URL="https://gitlab-italent.com/italentdev/XCOP"
BRANCH_TO_CHECK="dev"
NEW_BRANCH="predev"
PROJECT_LIST_FILE="gitlabprojectNames.txt"

while read -r PROJECT_ID PROJECT_NAME; do
    REPO_URL="${BASE_URL}/${PROJECT_NAME}.git"
    echo "Checking project: $REPO_URL"

    # Check if dev branch exists
    if git ls-remote --heads "$REPO_URL" "$BRANCH_TO_CHECK" | grep -q "refs/heads/$BRANCH_TO_CHECK"; then
        echo "✅ '$BRANCH_TO_CHECK' exists in $PROJECT_NAME. Creating '$NEW_BRANCH'..."

        # Clone the repo shallowly
        git clone --quiet --single-branch --branch "$BRANCH_TO_CHECK" "$REPO_URL" "${PROJECT_NAME}-temp"
        cd "${PROJECT_NAME}-temp" || continue

        # Create and push the new branch
        git checkout -b "$NEW_BRANCH"
        git push origin "$NEW_BRANCH"

        echo "✅ '$NEW_BRANCH' created successfully in $PROJECT_NAME."

        # Cleanup
        cd ..
    else
        echo "❌ '$BRANCH_TO_CHECK' does not exist in $PROJECT_NAME. Skipping."
    fi

    echo "-----------------------------------------"
done < "$PROJECT_LIST_FILE"