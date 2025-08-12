#!/bin/bash
set -e

GITLAB_URL="gitlab-italent.com" # provide the url without https 
RUN_ALL_PIPELINES_PROJECT_ID=6534 # used to add to the allowlist of every project, so that $CI_JOB_TOKEN token is able to trigger pipeline
GROUP_LEVEL_ACCESS_TOKEN=${GROUP_LEVEL_ACCESS_TOKEN} # access token generated a group level
GROUP_ID=9122  # provide XCOP group id
SOURCE_CODE_BRANCH=${SOURCE_CODE_BRANCH}
# provide variables to running pipeline
ENVIRONMENT_TO_DEPLOY=${environment}


## Add configurations project to CI/CD JOB token list for a  service project to allow access to trigger pipeline from configurations project
getProjectNameUsingID() {
    PROJECT_ID=$1  # Replace with your project ID

    curl -s --header "PRIVATE-TOKEN: ${GROUP_LEVEL_ACCESS_TOKEN}" \
     --request GET "https://${GITLAB_URL}/api/v4/projects/$PROJECT_ID" | jq -r '.name'

}



## POST /projects/:id/trigger/pipeline
triggerProjectPipeline() {
    echo "Triggering Pipeline for the project $2"

    # Capture only the HTTP status code
    STATUS_CODE=$(curl -s --write-out "%{http_code}" --output /dev/null \
        --request POST \
        --form "token=${CI_JOB_TOKEN}" \
        --form "ref=${SOURCE_CODE_BRANCH}" \
        -F "variables[environment]=${ENVIRONMENT_TO_DEPLOY}" \
        "https://${GITLAB_URL}/api/v4/projects/$1/trigger/pipeline")

    if [[ "$STATUS_CODE" == "201" ]]; then
        echo "Successfully triggered Pipeline for the $2 project"
    else
        echo "Failed to trigger Pipeline for the $2 project (HTTP Status: $STATUS_CODE)"
        exit 1
    fi
}

## GET /projects/:id/job_token_scope/allowlist
getListofAllowListForProject() {
    response=$(curl -s --header "PRIVATE-TOKEN: ${GROUP_LEVEL_ACCESS_TOKEN}" "https://${GITLAB_URL}/api/v4/projects/$1/job_token_scope/allowlist")
    if [[ -n $response ]]; 
    then
        REQUIRED_PROJECT_ID=$(echo $response | jq --arg RUN_ALL_PIPELINES_PROJECT_ID "$RUN_ALL_PIPELINES_PROJECT_ID" '.[] | select(.id == ($RUN_ALL_PIPELINES_PROJECT_ID | tonumber ))')
        if [[ -n $REQUIRED_PROJECT_ID ]];
        then
            echo "true"
        else
            echo "false"
        fi
    fi
}

## POST /projects/:id/job_token_scope/allowlist
addProjectToJobTokenPermissions() {
    response=$(curl -s --request POST \
        --url "https://${GITLAB_URL}/api/v4/projects/$1/job_token_scope/allowlist" \
        --header "PRIVATE-TOKEN: ${GROUP_LEVEL_ACCESS_TOKEN}" \
        --header "Content-Type: application/json" \
        --data "{ \"target_project_id\": \"${RUN_ALL_PIPELINES_PROJECT_ID}\" }")
    targetProjectId=$(echo $response | jq '.target_project_id')
    if [[ "$RUN_ALL_PIPELINES_PROJECT_ID" == "${targetProjectId}" ]];
    then
        echo "SucessFully Added Run-All-Pipelines Project with ID ${RUN_ALL_PIPELINES_PROJECT_ID} to the $2 Project with ID $1}"
        echo "Trigger Pipeline for the project $2"
        triggerProjectPipeline "$1" "$2"
    else
        echo "Failed to Add Run-All-Pipelines Project with ID ${RUN_ALL_PIPELINES_PROJECT_ID} to the $2 Project with ID $1 with error: ${response}"
        exit 1
    fi
}


checkAllowListAndTriggerPipeline() {

    local GITLAB_PROJECT_ID=$1   
    local SERVICE_NAME=$2
    
    echo "Adding project ID $GITLAB_PROJECT_ID to the allowlist for the $SERVICE_NAME project"
    isProjectAdded=$(getListofAllowListForProject "$GITLAB_PROJECT_ID")
    if [[ "$isProjectAdded" == "true" ]];
    then
        echo "The Run-All-Pipelines project already exists in ${SERVICE_NAME} ${GITLAB_PROJECT_ID} project job token allowlist"
        triggerProjectPipeline "$GITLAB_PROJECT_ID" "$SERVICE_NAME"
    else
        echo "Run-All-Pipelines project does not exsits in ${SERVICE_NAME} ${GITLAB_PROJECT_ID} project job token allowlist, so adding to allowlist"
        addProjectToJobTokenPermissions "$GITLAB_PROJECT_ID" "$SERVICE_NAME"
    fi
}



# listProjectsInGroup() {

#     page=1
#     total_pages=1

#     #GET /groups/:id/projects
#     while [ "$page" -le "$total_pages" ]; do
#         response=$(curl -s -D headers.txt \
#         --header "PRIVATE-TOKEN: ${GROUP_LEVEL_ACCESS_TOKEN}" \
#         "https://${GITLAB_URL}/api/v4/groups/${GROUP_ID}/projects?per_page=${PER_PAGE}&page=${page}")


#         # Append project IDs and names to arrays using a loop
#         while IFS= read -r name; do
#             if [[ "$name" == "Configurations"  || "$name" == "commonModelsService" ]]; then
#                 echo "Don't run $name"
#             else
#                 echo "Adding Project $name into the array"
#                 project_names+=("$name")
#             fi
#         done < <(echo "$response" | jq -r '.[].name')
        
        
#         while IFS= read -r id; do
#             if [[ "$id" == "5819" || "$id" == "5759" || "$id" == "5763" ]]; then
#                 echo "************************************************"
#                 echo "Don't run $id"
#             else
#                 project_ids+=("$id")
#                 echo "Adding project_id $id into the array"
#                 # Capture the project name from the function
#                 project_name=$(getProjectNameUsingID "$id")

#                 # Handle empty project name (API failure or invalid ID)
#                 if [[ -z "$project_name" || "$project_name" == "null" ]]; then
#                     echo "Warning: Failed to fetch project name for ID $id"
#                     continue
#                 fi

#                 # Pass the project ID and project name to the function
#                 checkAllowListAndTriggerPipeline "$id" "$project_name"
#                 # checkAllowListAndTriggerPipeline "$id" "${project_names[-1]}"
#             fi
#         done < <(echo "$response" | jq -r '.[].id')

#         # Get pagination details from headers
#         total_pages=$(grep -i '^x-total-pages:' headers.txt | awk '{print $2}' | tr -d '\r')
#         echo "Fetched page $page of $total_pages"
#         rm -rf headers.txt
#         sleep 10
#         ((page++))
#     done

# }


## MAIN Logic Entry Point ###

while read -r id name; do
        # Skip header and END line
        if [[ "$id" == "PROJECT_ID" || "$id" == "END" ]]; then
            continue
        fi
        echo "Triggering pipeline for project: $id - $name"
        checkAllowListAndTriggerPipeline "$id" "$name"
done < "projects_list.txt"

echo "using source code branch ${SOURCE_CODE_BRANCH} in  enviornment ${ENVIRONMENT_TO_DEPLOY}"
env


# listProjectsInGroup
