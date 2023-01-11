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

function task_git-open-repo(){
    # shellcheck disable=SC2034
    DOC="Opens the web url of the repository you are currently in."
    git rev-parse --is-inside-work-tree > /dev/null || { runner_log_error "Not a git repo"; return 1; }
    url=https://$(git remote -v | head -n1 | awk '{ print $2 }' | sed 's/git\@//' | tr ":" "/" | sed 's/\.git//')
    runner_log_notice "Opening ${url}"
    open "${url}"
}
