#!/bin/bash

source "./helpers.sh"

_echo "Run 10 set of commands concurrently (~ in parallel)"
_echo "Wait till all commands completed"
_echo "Check if any command ended with error"

# Set initial wait number equal to concurrent bash processes
_waitInit 10

for i in {1..10}; do
    
    # This set of commands will be executed in a separate process (sub-process)
    (        
    _echo "$i: sleep 1 sec ..."     ; _waitIfErr "$i: failed"
    sleep 1                         ; _waitIfErr  "$i: failed"
    _echo "$i: ok"
    
    # _waitIfErr can be omitted if there is no need to check the status code of the previous command
    
    # _waitDoneIfErr is required to notify about completion of this sub-process
    _waitDoneIfErr "$i: failed"
    ) &
    
done

# Wait till all commands completed. Check if any command ended with error.
_wait; _iferr "There were errors"

_echo "Success"
