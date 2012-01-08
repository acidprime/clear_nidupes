#!/bin/bash
declare -x awk="/usr/bin/awk"
declare -x basename="/usr/bin/basename"
declare -x date="/bin/date"
declare -x du="/usr/bin/du"
declare -x defaults="/usr/bin/defaults"
declare -x killall="/usr/bin/killall"
declare -x nicl="/usr/bin/nicl"
declare -x nidump="/usr/bin/nidump"
declare -x osascript="/usr/bin/osascript"
declare -x rm="/bin/rm"
mcxcacher="/System/Library/CoreServices/mcxd.app/Contents/Resources/MCXCacher"
declare -x REQCMDS="$nicl $nidump $mcxcacher"

# -- Runtime varibles
declare -x SCRIPT="${0##*/}" ; SCRIPTNAME="${SCRIPT%%\.*}"
declare -x SCRIPTPATH="$0" RUNDIRECTORY="${0%/*}"
declare -x SERVERVERSION="/System/Library/CoreServices/ServerVersion.plist"
declare -x SYSTEMVERSION="/System/Library/CoreServices/SystemVersion.plist"
declare -x OSVER="$("$defaults" read "${SYSTEMVERSION%.plist}" ProductVersion )"
declare -x CONFIGFILE="${RUNDIRECTORY:?}/${SCRIPTNAME}.conf"
declare -x BUILDVERSION="20090903"
[ "$EUID" != 0 ] && printf "%s\n" "This script requires root access!" && exit 1

# -- Start the script log
# Set to "VERBOSE" for more logging prior to using -v
declare -x SCRIPTLOG="/Library/Logs/${SCRIPT%%\.*}.log"
if [ -f "$SCRIPTLOG" ] ; then
declare -ix CURRENT_LOG_SIZE="$("$du" -k "${SCRIPTLOG:?}" |
                                "$awk" '/^[0-9]/{print $1;exit}')"
fi
if [ ${CURRENT_LOG_SIZE:=0} -gt 10240 ] ; then
        "$rm" "$SCRIPTLOG"
        echo "$SCRIPT:LOGSIZE:$CURRENT_LOG_SIZE, too large removing"
fi

exec 2>>"${SCRIPTLOG:?}" # Redirect standard error to log file

# Strip any extention from scriptname and log stderr to script log
if [ -n ${SCRIPTLOG:?"The script log has not been specified"} ] ; then
printf "%s\n" \
"STARTED:$SCRIPTNAME:EUID:$EUID:$("$date" +%H:%M:%S): Mac OS X $OSVER:BUILD:$BUILDVERSION" >>"${SCRIPTLOG:?}"
printf "%s\n" "Log file is: ${SCRIPTLOG:?}"
fi


