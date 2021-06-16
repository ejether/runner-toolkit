#!/usr/bin/env bash

function task_git_open_repo(){
    DOC="Opens the web url of the repository you are currently in."
    git rev-parse --is-inside-work-tree > /dev/null || { runner_log_error "Not a git repo"; return 1; }
    url=https://$(git remote -v | head -n1 | awk '{ print $2 }' | sed 's/git\@//' | tr ":" "/" | sed 's/\.git//')
    runner_log_notice "Opening ${url}"
    open "${url}"
}
