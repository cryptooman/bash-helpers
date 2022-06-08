#
# Bash helpers
#

# Echo with current datetime
function _echo {
    echo -e "`date '+%Y-%m-%d %H:%M:%S'`\t$@"
}

# Print error status code and message, then exit
# Usage: [[ <my-expr> ]] || _err "<failed-message>" <failed-code>
function _err {
    local msg=$1
    local code=$2
    if (( !code )); then
        code=1
    fi
    echo "ERROR: [$code] $msg"
    exit $code
}

# If previous command returned non-zero status code: print error status code and message, then exit
# Usage: <my-command>; iferr "<failed-message>"
set -o pipefail
function _iferr {
    local code=$?
    local msg=$1
    if (( $code != 0 )); then
        _err "$msg" $code
    fi
}

# Wait group (run commands concurrently)
# Usage:
#   _waitInit 10
#   for i in {1..10}; do
#       (sleep 1; echo "$i: ok"; _waitDoneIfErr "$i: failed") &
#   done
#   _wait; _iferr "There were errors"

readonly WAIT_LOCK_FILE="/dev/shm/wait-lock-`date +%s`$RANDOM.tmp"
readonly WAIT_ERR_FILE="/dev/shm/wait-err-`date +%s`$RANDOM.tmp"

function _waitInit {
    echo "$1" > $WAIT_LOCK_FILE; _iferr "_waitInit: failed to write lock file: $WAIT_LOCK_FILE"
    > $WAIT_ERR_FILE; _iferr "_waitInit: failed to write error file: $WAIT_ERR_FILE"
}

# Skip error check
function _waitDone {
    echo "1" >> $WAIT_LOCK_FILE; _iferr "_waitDone: failed to write lock file: $WAIT_LOCK_FILE"
}

function _waitDoneIfErr {
    local code=$?
    local msg=$1    
    echo "1" >> $WAIT_LOCK_FILE; _iferr "_waitDoneIfErr failed to write lock file: $WAIT_LOCK_FILE"
    if (( $code != 0 )); then
        echo "1" >> $WAIT_ERR_FILE; _iferr "_waitDoneIfErr failed to write error file: $WAIT_ERR_FILE"
        _err "$msg" $code
    fi    
}

function _wait {
    local want=$(head -1 $WAIT_LOCK_FILE)
    [[ "$want" ]] || _err "_wait: failed to get 'want' from lock file: $WAIT_LOCK_FILE"        
    local completed
    while (( 1 )); do        
        completed=$(tail -n+2 $WAIT_LOCK_FILE | wc -l)
        if (( completed >= want )); then
            rm $WAIT_LOCK_FILE; _iferr "_wait: failed to remove lock file: $WAIT_LOCK_FILE"            
            break
        fi                
        sleep 0.1
    done
    local errors=$(cat $WAIT_ERR_FILE | wc -l)
    rm $WAIT_ERR_FILE; _iferr "_wait: failed to remove error file: $WAIT_ERR_FILE"
    if (( errors )); then        
        return 1
    fi
}

# END: Wait group