statusMessage() { # Status message function with type and now color!
declare date="${date:="/bin/date"}"
declare DATE="$("$date" -u "+%Y-%m-%d")"
declare STATUS_TYPE="$1" STATUS_MESSAGE="$2"
if [ "$ENABLECOLOR" = "YES"  ] ; then
        # Background Color
        declare REDBG="41" WHITEBG="47" BLACKBG="40"
        declare YELLOWBG="43" BLUEBG="44" GREENBG="42"
        # Foreground Color
        declare BLACKFG="30" WHITEFG="37" YELLOWFG="33"
        declare BLUEFG="36" REDFG="31"
        declare BOLD="1" NOTBOLD="0"
        declare format='\033[%s;%s;%sm%s\033[0m\n'
        # "Bold" "Background" "Forground" "Status message"
        printf '\033[0m' # Clean up any previous color in the prompt
else
        declare format='%s\n'
fi
showUIDialog(){
statusMessage header "FUNCTION: #       $FUNCNAME" ; unset EXITVALUE TRY
"$killall" -HUP "System Events" 2>/dev/null
declare -x UIMESSAGE="$1"
"$osascript" <<EOF
try
with timeout of 0.1 seconds
        tell application "System Events"
                set UIMESSAGE to (system attribute "UIMESSAGE") as string
                activate
                        display dialog UIMESSAGE with icon 2 giving up after "3600" buttons "Dismiss" default button "Dismiss"
                end tell
        end timeout
end try
EOF
return 0
} # END showUIDialog()
case "${STATUS_TYPE:?"Error status message with null type"}" in
        progress) \
        [ -n "$LOGLEVEL" ] &&
        printf $format $NOTBOLD $WHITEBG $BLACKFG "PROGRESS:$STATUS_MESSAGE"  ;
        printf "%s\n" "$DATE:PROGRESS: $STATUS_MESSAGE" >> "${SCRIPTLOG:?}" ;;
        # Used for general progress messages, always viewable

        notice) \
        printf "%s\n" "$DATE:NOTICE:$STATUS_MESSAGE" >> "${SCRIPTLOG:?}" ;
        [ -n "$LOGLEVEL" ] &&
        printf $format $NOTBOLD $YELLOWBG $BLACKFG "NOTICE  :$STATUS_MESSAGE"  ;;
        # Notifications of non-fatal errors , always viewable

        error) \
        printf "%s\n\a" "$DATE:ERROR:$STATUS_MESSAGE" >> "${SCRIPTLOG:?}" ;
        [ -n "$LOGLEVEL" ] &&
        printf $format $NOTBOLD $REDBG $YELLOWFG "ERROR   :$STATUS_MESSAGE"  ;;
        # Errors , always viewable

        verbose) \
        printf "%s\n" "$DATE:VERBOSE: $STATUS_MESSAGE" >> "${SCRIPTLOG:?}" ;
        [ "$LOGLEVEL" = "VERBOSE" ] &&
        printf $format $NOTBOLD $WHITEBG $BLACKFG "VERBOSE :$STATUS_MESSAGE" ;;
        # All verbose output

        header) \
        [ "$LOGLEVEL" = "VERBOSE" ] &&
        printf $format $NOTBOLD $BLUEBG $BLUEFG "VERBOSE :$STATUS_MESSAGE" ;
        printf "%s\n" "$DATE:PROGRESS: $STATUS_MESSAGE" >> "${SCRIPTLOG:?}" ;;
        # Function and section headers for the script

        passed) \
        [ "$LOGLEVEL" = "VERBOSE" ] &&
        printf $format $NOTBOLD $GREENBG $BLACKFG "SANITY  :$STATUS_MESSAGE" ;
        printf "%s\n" "$DATE:SANITY: $STATUS_MESSAGE" >> "${SCRIPTLOG:?}" ;;
        # Sanity checks and "good" information
        graphical) \
        [ "$GUI" = "ENABLED" ] &&
        showUIDialog "$STATUS_MESSAGE" ;;

esac
return 0
} # END statusMessage()



die() { # die Function
statusMessage header "FUNCTION: #       $FUNCNAME" ; unset EXITVALUE
declare LASTDIETYPE="$1" LAST_MESSAGE="$2" LASTEXIT="$3"
declare LASTDIETYPE="${LASTDIETYPE:="UNTYPED"}"
if [ ${LASTEXIT:="192"} -gt 0 ] ; then
        statusMessage error "$LASTDIETYPE :$LAST_MESSAGE:EXIT:$LASTEXIT"
        # Print specific error message in red
else
        statusMessage verbose "$LASTDIETYPE :$LAST_MESSAGE:EXIT:$LASTEXIT"
        # Print specific error message in white
fi
statusMessage verbose "COMPLETED:$SCRIPT IN $SECONDS SECONDS"
"$killall" "System Events"
exit "${LASTEXIT}"      # Exit with last status or 192 if none.
return 1                # Should never get here
} # END die()


cleanUp() { # -- Clean up of our inportant sessions variables and functions.
statusMessage header "FUNCTION: #       $FUNCNAME" ; unset EXITVALUE
statusMessage verbose "TIME: $SCRIPT ran in $SECONDS seconds"
unset -f ${!check*}
[ "${ENABLECOLOR:-"ENABLECOLOR"}" = "YES"  ] && printf '\033[0m' # Clear Color

if [ "$PPID" == 1 ] ; then # LaunchD is always PID 1 in 10.4+
	: # Future LaunchD code
fi
exec 2>&- # Reset the error redirects
return 0
} # END cleanUp()

# Check script options
statusMessage header "GETOPTS: Processing script $# options:$@"
# ABOVE: Check to see if we are running as a postflight script,the installer  creates $SCRIPT_NAME
[ $# = 0 ] && statusMessage verbose "No options given"
# If we are not running postflight and no parameters given, print usage to stderr and exit status 1
while getopts vCu SWITCH ; do
        case $SWITCH in
                v ) export LOGLEVEL="VERBOSE" ;;
                C ) export ENABLECOLOR="YES" ;;
                u ) export GUI="ENABLED" ;;
        esac
done # END getopts


