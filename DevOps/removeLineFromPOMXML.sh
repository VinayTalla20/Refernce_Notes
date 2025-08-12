#!/bin/bash

set -e

PROJECT_FILE="gitlabprojectNames.txt"
BRANCH_TO_CHECK="dev"
REPO_BASE_URL="https://gitlab-italent.com/italentdev/XCOP"  # 🔁 Replace with your actual base URL

tail -n +2 "$PROJECT_FILE" | while read -r PROJECT_ID PROJECT_NAME; do
    echo "🔍 Processing $PROJECT_NAME (ID: $PROJECT_ID)..."

    REPO_URL="${REPO_BASE_URL}/${PROJECT_NAME}.git"
    TEMP_DIR="${PROJECT_NAME}-temp"

    # Check if dev branch exists remotely
    if git ls-remote --heads "$REPO_URL" "$BRANCH_TO_CHECK" | grep -q "refs/heads/$BRANCH_TO_CHECK"; then
        echo "  ✅ dev branch found. Cloning..."

        git clone --quiet --single-branch --branch "$BRANCH_TO_CHECK" "$REPO_URL" "$TEMP_DIR"
        cd "$TEMP_DIR"

        echo "  🌱 Creating branch: removecommonversion"
        git checkout -b removecommonversion

        if [ -f "pom.xml" ]; then
            # Check if the target line exists before modifying
            if grep -q '<commonservice.version>${commonservice.version}</commonservice.version>' pom.xml; then
                echo "  🧹 Removing <commonservice.version> from pom.xml"
                sed -i '/<commonservice.version>${commonservice.version}<\/commonservice.version>/d' pom.xml

                git add pom.xml
                git commit -m "Remove <commonservice.version> from pom.xml"
                git push -u origin removecommonversion

                echo "  🚀 Changes pushed for $PROJECT_NAME"
            else
                echo "  ⚠️  Line not found in pom.xml, skipping commit"
            fi
        else
            echo "  ⚠️  pom.xml not found in $PROJECT_NAME"
        fi

        cd ..
    else
        echo "  ❌ dev branch not found in $PROJECT_NAME. Skipping..."
    fi

    echo ""
done

echo "✅ All done."
