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
    workspaces=$(tsh kube ls | tail -n +3 | uniq | awk '{ print $1 }' | sort)
    choice=$(select_from_with_grep "tsh kube ls | tail -n +3 | uniq | awk '{ print \$1 }' | sort"  ${runner_extra_args[0]})
    tsh kube login "$choice"
    set +e
    $SHELL
    rm "$KUBECONFIG" 2> /dev/null
}

task_tsh-db(){
  parse_args "$@"
  ensure_tsh_login || return 1
  set -e
  choice=$(select_from_with_grep "tsh kube ls | tail -n +3 | uniq | awk '{ print \$1 }' | sort"  ${runner_extra_args[0]})
  task_tsh-db-workspace --workspace="$choice"

}

task_tsh-login(){
  tsh login --proxy openraven.teleport.sh:443 --auth okta-corp --user ej@openraven.com
}