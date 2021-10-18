ORVN_CODE_PATH="${HOME}/code/openraven"

ensure_tsh_login(){
    if ! tsh status; then
      runner_log_warning "Session Expired. Logging in."
      task_tsh-login
    fi
}

# shellcheck disable=SC2120
task_orvn-synch(){
    parse_args "$@"
    ensure_aws_login || return 1
    yawsso --profile "${AWS_PROFILE}"
    orvn sync -r --env-name="${AWS_PROFILE}"
}

task_orvn-synch-all(){
    rm "${HOME}/.kube/config" 2>/dev/null || true
    for AWS_PROFILE in $(aws configure list-profiles | grep -v default); do
        export AWS_PROFILE
        runner_log_notice "Synching Clusters for ${AWS_PROFILE}"
        task_orvn-synch
    done
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

task_use-cluster(){
    parse_args "$@"
    ensure_aws_login || return 1
    set -e
    KUBECONFIG="$(mktemp)"
    export KUBECONFIG
    cp ~/.kube/config "$KUBECONFIG"
    context=$(select_from_with_grep "kubectl config get-contexts  --output=name" ${runner_extra_args[0]})
    kubectl config use-context "${context}"
    set +e
    $SHELL
    rm "$KUBECONFIG" 2> /dev/null
}

task_use-saas-cluster(){
    parse_args "$@"
    task_use-cluster --aws-profile=saas
}

task_use-staging-cluster(){
    parse_args "$@"
    task_use-cluster --aws-profile=saas-staging
}

task_orvn-get-splunk-admin-creds(){
    echo
    echo "admin"
    kubectl -n splunk get secrets splunk-splunk-secret -o jsonpath='{.data.password}' | base64 -d
    echo
    echo
}

task_clone(){
    parse_args "$@"
    required_vars=('REPO')
    check_required_vars || return 1
    REPO_PATH=$(echo "$REPO" | sed 's/git@gitlab.com:openraven\///' | sed 's/\.git//')
    PARENT_PATH=$(dirname "${ORVN_CODE_PATH}/${REPO_PATH}")
    mkdir -p "${PARENT_PATH}"
    cd "${PARENT_PATH}" || return 1
    git clone "${REPO}" || return 1
}
#journalctl --no-hostname -f -u boot0.service

task_orvn-show-git(){
    tree -L 2 -d "${ORVN_CODE_PATH}"
}


task_orvn-show-my-vpcs(){
    parse_args "$@"
    export AWS_PROFILE="saas-staging"
    ensure_aws_login || return 1
    aws ec2 describe-vpcs --filters Name=tag:OrgSlug,Values='*ej*' | jq '.Vpcs[].VpcId' -r
}

task_tsh-db-workspace(){
      parse_args "$@"
      USER="orvn_superuser"
      DATABASE="orvn"
      tsh db login "$WORKSPACE"
      eval "$(tsh db env --db="$WORKSPACE")"
      psql -U $USER $DATABASE
}

task_tsh-db(){

  parse_args "$@"
  choice=$(select_from_with_grep "tsh kube ls | tail -n +3 | uniq | awk '{ print \$1 }' | sort"  ${runner_extra_args[0]})
  task_tsh-db-workspace --workspace="$choice"

}


task_pg-proxy(){
# DEPRECATED Method to connect to a workspace's postgress. Superceded by tsh-db

    PG_LOCAL_PROXY_PORT=$(shuf -i 20000-30000 -n 1)
    PAGER=""

    parse_args "$@"

    pf_pid="$(ps -ef | grep port-forward | grep $PG_LOCAL_PROXY_PORT | awk '{ print $2 }')"
    if [ -n "${pf_pid}" ]; then
      runner_log_warning "It appears you already have a port-forward command on this port: $PG_LOCAL_PROXY_PORT. You should kill it."
      runner_log_warning "PID: $pf_pid"
      return 1
    fi

    type psql >/dev/null || { runner_log_error "'psql' is required and is missing"; return 1; }

    secret_data=$(kubectl get -n ui secret jdbc-env -o jsonpath='{.data}')

    export pg_host=$(echo ${secret_data} | jq -r '.SPRING_DATASOURCE_URL' | base64 -d  | sed 's/jdbc:postgresql:\/\///' | sed 's/:5432\/orvn//')
    export PGPASSWORD=$(echo ${secret_data} | jq -r '.SPRING_DATASOURCE_PASSWORD' | base64 -d  )
    export DATABASE='orvn'
    export USER='root'

cat << EOF | kubectl apply -f -
---
apiVersion: v1
kind: Namespace
metadata:
  name: pg-proxy
  labels:
    app.kubernetes.io/name: pg-proxy
spec:
  finalizers:
  - kubernetes

---
apiVersion: v1
kind: Service
metadata:
  name: pg-proxy
  namespace: pg-proxy
  labels:
    app.kubernetes.io/name: pg-proxy
spec:
  ports:
    - name: postgres
      protocol: TCP
      port: 5432
      targetPort: 5432
  type: ExternalName
  externalName: ${pg_host}

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pg-proxy
  namespace: pg-proxy
  labels:
    app: pg-proxy
    app.kubernetes.io/name: pg-proxy
spec:
  selector:
    matchLabels:
      app: pg-proxy
  template:
    metadata:
      labels:
        app: pg-proxy
        app.kubernetes.io/name: pg-proxy
    spec:
      containers:
      - name: pg-proxy
        imagePullPolicy: Always
        image: tecnativa/tcp-proxy:latest
        env:
          - name: LISTEN
            value: ":5432"
          - name: TALK
            value: "pg-proxy.pg-proxy.svc.cluster.local:5432"
          - name: TIMEOUT_CLIENT
            value: 30m
          - name: TIMEOUT_SERVER
            value: 30m
          #- name: TIMEOUT_SERVER_FIN
          #  value: 30m
          #- name: TIMEOUT_CLIENT_FIN
          #  value: 30m
          - name: TIMEOUT_TUNNEL
            value: 30m
EOF

    while true; do
        kubectl -n pg-proxy get pods | grep pg-proxy | grep -q Running && break
        sleep 3
        echo -n .
    done
    echo

    kubectl -n pg-proxy port-forward "$(kubectl -n pg-proxy get pods --selector=app=pg-proxy -o   jsonpath='{.items[*].metadata.name}')" "$PG_LOCAL_PROXY_PORT":5432 &

    while true; do
      nc -vz localhost "$PG_LOCAL_PROXY_PORT" 2>/dev/null && break
      echo "Port-forward not ready yet"
      sleep 1
    done;
    export PAGER
    psql -U $USER -d $DATABASE -h localhost -p "$PG_LOCAL_PROXY_PORT"
    pf_pid="$(ps -ef | grep port-forward | grep $PG_LOCAL_PROXY_PORT | awk '{ print $2 }')"
    echo killing $pf_pid
    kill $pf_pid
    kubectl delete ns pg-proxy &
}

task_etag-reset(){
  kubectl exec -it -n kafka kafka-zookeeper-0 -- /bin/bash zkCli.sh set /config/application/openraven/upgrades/etag "" || return 1
}

task_kafka-offset-reset(){
  runner_log_notice "Fetching Kafka Groups"
  kubectl exec -it -n kafka pod/kafka-0 -- kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --all-groups
  read -re -p "Enter Group: " GROUP
  read -re -p "Enter Topic: " TOPIC

  kubectl exec -it -n kafka pod/kafka-0 -- kafka-consumer-groups.sh --bootstrap-server localhost:9092 --reset-offsets --to-latest --topic ${TOPIC} --group ${GROUP} --dry-run
  confirm "Does this look right?"

  kubectl exec -it -n kafka pod/kafka-0 -- kafka-consumer-groups.sh --bootstrap-server localhost:9092 --reset-offsets --to-latest --topic ${TOPIC} --group ${GROUP} --execute
}

task_zk-shell(){
  kubectl exec -it -n kafka kafka-zookeeper-0 -- /bin/bash zkCli.sh
}

task_zk-status(){
  for pod in $(kubectl get pods -n kafka -o name | grep zookeeper); do
    echo "$pod"
    kubectl exec -it -n kafka "$pod" -- /bin/bash zkServer.sh status
  done
}

task_zk_disable_scheduling(){
  kubectl exec -n kafka kafka-zookeeper-0 -- /opt/bitnami/zookeeper/bin/zkCli.sh set /config/application/openraven/app/v1/dmap/scheduling/enabled false
  kubectl exec -n kafka kafka-zookeeper-0 -- /opt/bitnami/zookeeper/bin/zkCli.sh set /config/application/openraven/app/v1/s3/scheduling/enabled false
}

task_deployed-helmfiles-sha(){
  MANIFEST="https://openraven-deploy-rds.s3.us-west-2.amazonaws.com/charts/manifest.json"
  SHA=$(curl -s "${MANIFEST}" | jq -r '.helmfile_git_ref')
  URL="https://gitlab.com/openraven/open/helm-charts/helmfiles/-/tree/${SHA}"
  open ${URL}
  runner_log_notice "Current Production Helmfiles at ${SHA}"
}


task_remove-splunk-crds(){
  task_orvn-synch-all
  for ctx in $(kubectl config get-contexts -o name); do
    echo $ctx
    cmd="kubectl --context ${ctx} delete \
    customresourcedefinition \
    clustermasters.enterprise.splunk.com \
    indexerclusters.enterprise.splunk.com \
    licensemasters.enterprise.splunk.com \
    searchheadclusters.enterprise.splunk.com \
    sparks.enterprise.splunk.com \
    standalones.enterprise.splunk.com"
    ${cmd}
  done
}

task_list-all-namespaces(){
  task_orvn-synch-all
  for ctx in $(kubectl config get-contexts -o name); do
    echo $ctx
    cmd="kubectl --context ${ctx} get ns"
    ${cmd}
  done
}

task_tsh-login(){
  tsh login --proxy openraven.teleport.sh:443 --auth okta-corp --user ej@openraven.com
}

task_staging-contexts(){
  kubectl config get-contexts -o name | grep @saas-staging
}

task_saas-contexts(){
  kubectl config get-contexts -o name | egrep @saas$
}

task_tsh-contexts(){
  kubectl config get-contexts -o name | egrep openraven.teleport.sh-
}

task_kshell(){
   kubectl run -i --tty kshell --image=alpine --restart=Never -- /bin/sh
}

task_set-deploy-channel(){
  parse_args "$@"
  required_vars=('DEPLOY_CHANNEL')
  check_required_vars || return
  kubectl set env -n cluster-upgrade deployment/cluster-upgrade  OPENRAVEN_UPGRADES_NAME="$DEPLOY_CHANNEL" $EXTRA_ARGS
  task_etag-reset
}

task_aws-generate-sso-profiles(){

  config_file="$HOME/.aws/config.generated"
  rm $config_file || true
  echo "# Auto Generated by ravn " > $config_file

cat << EOF >> $config_file
[default]
region=us-west-2
output=json

[profile root]
sso_start_url = https://openraven.awsapps.com/start
sso_region = us-east-1
sso_account_id = 487193801865
sso_role_name = AdministratorAccess


EOF

  export AWS_PROFILE='root'
  ensure_aws_login || return 1
  yawsso --profile "root"

  for account in $(aws organizations list-accounts | jq -r '.Accounts[] | @base64'); do

    account_name=$(echo $account | base64 -d | jq -r '.Name' | tr '[:upper:]' '[:lower:]' | tr ' ' '-'  | tr -cd '[:alnum:]._-')
    account_id=$(echo $account | base64 -d | jq -r '.Id')

    cat << EOF >> $config_file

[profile $account_name]
sso_start_url = https://openraven.awsapps.com/start
sso_region = us-east-1
sso_account_id = $account_id
sso_role_name = AdministratorAccess

EOF

  done
  mv $config_file $HOME/.aws/config
}

task_onica-stacks(){
  for account in $(cat onica-external-ids.json | jq  -r '. | @base64'); do
    account_name=$(echo $account | base64 -d | jq -r '.name' | tr '[:upper:]' '[:lower:]' | tr ' ' '-'  | tr -cd '[:alnum:]._-')
    account_id=$(echo $account | base64 -d | jq -r '.number')
    external_id=$(echo $account | base64 -d | jq -r '.ExID')

    export AWS_PROFILE=$account_name
    export AWS_REGION=us-east-1
    ensure_aws_login || return 1
    runner_log_notice "Createing RackspaceMemberLimited Stack in $AWS_REGION of $AWS_PROFILE"
    aws cloudformation create-stack \
      --stack-name "RackspaceMemberLimited" \
      --template-url https://rackspace-optimizer-plus.s3.amazonaws.com/templates/RackspaceMemberLimited.yaml \
      --parameters="ParameterKey=ExternalID,ParameterValue=$external_id" \
      --capabilities="CAPABILITY_NAMED_IAM"

    runner_log_notice "Createing CloudHealth Stack in $AWS_REGION of $AWS_PROFILE"
    aws cloudformation create-stack \
      --stack-name "CloudHealth" \
      --template-url https://rackspace-optimizer-plus.s3.amazonaws.com/templates/RackspaceCloudHealthRoleMember.template \
      --parameters="ParameterKey=ExternalID,ParameterValue=a6df1e013c9d77218bdf0dc70a39ff" \
      --capabilities="CAPABILITY_NAMED_IAM"

  done
}