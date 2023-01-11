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

ensure_tsh_login(){
    if ! tsh status; then
      runner_log_warning "Session Expired. Logging in."
      task_tsh-login
    fi
}

task_tsh-use-cluster(){
    parse_args "$@"
    ensure_tsh_login || return 1
    set -e
    KUBECONFIG="$(mktemp)"
    export KUBECONFIG
    # shellcheck disable=SC2034
    workspaces=$(tsh kube ls | tail -n +3 | uniq | awk '{ print $1 }' | sort)
    # shellcheck disable=SC2154
    choice=$(select_from_with_grep "tsh kube ls | tail -n +3 | uniq | awk '{ print \$1 }' | sort"  "${runner_extra_args[0]}")
    tsh kube login "$choice"
    set +e
    $SHELL
    rm "$KUBECONFIG" 2> /dev/null
}

task_tsh-db(){
  parse_args "$@"
  ensure_tsh_login || return 1
  set -e
  choice=$(select_from_with_grep "tsh kube ls | tail -n +3 | uniq | awk '{ print \$1 }' | sort"  "${runner_extra_args[0]}")
  task_tsh-db-workspace --workspace="$choice"

}

task_tsh-login(){
  tsh login --proxy openraven.teleport.sh:443 --auth okta-corp --user ej@openraven.com
}