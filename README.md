# runner-toolkit
An easy way to use stylemistake/Runner with some handy helpers built in.

## Description

I'm a big fan of `runner` but I found myself repeating a lot of helper functions and install structures when using it in different ways.  The `runner-toolkit` provides some helper functionality and some opinionated but configurable structure to assist the next time I setup a project or team with `runner`

## Requirements

1. Install [runner](https://github.com/stylemistake/runner)

## Initialization

1. Configure shell:
    1. From the root of the repo: `eval $(bash ./setup.sh)` or, to make enable it permanently use `bash ./setup.sh >> .bash_profile` (or equivalent for your shell)
    1. **If you move your code directory or rename any files, you'll need to re-run the above steps**

1. If you want to use this as another command you can set `RUNNER_TOOLKIT_ALIAS` before running `./setup.sh` and it will alias the command and configure shell completion for the alias as well.

1. If you want to designate other locations you can set `RUNNER_TOOLKIT_TASK_LOCATIONS` as a `:` delimited string (like `$PATH`)  before running `./setup.sh` or edit the output of `./setup.sh` accordingly. Members of the list may be files or directories or a mixture of the two. If the members of the list are files, it will include automatically the tasks in that file. If the members of the list are directories, all tasks in all files in the directory will be included. If non-runner files are in the directory, unexpected errors may result.

1. Once configured, all available runner tasks will be available to you, tab completable, in any login shell.

## Update

1. The installation _IS_ this repo. Use `git pull` to get the latest code. That's it. You're done.

## Runner Toolkit Use

1. `runner help` will show you all enabled tasks
1. `runner <task_name>` will run the task or show all the required options
1. `runner <task_name> <--option=value>` will allow you to set options for tasks
1. Autocomplete works when configured properly
1. You may call more than one task in a order

## Best Practices

1. Name new tasks as `<noun>_<verb>` so autocompletion _should_ group tasks for easy discovery
1. Use files in `RUNNER_TOOLKIT_TASK_LOCATIONS` to group tasks
1. Always add a `DOC=` and `required_vars=()` (if appropriate)
1. See [runner documentation](https://github.com/stylemistake/runner#runnerfile) for more advanced use of runner native functions

## Runner Toolkit Helper Tasks
These task are always available when using the runner toolkit.

* `default`: Accepts no arguments. Shows usage information

* `help`: Accepts no arguments. Shows the complete list of available tasks and their DOC string if available

* `show_task`: Accepts `--tasks=<name>`. Outputs the body of the task in case you'd don't feel like hunting for the source code.

## Runner Toolkit Helper Functions
These functions are not runner tasks and you will not see them when using the `runner` command but they are available while writing tasks.

* `parse_args`:
    * Accepts `$@` in the form of "--arg=value" or "--arg" and sets an environment variable of the upper cased "$ARG" with the value. If "--arg" form is used, then the value is "true"
    * Use this with any task you expect to accept args. You can "set -u" in your task to reduce accidental errors due to unset variables
    * Example:
```
function task_parse_args_example(){
    # Accepts --foo and --baz
    parse_args "${@}"
    echo ${FOO}
    echo ${BAZ}
}
```
```
▶ runner parse_args_example --foo=bar --baz
[12:51:04.304] Starting 'parse_args_example'...
FOO=bar
BAZ=true
[12:51:04.346] Finished 'parse_args_example' after 25 ms
```

* `check_required_vars`:
   * Loops over array `$required_args` and ensure that each is set.
   * Errors and Exits if a variable is not set
   * Use by setting a `$required_args` as an array of variable names and then invoke `check_required_vars` at the start of the task
   * Example:
```
function task_required_args_example(){
    DOC="Example task for 'check_required_args'. Requires --foo and --bar."
    required_vars=('FOO' 'BAR')
    parse_args "$@"
    # return 1 is required here for runner to exit with error
    check_required_vars || return 1

    echo "FOO=${FOO}"
    echo "BAZ=${BAZ}"
}
```
```
▶ runner required_args_example
[12:59:19.892] Starting 'required_args_example'...
[12:59:19.906] Missing argument --foo
[12:59:19.913] Missing argument --bar
[12:59:19.928] Task 'required_args_example' failed after 21 ms (1)
```
```
▶ runner required_args_example  --foo
[13:01:08.334] Starting 'required_args_example'...
[13:01:08.355] Missing argument --baz
[13:01:08.370] Task 'required_args_example' failed after 23 ms (1)
```
```
▶ runner required_args_example  --foo=bar --baz
[13:01:00.976] Starting 'required_args_example'...
FOO=bar
BAZ=true
[13:01:01.012] Finished 'required_args_example' after 23 ms
```

* `confirm`
    * Provides a `confirm` function. Will only proceed if "yes" is entered
    * Example:
```
function task_confirm_example(){
    DOC="Example task for 'confirm'."
    runner_colorize red ARE YOU SURE?
    confirm
    runner_colorize green "I guess you're sure"
}
```
```
▶ runner confirm_example
[13:05:17.336] Starting 'confirm_example'...
ARE YOU SURE?
Type "YES" within 10s to proceed: foo

[13:05:19.749] Task will not proceed
```
```
6s ▶ runner confirm_example
[13:05:52.615] Starting 'confirm_example'...
ARE YOU SURE?
Type "YES" within 10s to proceed: YES

I guess you're sure
[13:05:54.010] Finished 'confirm_example' after 1.38 s
```

* `spin`/`unspin`
    * Provides a mini ascii spinner for to bracket long running tasks
    * invoke `spin` before a long running task and invoke `unspin` following it.
    * Example:
```
function task_spinner_example(){
    DOC="Example task for 'spinner' and 'unspin'."
    runner_colorize pink "Starting Sleep"
    spinner
    sleep 10
    unspin
    runner_colorize pint "Stopping"
}
```
```
▶ runner spin_example
[13:13:00.809] Starting 'spin_example'...
Starting Sleep
Stopping
[13:13:10.840] Finished 'spin_example' after 10.1 s
```
