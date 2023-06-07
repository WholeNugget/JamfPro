#!/bin/zsh

# Variables
############################
scriptFolder="/Library/Management/Scripts"
scriptLocation="${scriptFolder}/notify.sh"
log="/private/var/log/preDeploy.log"
prefFile="/Library/Preferences/com.jamf.connect.login.plist"
NOTIFY_LOG="/var/tmp/depnotify.log"
extAttFolder="/Library/Application Support/JAMF/ExtensionAttributes/"
extAttFile="${extAttFolder}com.notify.provision.done"
# Utility Shorthands
############################
jamfBin="/usr/local/bin/jamf"
authchanger="/usr/local/bin/authchanger"

# Folder Setup
############################
if [[ ! -d "${scriptFolder}" ]];then 
	sudo mkdir -p "${scriptFolder}"
fi 

echo "Starting Script" >> "$log" 
if [[ ${4} == "" ]]; then
	echo "No policies detected to be run. Exiting..." >> "$log"
    exit 1
fi

# Install Jamf Connect
# Change to if statement, check for Jamf Connect and install if not there 
echo "Downloading JamfConnect" >> "$log" 
/usr/local/Installomator/Installomator.sh jamfconnect NOTIFY=silent BLOCKING_PROCESS_ACTION=kill 
sleep 2

# Delete any existing logs if we find one. 
if [[ "$NOTIFY_LOG" ]]; then
	rm -Rf "$NOTIFY_LOG"
fi

# Waiting for Setup Assistant to end
while pgrep -q -x "Setup Assistant"; do
    echo "Setup Assistant is still running; pausing for 2 seconds" >> "$log"
    sleep 2
done

echo "Copying deploy script to ${scriptLocation}" > "${log}"
tee "${scriptLocation}" << EOS
#!/bin/zsh

# Disable for prod
# Allows to run this script on a machine to test how DEPNotify will present
#/Applications/Utilities/DEPNotify.app/Contents/MacOS/DEPNotify &

# Heredoc Variables
############################
policiesArray=(${4})
testingMode=${6:-"true"}
cleanUpTrigger=${7:-"predeploy-cleanup"}

# NOTIFY WINDOW SETUP
########################

echo "STARTING RUN" >> $NOTIFY_LOG

echo "Time to caffeniate..." >> $NOTIFY_LOG
caffeinate -d -i -m -s -u &

# Total setups to go through
echo "Command: DeterminateOff:" >> $NOTIFY_LOG

# Set our logo
echo "Command: MainTitle: Starting PreDeployment" >> $NOTIFY_LOG

echo "Command: Image: /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.macbookpro-13-retina-usbc-space-gray.icns" >> $NOTIFY_LOG

echo "Command: MainText: Mac has successfully enrolled to Jamf Pro server. The device will be automatically configured for College use." >> $NOTIFY_LOG

echo "Status: Preparing Mac..." >> "$NOTIFY_LOG"
sleep 10

echo "Command: DeterminateOffReset:" >> "$NOTIFY_LOG"
echo "Command: Determinate: \$(( \${#policiesArray[@]} + 1 ))" >> "$NOTIFY_LOG"

# POLICY LOOP
for POLICY in \${policiesArray[@]}; do
	# Write name to message
	echo "Status: \$(echo "\$POLICY" | cut -d ',' -f1)" >> "$NOTIFY_LOG"
    trigger="\$(echo "\$POLICY" | cut -d ',' -f2)"
	if [ "\$testingMode" = true ]; then
		sleep 10
	elif [ "\$testingMode" = false ]; then
		"$jamfBin" policy -event "\${trigger}"
	fi
done

echo "Command: MainText: Successfully deployed the standard operating environment - performing clean up, the Mac will restart shortly." >> $NOTIFY_LOG

echo "Status: Wrapping up..." >> $NOTIFY_LOG

if [[ "\${testingMode}" = true ]]; then 
	sleep 10
    mkdir -p "${extAttFolder}" && touch "${extAttFile}"
    ${authchanger} -reset
elif [[ "\${testingMode}" = false ]]; then
	"$jamfBin" policy -event \${cleanUpTrigger}
    mkdir -p "${extAttFolder}" && touch "${extAttFile}"
fi
sleep 3
echo "Command: Quit:" >> $NOTIFY_LOG

# Refresh the loginwindow (may not be needed for JC -> JC)
/usr/bin/killall -HUP loginwindow

exit 0

EOS

# Script Permissions
chown root:wheel "${scriptLocation}"
chmod 777 "${scriptLocation}"
chmod u+x "${scriptLocation}"

# Set ScriptPath parameter of Jamf Connect/NoLoAD plist to the location of our script file. 
defaults write "${prefFile}" ScriptPath "${scriptLocation}"
echo "ScriptPath set to:" >> "${log}"
defaults read "${prefFile}" ScriptPath >> "${log}"
sleep 1

# Hand-off to JC for Notify
/usr/local/bin/authchanger -reset -prelogin JamfConnectLogin:Notify
/usr/local/bin/authchanger -prelogin JamfConnectLogin:RunScript,privileged
echo "Rebooting with authorizationdb settings:" >> "${log}"
${authchanger} -print >> "${log}"
sleep 1

# Restart our device to kick the predeployment
shutdown -r now
/usr/bin/killall -HUP loginwindow