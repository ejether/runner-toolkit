task_kshell(){
   kubectl run -i --tty kshell --image=alpine --restart=Never -- /bin/sh
}
