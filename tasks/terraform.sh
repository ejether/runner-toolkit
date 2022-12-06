task_tf-diff(){
    DOC="Outputs 'terraform plan' in a diff format"

    # Stolen from: https://discuss.hashicorp.com/t/get-diff-formatted-file-from-terraform-plan/4757/3

    # Get plan
    terraform plan -out=$TMPDIR/tfplan > /dev/null 2>&1

    # Convert plan to json
    CHANGES=$(terraform show -json $TMPDIR/tfplan | jq '.resource_changes[].change')

    # Diff before and after with newlines expanded
    diff -u \
    <(echo "$CHANGES" | jq '.before' | sed 's/\\n/\
    /g') \
    <(echo "$CHANGES" | jq '.after' | sed 's/\\n/\
    /g')
}
