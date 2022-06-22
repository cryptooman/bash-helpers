#
# Bash helpers
#

# Echo with current datetime
function _echo {
    echo -e "`date '+%Y-%m-%d %H:%M:%S'`\t$@"
}

# Print error status code and message, then exit
# Syntax: _err ["failed message"] [failed-code]
#         If 'failed-code' is omitted, then used exit code of the last executed command
# Usage: <cmd> || _err
#        <cmd1> && ( <cmd2> || _err )
#        <cmd1> | <cmd2> || _err
set -o pipefail
function _err {  
    local lastExitCode=$?
    local msg=$1
    local code=$2
    if (( ! code )); then
        code=$lastExitCode
    fi
    if (( ! code )); then
        code=1 # Default exit code
    fi
    echo "ERROR: [$code] $msg"
    exit $code
}

# Wait group
# Run bash commands concurrently (~ in parallel). Wait till all commands completed. Check if any command ended with error.
# Usage:
#    workers=10
#    _waitInit $workers
#    for i in $(eval echo "{1..$workers}"); do
#        (
#            echo "$i: doing long command ..." && sleep 1; _waitIfErr "$i: failed"
#            echo "$i: success"
#            _waitDone
#        ) &    
#    done
#    _wait || _err "There were errors"

readonly _BH_WAIT_LOCK_FILE="/dev/shm/_bh_wait_lock_`date +%s`_$RANDOM.tmp"
readonly _BH_WAIT_ERR_FILE="/dev/shm/_bh_wait_err_`date +%s`_$RANDOM.tmp"

function _waitInit {
    echo "$1" > $_BH_WAIT_LOCK_FILE || _err "_waitInit: failed to write lock file: $_BH_WAIT_LOCK_FILE"
    > $_BH_WAIT_ERR_FILE || _err "_waitInit: failed to write error file: $_BH_WAIT_ERR_FILE"
}

function _waitIfErr {
    local lastExitCode=$?
    local msg=$1
    if (( lastExitCode != 0 )); then
        echo "1" >> $_BH_WAIT_LOCK_FILE || _err "_waitIfErr: failed to write lock file: $_BH_WAIT_LOCK_FILE"
        echo "1" >> $_BH_WAIT_ERR_FILE || _err "_waitIfErr: failed to write error file: $_BH_WAIT_ERR_FILE"
        _err "$msg" $lastExitCode
    fi
}

function _waitDone {
    echo "1" >> $_BH_WAIT_LOCK_FILE || _err "_waitDone: failed to write lock file: $_BH_WAIT_LOCK_FILE"
}

function _wait {
    local want=$(head -1 $_BH_WAIT_LOCK_FILE)
    [[ "$want" ]] || _err "_wait: failed to get control data from lock file: $_BH_WAIT_LOCK_FILE"
    local completed
    while (( 1 )); do        
        completed=$(tail -n+2 $_BH_WAIT_LOCK_FILE | wc -l)
        if (( completed >= want )); then
            rm $_BH_WAIT_LOCK_FILE || _err "_wait: failed to remove lock file: $_BH_WAIT_LOCK_FILE"            
            break
        fi                
        sleep 0.1
    done
    local errors=$(cat $_BH_WAIT_ERR_FILE | wc -l)
    rm $_BH_WAIT_ERR_FILE || _err "_wait: failed to remove error file: $_BH_WAIT_ERR_FILE"
    if (( errors )); then
        return 1
    fi
}

# END: Wait group
