#!/bin/bash

#https://gitlab-italent.com/italentdev/XCOP/configurations.git
GITLAB_BASE_URL="https://gitlab-italent.com/italentdev/XCOP"  # Replace with actual GitLab group
BRANCH_NAME="XCC-3829"
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
    echo "Checking for $PROJECT_NAME..."
    serviceName=$(yq '.variables.service_name' .gitlab-ci.yml)
    echo "Serivce Name for $serviceName..."
    rm -rf .gitlab-ci.yml
    cp ../.gitlab-ci.yml .gitlab-ci.yml
    # sed 's|CI_PROJECT_NAME|$service_name| g' .gitlab-ci.yml
    # yq e -i '.spec.template.spec.containers[0].env[1].value = "'${MONGODB_ROOT_PASSWORD}'"' deployment.yaml
    yq e -i '.variables.service_name = "'${serviceName}'"' .gitlab-ci.yml

    cat .gitlab-ci.yml


    # Commit and push
    git add .gitlab-ci.yml
    git commit -m "XCC-3829: Added 'new compontents for dev'"
    git push origin "$BRANCH_NAME"
    echo "Changes pushed to $BRANCH_NAME for $PROJECT_NAME"

  else
    echo ".gitlab-ci.yml not found in $PROJECT_NAME"
  fi

  # Cleanup
  cd ..

done < gitlab-smartconx-projects.txt