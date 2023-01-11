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

task_tf-diff(){
    # shellcheck disable=SC2034
    DOC="Outputs 'terraform plan' in a diff format"

    # Stolen from: https://discuss.hashicorp.com/t/get-diff-formatted-file-from-terraform-plan/4757/3

    # Get plan
    terraform plan -out="${TMPDIR}/tfplan" > /dev/null 2>&1

    # Convert plan to json
    CHANGES=$(terraform show -json "${TMPDIR}"/tfplan | jq '.resource_changes[].change')

    # Diff before and after with newlines expanded
    diff -u \
    <(echo "$CHANGES" | jq '.before' | sed 's/\\n/\
    /g') \
    <(echo "$CHANGES" | jq '.after' | sed 's/\\n/\
    /g')
}
