#!/bin/bash

source "./helpers.sh"

_echo "Run 10 set of commands concurrently (~ in parallel)"
_echo "Wait till all commands completed"
_echo "Check if any command ended with error"

# Set initial wait number equal to concurrent bash processes
workers=10
_waitInit $workers

for i in $(eval echo "{1..$workers}"); do
    
    # This set of commands will be executed in a separate process (sub-process)
    (        
        echo "$i: doing long command ..." && sleep 1; _waitIfErr "$i: failed"
        echo "$i: success"
        _waitDone
        
        # _waitIfErr can be omitted if there is no need to check exit code of the last executed command
    ) &
    
done

# Wait till all commands completed. Check if any command ended with error.
_wait || _err "There were errors"

_echo "Success"
