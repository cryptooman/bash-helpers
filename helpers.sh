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

# Send message to Telegram
# Setup: 
#   For urlencode: sudo apt install gridsite-clients
# Usage:
#   Basic:
#       sendToTelegram "<telegram-token>" "<chat-id>" "My message ..."
#   With host name and script name:
#       HOST_NAME="$(hostname)"
#       SCRIPT_NAME="$0"
#       TELEGRAM_TOKEN="..."
#       TELEGRAM_CHAT_ID="..."
#       msg="My message ..."
#       msg="$HOST_NAME@$SCRIPT_NAME: `printf "%s" \"$msg\"`" || _err
#       sendToTelegram "$TELEGRAM_TOKEN" "$TELEGRAM_CHAT_ID" "$msg"
# Telegram API limits:
#   https://core.telegram.org/bots/faq
#   If you're sending bulk notifications to multiple users, the API will not allow more than 30 messages per second or so
#   Bot will not be able to send more than 20 messages per minute to the same group
function sendToTelegram {
    local token="$1"
    local chatId="$2"
    local msg="$3"
    [[ "$token" && "$chatId" && "$msg" ]] || _err "sendToTelegram: bad input"
    
    msg=$(urlencode "$msg") || _err
    local len=$(printf "%s" "$msg" | wc -c) || _err        
    if (( len > 4096 )); then
        msg=$(printf "%s" "$msg" | head -c 4093) || _err
        msg=$(printf "%s..." "$msg") || _err
    fi    
    curl -s -L --retry 1 --max-time 30 -X POST "https://api.telegram.org/bot$token/sendMessage" -d chat_id="$chatId" -d text="$msg" 1>/dev/null || _err
}

# Wait group
# Run bash commands concurrently (~ in parallel). Wait till all commands completed. Check if any command ended with error.
# Usage:
#    workers=10
#    waitInit $workers
#    for i in $(eval echo "{1..$workers}"); do
#        (
#            _echo "$i: doing long command ..." && sleep 1; waitIfErr "$i: failed"
#            _echo "$i: success"
#            waitDone
#        ) &    
#    done
#    waitGroup || _err "There were errors"

readonly _BH_WAIT_LOCK_FILE="/dev/shm/_bh_wait_lock_`date +%s`_$RANDOM.tmp" || _err
readonly _BH_WAIT_ERR_FILE="/dev/shm/_bh_wait_err_`date +%s`_$RANDOM.tmp" || _err

function waitInit {
    echo "$1" > $_BH_WAIT_LOCK_FILE || _err "_waitInit: failed to write lock file: $_BH_WAIT_LOCK_FILE"
    > $_BH_WAIT_ERR_FILE || _err "_waitInit: failed to write error file: $_BH_WAIT_ERR_FILE"
}

function waitIfErr {
    local lastExitCode=$?
    local msg=$1
    if (( lastExitCode != 0 )); then
        echo "1" >> $_BH_WAIT_LOCK_FILE || _err "_waitIfErr: failed to write lock file: $_BH_WAIT_LOCK_FILE"
        echo "1" >> $_BH_WAIT_ERR_FILE || _err "_waitIfErr: failed to write error file: $_BH_WAIT_ERR_FILE"
        _err "$msg" $lastExitCode
    fi
}

function waitDone {
    echo "1" >> $_BH_WAIT_LOCK_FILE || _err "_waitDone: failed to write lock file: $_BH_WAIT_LOCK_FILE"
}

function waitGroup {
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
