#!/bin/sh
# 
# SSH backup script based on SCP - Secure copy.
# 
# Per default, ssh-backup will copy all files in the
# working dir to a remote host using scp tool. 
#
# Checksuming and e-mail notification can be turned 
# on optionally. 
# 
# For usage and option description execute:
# ssh-backup.sh -h
#
VERSION=0.1

# Environment variables and binaries
DATE=`/bin/date '+%-d%b%Y-%H:%M-'`
FIND='find'
GREP='grep'
HOSTNAME='hostname'
RM='rm'
SCP='scp'
SENDMAIL='sendmail'
PRINTF='printf'
PWD=`/bin/pwd`

# Variables
TRANSFER_LOG=''

# Script configuration
show_usage()
{
	cat <<EOF

	Usage:
		
		$0 [-u username] [-i /identity_file] [-s server_address:/remote_dir]

	Options: 

		-h show help                    Show this help
		-l local_file(s)                Copy local file(s) to remote host
		-c checksum                     Create checksums off all files in working directory
		
	Mandatory options:
		 
		-u username                     Use specified username when connecting to the remote host
		-i identity_file                Use a specific ssh private key for authentication with the remote host
		-s remote_server:/remote_dir    Use specified remote server and path to remote dir

	Notification specific 0ptions:

		-r mail_recipient               Send e-mail notification on error or success
		-m mail_server                  Use specified mail server

EOF
}

# Check for missing flags
check_arguments()
{ 
	if [ "$VALUE" = ":" ] ; then
		echo "Flag -$OPTARG requires an argument."
		show_usage
		exit 1
	fi
}
check_option_m()
{
	if [ ! "$MAIL_SERVER" ] ; then
		echo "Option [-m mail_server] is missing."
		show_usage
		exit 1
	fi

}
check_option_r()
{
	if [ ! "$MAIL_RECIPIENT" ] ; then
		echo "Option [-r mail_recipient] is missing."
		show_usage
		exit 1
	fi
}

# Options
LF_PATH=''
LF_VAL=0
MAIL_RECIPIENT=''
MAIL_SERVER=''
REMOTE_USER=''
REMOTE_SERVER=0
IDENTITY_FILE=''
CHECKSUM=0

# Start processing options at index 1
OPTIND=1

# Show help if no option is given
if [ "$#" = 0 ]; then
		echo "Mandatory flags missing."
		show_usage
		exit 1	
fi

# Parse options
while getopts ":hl:cu:i:s:r:m:" VALUE "$@" ; do
	if [ "$VALUE" = "h" ] ; then
		show_usage
		exit 1
	fi
	if [ "$VALUE" = "r" ] ; then
		MAIL_RECIPIENT=$OPTARG
		check_option_m 
		fi 
	check_arguments
	if [ "$VALUE" = "m" ] ; then
		MAIL_SERVER=$OPTARG
		check_option_r
	fi 
	check_arguments
	if [ "$VALUE" = "l" ] ; then
		LF_PATH=$OPTARG
		LF_VAL=1
	fi 
	check_arguments
	if [ "$VALUE" = "u" ] ; then
		REMOTE_USER=$OPTARG"@"
	fi
	check_arguments
	if [ "$VALUE" = "i" ] ; then
		IDENTITY_FILE=$OPTARG
	fi 
	check_arguments
	if [ "$VALUE" = "s" ] ; then
		REMOTE_SERVER=$OPTARG
	fi
	if [ "$VALUE" = "c" ] ; then
		CHECKSUM=true
	fi
	# Check for unknown flags
	if [ "$VALUE" = "?" ] ; then
		echo "Unknown flag -$OPTARG detected."
		show_usage
		exit 1
	fi
done

# Check if mandatory options missing
if [ ! "$REMOTE_USER" ] || [ ! "$IDENTITY_FILE" ] || [ ! "REMOTE_SERVER" ] ; then
	echo "Mandatory flags missing."
	show_usage
	exit 1
fi

# Checksum files in working dir
if [ "$CHECKSUM" ] && [ ! "$LF_VAL" ] ; then
	$FIND $PWD -type f -exec md5 {} + > "$DATE"Checksums.md5""
elif [ "&CHECKSUM" ] && [ "$LF_VAL" ] ; then
	# Needs modification, only checksum specified file
	$FIND $PWD -type f -exec md5 {} + > "$DATE"Checksums.md5""
fi
# Execute file upload, redirect stdin & err to transfer log 
if [ "$LF_VAL" = 0 ] ; then
	$SCP -v -i $IDENTITY_FILE $PWD/*.* $REMOTE_USER$REMOTE_SERVER 2>&1 | $GREP 'Transferred' > "$DATE"Transfer_Log.txt""
elif [ "$LF_VAL" ] ; then
	$SCP -v -i $IDENTITY_FILE $LF_PATH ./*.md5 $REMOTE_USER$REMOTE_SERVER 2>&1 | $GREP 'Transferred' > "$DATE"Transfer_Log.txt""
fi

# Check and execute notification
if [ "$MAIL_RECIPIENT" ] && [ "$MAIL_SERVER" ] ; then
	if [ "$?" = 0 ] ; then
		echo "$PRINTF "Backup succeeded.\n\nTransfer details:\n$TRANSFER_LOG." | "$SENDMAIL -t $MAIL_SERVER -s $HOSTNAME -f $HOSTNAME $MAIL_RECIPIENT""
	elif [ "$?" -ne 0 ]; then
		echo "$PRINTF "Backup failed, check transfer log for details.\n\nTransfer details:\n$TRANSFER_LOG" | "$SENDMAIL -t $MAIL_SERVER -s $HOSTNAME -f $HOSTNAME $MAIL_RECIPIENT""
	fi
fi



