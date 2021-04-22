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

function task_parse_args_example(){
    DOC="Example task for 'parse_args'. Accepts --foo and --baz; outputs the values."
    parse_args "${@}"
    echo "FOO=${FOO}"
    echo "BAZ=${BAZ}"
}

function task_required_args_example(){
    DOC="Example task for 'check_required_args'. Requires --foo and --baz."
    required_vars=('FOO' 'BAZ')
    parse_args "$@"
    # return 1 is required here for runner to exit with error
    check_required_vars || return 1

    echo "FOO=${FOO}"
    echo "BAZ=${BAZ}"
}

function task_confirm_example(){
    DOC="Example task for 'confirm'."
    runner_colorize red ARE YOU SURE?
    confirm
    runner_colorize green "I guess you're sure"
}

function task_spin_example(){
    DOC="Example task for 'spinner' and 'unspin'."
    runner_colorize pink "Starting Sleep"
    spin
    sleep 10
    unspin
    runner_colorize pint "Stopping"
}