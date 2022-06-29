#!/bin/bash

TIME_START=$(date +%s)
SCRIPT_DIR="$(dirname `readlink -f "$0"`)"
source "$SCRIPT_DIR/helpers.sh"

_echo "Run 10 set of commands concurrently (~ in parallel)"
_echo "Wait till all commands completed"
_echo "Check if any command ended with error"

# Set initial wait number equal to concurrent bash processes
workers=10
waitInit $workers

for i in $(eval echo "{1..$workers}"); do
    
    # This set of commands will be executed in a separate process (sub-process)
    (        
        _echo "$i: doing long command ..." && sleep 1; waitIfErr "$i: failed"
        _echo "$i: success"
        waitDone
        
        # waitIfErr can be omitted if there is no need to check exit code of the last executed command
    ) &
    
done

# Wait till all commands completed. Check if any command ended with error.
waitGroup || _err "There were errors"

timeTaken=$(( $(date +%s) - $TIME_START ))
_echo "All done ($timeTaken sec)"
