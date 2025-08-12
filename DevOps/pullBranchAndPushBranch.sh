#!/bin/bash

REPO_BASE_URL="https://gitlab-italent.com/italentdev/XCOP"  # Adjust this
PROJECTS_FILE="gitlab-smartconx-projects.txt"
BRANCH="XCC-3727"
LOGLEVEL_BRANCH="loglevel"
COMMIT_MSG="Updated log level changes and code coverage stage for selected projects"

while read -r project; do
  echo "Processing $project..."

  # Clone project if not already present
  if [ ! -d "$project" ]; then
    git clone "$REPO_BASE_URL/$project.git"
  fi

  cd "$project" || continue

  # Checkout and pull XCC-3727
  git checkout $BRANCH 2>/dev/null || git checkout -b $BRANCH origin/$BRANCH
  git pull origin $BRANCH --no-edit

  # Pull and optionally merge loglevel branch
  git fetch origin $LOGLEVEL_BRANCH
  git merge origin/$LOGLEVEL_BRANCH --no-edit

  # === MAKE YOUR CHANGES HERE ===
  # For example, change log level in properties file:
  # sed -i 's/log.level=.*$/log.level=INFO/' config/app.properties

  # Commit and push
  git add .
  git commit -m "$COMMIT_MSG"
  git push origin $BRANCH

  cd ..
done < "$PROJECTS_FILE"