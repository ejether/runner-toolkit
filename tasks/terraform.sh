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

task_tf-diff() {
  # shellcheck disable=SC2034
  DOC="Outputs 'terraform plan' in a diff format"

  # Stolen from: https://discuss.hashicorp.com/t/get-diff-formatted-file-from-terraform-plan/4757/3

  # Get plan
  terraform plan -out="${TMPDIR}/tfplan" >/dev/null 2>&1

  # Convert plan to json
  CHANGES=$(terraform show -json "${TMPDIR}"/tfplan | jq '.resource_changes[].change')

  # Diff before and after with newlines expanded
  diff -u \
    <(echo "$CHANGES" | jq '.before' | sed 's/\\n/\
    /g') \
    <(echo "$CHANGES" | jq '.after' | sed 's/\\n/\
    /g')
}

task_tg-diff() {
  # shellcheck disable=SC2034
  DOC="Outputs 'terraform plan' in a diff format"

  # Stolen from: https://discuss.hashicorp.com/t/get-diff-formatted-file-from-terraform-plan/4757/3

  # Get plan
  terragrunt plan -out="${TMPDIR}/tfplan" >/dev/null 2>&1

  # Convert plan to json
  CHANGES=$(terragrunt show -json "${TMPDIR}"/tfplan | jq '.resource_changes[].change')

  # Diff before and after with newlines expanded
  diff -u \
    <(echo "$CHANGES" | jq '.before' | sed 's/\\n/\
    /g') \
    <(echo "$CHANGES" | jq '.after' | sed 's/\\n/\
    /g')
}

task_terraform-format() {
  DOC="Recursively Lints and Formats Terraform and HCL files from the root of whatever repo you're in"

  GIT_ROOT="$(git rev-parse --show-toplevel)"
  pushd "${GIT_ROOT}" >/dev/null

  echo "Linting everything!"
  command -v terraform >/dev/null &&
    terraform fmt -recursive ./ ||
    echo "Terraform Not installed. Not Running 'terraform fmt'"
  command -v terragrunt >/dev/null &&
    terragrunt hclfmt ./ ||
    echo "Terragrunt Not installed. Not Running 'terragrunt hclfmt'"
  command -v tflint >/dev/null &&
    tflint --recursive ||
    echo "Tflint Not installed. Not Running 'tflint'"

  git diff --exit-code >/dev/null || (
    echo "There are uncommited changes. Don't forget to commit them!"
    exit 1
  )
  echo Done.
}

task_terraformn-doc() {
  DOC="Runs terrafrom-docs on every module in '/modules'"

  # Runs terraform-doc in a docker container to create module documentation
  # For each module in `modules/*/*` directory

  GIT_ROOT=$(git rev-parse --show-toplevel)
  pushd "${GIT_ROOT}" >/dev/null

  # for each module in `modules `
  # this will break if we re-organize the modules directory
  for module in */*/; do
    echo "Generating documents for: ${module}"
    docker run \
      --platform linux/amd64 \
      --rm \
      --volume "$(pwd)/${module}:/module" \
      -u "$(id -u)" \
      quay.io/terraform-docs/terraform-docs:0.16.0 \
      markdown /module --output-file README.md

  done
}

task_terragrunt-clean() {
  DOC="Removes all terragrunt cache files and lock files"
  "Handy when you're searching or grepping and your results keep"
  "getting polluted by the cache dirs"

  GIT_ROOT=$(git rev-parse --show-toplevel)
  pushd "${GIT_ROOT}"

  find . -type d -name '.terragrunt-cache' -exec rm -rf {} \;
  find . -type f -name '.terraform.lock.hcl' -exec rm -rf {} \;

}
