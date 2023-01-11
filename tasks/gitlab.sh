#!/usr/bin/env bash

# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

gitlab_api_call(){
  curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://gitlab.com/api/v4/${1}"
}

gitlab_project_name(){
  git remote -v | head -n1 | awk '{ print $2 }' | sed 's/git\@//' | tr ":" "/" | sed 's/\.git//' | sed 's/gitlab.com\///' | sed 's/\//%2F/g'
}

gitlab_project_id(){
  gitlab_api_call "projects/$(gitlab_project_name)" | jq -r '.id'
}

task_gitlab-groups(){
  gitlab_api_call "groups"
}

# shellcheck disable=SC2120
task_gitlab-group-projects(){
  parse_args "$@"
  required_vars=('GROUP_ID')
  check_required_vars || return 1
  gitlab_api_call "groups/${GROUP_ID}" | jq '.projects  '
}

task_gitlab-project(){
  parse_args "$@"
  required_vars=('PROJECT_ID')
  check_required_vars || return 1
  gitlab_api_call "projects/${PROJECT_ID}"
}

task_gitlab-project-id(){
  gitlab_project_id
}

task_gitlab-group(){
  parse_args "$@"
  required_vars=('GROUP_ID')
  check_required_vars || return 1
  gitlab_api_call "groups/${GROUP_ID}"
}

task_gitlab-project-variables(){
  parse_args "$@"
  required_vars=('PROJECT_ID')
  check_required_vars || return 1
  gitlab_api_call "projects/${PROJECT_ID}/variables"
}

task_gitlab-group-variables(){
  parse_args "$@"
  required_vars=('GROUP_ID')
  check_required_vars || return 1
  gitlab_api_call "groups/${GROUP_ID}/variables"
}

task_gitlab-project-variable(){
  parse_args "$@"
  required_vars=('PROJECT_ID' 'VARIABLE_KEY')
  check_required_vars || return 1
  gitlab_api_call "projects/${PROJECT_ID}/variables/${VARIABLE_KEY}"
}

task_gitlab-group-variable(){
  parse_args "$@"
  # shellcheck disable=SC2034
  required_vars=('GROUP_ID' 'VARIABLE_KEY')
  check_required_vars || return 1
  gitlab_api_call "groups/${GROUP_ID}/variables/${VARIABLE_KEY}"
}

task_gitlab-get-all-aws-key-ids(){
  echo GROUP_ID, PROJECT_ID, KEY_ID
  for GROUP_ID in $(task_gitlab-groups | jq -r  '.[].id'); do
    PROJECT_ID="None"
    output_group_project_var "$(task_gitlab-group-variable --variable-key=AWS_ACCESS_KEY_ID | jq '.value')"
    for PROJECT_ID in $(task_gitlab-group-projects | jq -r '.[].id'); do
      output_group_project_var "$(task_gitlab-project-variable --variable-key=AWS_ACCESS_KEY_ID | jq '.value')"
    done
  done
}

output_group_project_var(){
  if [ "${1}" != 'null' ]; then
  echo "$GROUP_ID, $PROJECT_ID, ${1}"
  fi
}

gitlab_pre_tf(){
  ENV=$(basename "$(pwd)")
  if [[ -e "${ENV}.env" ]]; then
    # shellcheck disable=SC1090  # Unused variables left for readability
    source  "${ENV}.env"
  fi
  default_state_name="$(gitlab_project_name)-${ENV}"
  TF_STATE_NAME=${TF_STATE_NAME:-${default_state_name}}
  export TF_STATE_NAME
}

task_gitlab-tf-init(){

  TF_PROJECT_ID=$(gitlab_project_id)
  parse_args "$@"
  if [[ ! -e "main.tf" ]] && [[ ! -e "${ENV}.env" ]]; then
    runner_log_error "Are you sure you're in the right place?"
    exit 1
  fi

  gitlab_pre_tf

  runner_log_notice "Using ProjectID: $TF_PROJECT_ID and State Name: $TF_STATE_NAME."

  if [ -n "${RECONFIGURE}" ]; then
    RECONFIGURE_ARG="-reconfigure"
  fi

  terraform init "${RECONFIGURE_ARG}" \
    -backend-config="address=https://gitlab.com/api/v4/projects/${TF_PROJECT_ID}/terraform/state/${TF_STATE_NAME}" \
    -backend-config="lock_address=https://gitlab.com/api/v4/projects/${TF_PROJECT_ID}/terraform/state/${TF_STATE_NAME}/lock" \
    -backend-config="unlock_address=https://gitlab.com/api/v4/projects/${TF_PROJECT_ID}/terraform/state/${TF_STATE_NAME}/lock" \
    -backend-config="username=${GTILAB_USER}" \
    -backend-config="password=${GITLAB_TOKEN}" \
    -backend-config="lock_method=POST" \
    -backend-config="unlock_method=DELETE" \
    -backend-config="retry_wait_min=5"
}

task_gitlab-tf-plan(){
  gitlab_pre_tf
  terraform plan
}