checkCommands() { # CHECK_CMDS Required Commands installed check using the REQCMDS varible.
declare -i FUNCSECONDS="$SECONDS" # Capture start time
statusMessage header  "FUNCTION: #      ${FUNCNAME}" ; unset EXITVALUE
declare REQCMDS="$1"
for RQCMD in ${REQCMDS:?} ; do
        if [  -x "$RQCMD" ] ; then
                statusMessage passed "PASSED: $RQCMD is executable"
        else
        # Export the command Name to the die status message can refernce it"
                export RQCMD ; return 1
        fi
        done
return 0
declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
[ "${FUNCTIME:?}" != 0 ] &&
statusMessage verbose "TIME:$FUNCNAME:Took $FUNCTIME seconds to EXIT:$EXITVALUE"
} # END checkCommands()


checkSystemVersion() {
# CHECK_OS Read the /Sys*/Lib*/CoreSer*/S*Version.plist value for OS version
statusMessage header "FUNCTION: #       ${FUNCNAME}" ; unset EXITVALUE
declare OSVER="$1"
case "${OSVER:?}" in
        10.0* | 10.1* | 10.2* | 10.3*) \
        die ERROR "$FUNCNAME: Unsupported OS version: $OSVER." 192 ;;

        10.4*) \
        statusMessage passed "CHECK_OS: OS check: $OSVER successful!";
        return 0 ;;

        10.5* | 10.6*) \
        die ERROR "$FUNCNAME:$LINENO Unsupported OS:$OSVER is too new." 192 ;;

       	*) \
        die ERROR "CHECK_OS:$LINENO Unsupported OS:$OSVER unknown error" 192 ;;
esac
return 1
} # END checkSystemVersion()

deleteNetInfoUser(){
statusMessage header "FUNCTION: #       ${FUNCNAME}" ; unset EXITVALUE
	declare NI_NAME="$1" NI_INDEX="$2"
	declare CONSOLE_USER=$("$who" | "$awk" '$2~/console/{ print $1;exit}')
	if [ "$CONSOLE_USER" != "${NI_NAME:?}" ] ; then
		statusMessage progress "Deleting account : $NI_NAME index: $NI_INDEX"
		$nicl . -delete $NI_INDEX ||
		statusMessage error "Deletion failed for user: $DP_USER"
	elif [ "$CONSOLE_USER" = ${NI_NAME:?} ] ; then
                statusMessage progress "Deleting account : $NI_NAME index: $NI_INDEX"
		statusMessage notice "User: $NI_NAME is logged into this system"
		$nicl . -delete $NI_INDEX ||
		statusMessage error "Deletion failed for user: $DP_USER"
		statusMessage progress "Recreating console mobile account"
		$mcxcacher -U "${NI_NAME}"
	fi
} # End deleteNetInfoUser

backNetInfo(){
statusMessage header "FUNCTION: #       ${FUNCNAME}" ; unset EXITVALUE
	if [ -d /var/db/netinfo ]; then
    	statusMessage verbose "Backing up NetInfo data"
    		for DOMAIN in /var/db/netinfo/*.nidb; do
        		declare DOMAIN=$($basename $DOMAIN .nidb)
        		declare SERVER=$($nicl -t localhost/$DOMAIN -statistics |
				$awk '/tag/{print $3}')
        	if [ $SERVER = 'master' ] ; then
	$nidump -r / -t localhost/$DOMAIN > /var/backups/$DOMAIN.nidump
		fi
    		done
	fi
} # END backNetInfo

checkSystemVersion "${OSVER:?}"
checkCommands "${REQCMDS:?}"

declare -xi DUP_USERS=`$nicl . -list /users | $awk 'seen[$2]++ == 1' | $awk 'END{print NR;exit}'`
if [ "$DUP_USERS" -eq 0 ] ; then
        statusMessage passed "No duplicate users found"
	cleanUp && exit 0
else
        statusMessage progress "Found $DUP_USERS duplicate users"
fi

OLDIFS="$IFS"
IFS=$'\n'
for DP_USER in `$nicl . -list /users | $awk 'seen[$2]++ == 1'` ; do 
	declare -i DP_INDEX="$(printf $DP_USER  | $awk '{print $1;exit}')"
	declare DP_USER="$(printf $DP_USER  | $awk '{print $2;exit}')"
	for NI_USER in `$nicl . -list /users` ; do
		declare -i NI_INDEX="$(printf "$NI_USER" | $awk '{print $1;exit}')"
		declare NI_NAME="$(printf "$NI_USER" | $awk '{print $2;exit}')"
		if [ "$NI_NAME" = "$DP_USER" ] ; then
			statusMessage progress "Found Duplicate User: $DP_USER ID: $NI_INDEX"
			backNetInfo # Backup before we modifiy the database
			deleteNetInfoUser "$NI_NAME" "$NI_INDEX"
			continue
		fi
	done
done
IFS="$OLDIFS"

cleanUp && exit 0
