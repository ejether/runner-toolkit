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

pushd $(dirname "${BASH_SOURCE[0]}")
DEFAULT_TASK_LOCATIONS="$(pwd)"/tasks

echo "## Paste this output into your shell files to be sourced at startup"
echo "# This can be configured with environment variables"
echo "export runner_file=$(pwd)/Runnerfile"
# Colon delimited paths where task files are located
echo "export RUNNER_TOOLKIT_TASK_LOCATIONS=${DEFAULT_TASK_LOCATIONS}:${RUNNER_TOOLKIT_TASK_LOCATIONS}"
echo "eval \$(runner --completion=bash)"

if [ -n "${RUNNER_TOOLKIT_ALIAS}" ]; then
    echo "alias ${RUNNER_TOOLKIT_ALIAS}=runner"
    echo "complete -F _runner_completions ${RUNNER_TOOLKIT_ALIAS}"
fi
