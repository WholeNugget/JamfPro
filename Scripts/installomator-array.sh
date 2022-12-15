#!/bin/sh
labels=("${4}")
LOGFILE="/private/var/log/Installomator.log"

block="${5}"   # BLOCKING_PROCESS_ACTION
${block:="prompt_user"} # If not specified, default to prompt_user
# ignore: continue even when blocking processes are found.
# silent_fail: Exit script without prompt or installation.
# prompt_user: Show a user dialog for each blocking process found, user can choose "Quit and Update" or "Not Now". When "Quit and Update" is chosen, blocking process will be told to quit. Installomator will wait 30 seconds before checking again in case Save dialogs etc are being responded to. Installomator will abort if quitting after three tries does not succeed. "Not Now" will exit Installomator.
# prompt_user_then_kill: show a user dialog for each blocking process found, user can choose "Quit and Update" or "Not Now". When "Quit and Update" is chosen, blocking process will be terminated. Installomator will abort if terminating after two tries does not succeed. "Not Now" will exit Installomator.
# prompt_user_loop: Like prompt-user, but clicking "Not Now", will just wait an hour, and then it will ask again. WARNING! It might block the MDM agent on the machine, as the script will not exit, it will pause until the hour has passed, possibly blocking for other management actions in this time.
# tell_user: (Default) User will be showed a notification about the important update, but user is only allowed to Quit and Continue, and then we ask the app to quit. This is default.
# tell_user_then_kill: User will be showed a notification about the important update, but user is only allowed to Quit and Continue. If the quitting fails, the blocking processes will be terminated.
# kill: kill process without prompting or giving the user a chance to save.

notify="${6}"  # NOTIFY
${notify:="success"} # If not specified, default to success
# success: (default) notify the user after a successful install
# silent: no notifications
# all: all notifications (great for Self Service installation)

logging="${7}"
${logging:="INFO"} # If not specified, default to INFO
#0: DEBUG Everything is logged
#1: INFO Normal logging behavior
#2: WARN
#3: ERROR
#4: REQ

if [[ "${8}" == "true" ]]
then
	force="force"
else
	force=""
fi

installo="/usr/local/Installomator/Installomator.sh"
echo "Notification set to ${notify} mode."
OLDIFS=$IFS
IFS=,

echo ${labels[@]} >> $LOGFILE
for label in ${labels[@]}
do
    if [[ "${label}" = "" ]]
    then
        echo "Parameter not defined"
    else
    	"Attempting install of app label ${label}"
        "${installo}" "${label}" NOTIFY="${notify}" BLOCKING_PROCESS_ACTION="${block}" LOGGING="${logging}" INSTALL=${force}
    fi
done
IFS=$OLDIFS