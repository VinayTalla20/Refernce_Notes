#!/bin/bash

#https://gitlab-italent.com/italentdev/XCOP/configurations.git
GITLAB_BASE_URL="https://gitlab-italent.com/italentdev/XCOP"  # Replace with actual GitLab group
BRANCH_NAME="XCC-3727"
SOURCE_BRANCH="dev"

while read -r PROJECT_NAME; do
  [[ -z "$PROJECT_NAME" ]] && continue  # skip empty lines

  echo "Processing project: $PROJECT_NAME"
  CLONE_DIR="${PROJECT_NAME}_temp2"

  # Clone project and switch directory
  git clone --quiet "$GITLAB_BASE_URL/$PROJECT_NAME.git" "$CLONE_DIR" || { echo "Failed to clone $PROJECT_NAME"; continue; }
  cd "$CLONE_DIR" || continue

  # Fetch all branches and checkout source branch
  git fetch origin
  git checkout "$SOURCE_BRANCH" || { echo "Branch $SOURCE_BRANCH not found in $PROJECT_NAME"; cd ..; continue; }

  # Create new branch from dev
  git checkout -b "$BRANCH_NAME"

  # Process .gitlab-ci.yml
  if [[ -f ".gitlab-ci.yml" ]]; then
    echo "Checking for stage in $PROJECT_NAME..."

    if grep -q 'Check-Code-Coverage-Percentage' .gitlab-ci.yml; then
      echo "Stage already exists. Skipping insert."
    else
      awk '
        BEGIN { inserted = 0 }
        /^\s*-\s*Maven-Install\s*$/ {
          print
          print "  - Check-Code-Coverage-Percentage"
          inserted = 1
          next
        }
        { print }
        END {
          if (!inserted) {
            print "Warning: Maven-Install stage not found, no insertion made." > "/dev/stderr"
          }
        }
      ' .gitlab-ci.yml > .gitlab-ci.yml.tmp && mv .gitlab-ci.yml.tmp .gitlab-ci.yml

      # Commit and push
      git add .gitlab-ci.yml
      git commit -m "XCC-3727: Added 'Check-Code-Coverage-Percentage' stage after 'Maven-Install'"
      git push origin "$BRANCH_NAME"
      echo "Changes pushed to $BRANCH_NAME for $PROJECT_NAME"
    fi
  else
    echo ".gitlab-ci.yml not found in $PROJECT_NAME"
  fi

  # Cleanup
  cd ..

done < gitlab-smartconx-projects.txt
