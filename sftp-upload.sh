#!/bin/bash -f
#
# SSH upload script based on:
#
# SFTP - Secure File Transfer Protocol
#
# Per default, sftp-upload will copy all files in the
# working directory to a remote host using sftp. A transfer
# log will be created containing the verbose sftp output.
#
# Checksuming and e-mail notification can be turned
# on optionally.
#
# Preconditions:
# 1. Copy sftp-upload.sh to backup directory.
# 2. Change file permissions: "chmod u+x sftp-backup.sh".
# 3. Create transfer log directory: "mkdir ./Log".
# 4. Set environment variables and binaries according
#    system environment.
# 5. Create a pair of SSH keys, the private key must
#    not be password protected and stored therefore
#    safely with the correct file permissions set.
# 6. Set the corresponding publick key on the SFTP
#    server as accepted key for authentication.
# 7. Create cronjob to execute backup script after
#    backup archive was created.
#
# For usage description execute: ./sftp-upload.sh -h
#
VERSION=1.0

# Set Environment variables and binaries specific to environment
DATE=`/bin/date '+%-Y%m%d-%H%M-'`
FIND=/usr/bin/find
GREP=/bin/grep
HOSTNAME=/bin/hostname
RM=/bin/rm
SFTP=/usr/bin/sftp
SENDMAIL=/usr/bin/sendmail
PRINTF=/usr/bin/printf
PWD=`/bin/pwd`
SHA1=/usr/bin/sha1sum
# Init variables
TRANSFER_LOG=''
UPLOAD_ERR=0
# Usage description
show_usage()
{
        cat <<EOF

        Usage:

                $0 [-u username] [-i /identity_file] [-s server_address]

        Options:

                -h show help                    Show this help
                -l local_file                   Copy local file to remote host
                -c checksum                     Create checksums off all files in working directory
                -p port                         Use specified port (default=22)

        Mandatory options:

                -u username                     Use specified username when connecting to the remote host
                -i identity_file                Use specified ssh private key for authentication with the remote host
                -s remote_server                Use specified remote server as backup server

        Notification options:

                -r mail_recipient               Send e-mail notifications on error or success
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
        if [ ! "$OPT_MAIL_SERVER" ] ; then
                echo "Option [-m mail_server] is missing."
                show_usage
                exit 1
        fi

}
check_option_r()
{
        if [ ! "$OPT_MAIL_RECIPIENT" ] ; then
                echo "Option [-r mail_recipient] is missing."
                show_usage
                exit 1
        fi
}
# Options
OPT_LF_PATH=''
OPT_LF_VAL=0
OPT_MAIL_RECIPIENT=''
OPT_MAIL_SERVER=0
OPT_REMOTE_USER=''
OPT_REMOTE_SERVER=0
OPT_PORT=22
OPT_IDENTITY_FILE=''
OPT_CHECKSUM=0
# Start processing options at index 1
OPTIND=1
# Show help if no option is given
if [ "$#" = 0 ]; then
                echo "Mandatory flags missing."
                show_usage
                exit 1
fi
# Parse options
while getopts ":hl:cu:i:s:p:r:m:" VALUE "$@" ; do
        if [ "$VALUE" = "h" ] ; then
                show_usage
                exit 1
        fi
        check_arguments
        if [ "$VALUE" = "r" ] ; then
                OPT_MAIL_RECIPIENT=$OPTARG
                check_option_m
                fi
        check_arguments
        if [ "$VALUE" = "m" ] ; then
                OPT_MAIL_SERVER=$OPTARG
                echo "$OPT_MAIL_SERVER"
                check_option_r
        fi
        check_arguments
        if [ "$VALUE" = "l" ] ; then
                OPT_LF_PATH=$OPTARG
                OPT_LF_VAL=1
        fi
        check_arguments
        if [ "$VALUE" = "u" ] ; then
                OPT_REMOTE_USER=$OPTARG"@"
        fi
        check_arguments
        if [ "$VALUE" = "i" ] ; then
                OPT_IDENTITY_FILE=$OPTARG
        fi
        check_arguments
        if [ "$VALUE" = "s" ] ; then
                OPT_REMOTE_SERVER=$OPTARG
        fi
        check_arguments
        if [ "$VALUE" = "p" ] ; then
                OPT_PORT=$OPTARG
        fi
        check_arguments
        if [ "$VALUE" = "c" ] ; then
                OPT_CHECKSUM=1
        fi
        # Check for unknown flags
        if [ "$VALUE" = "?" ] ; then
                echo "Unknown flag -$OPTARG detected."
                show_usage
                exit 1
        fi
done
# Check if mandatory options missing
if [ ! "$OPT_REMOTE_USER" ] || [ ! "$OPT_IDENTITY_FILE" ] || [ ! "OPT_REMOTE_SERVER" ] ; then
        echo "Mandatory flags missing."
        show_usage
        exit 1
fi
# Checksum file(s) in working dir
if [ "$OPT_CHECKSUM" ] && [ ! "$OPT_LF_VAL" ] ; then
        $FIND $PWD -type f -exec $SHA1 {} + > "$DATE"Checksums.sha1""
elif [ "&OPT_CHECKSUM" ] && [ "$OPT_LF_VAL" ] ; then
        # Needs modification, only checksum specified file
        $FIND $PWD -type f -exec $SHA1 {} + > "$DATE"Checksums.sha1""
fi
# Create sftp-batchfiles
if [ "$OPT_LF_VAL" = 0 ] ; then
        echo > ./batchfile.txt
        echo "put *
        quit" >> batchfile.txt
elif [ "$OPT_LF_VAL" ] ; then
        echo > ./batchfile.txt
        echo "put "$OPT_LF_PATH"
        put *.sha1
        quit" >> batchfile.txt
fi
# Execute sftp file upload, redirect stdin & stderr to transfer log
if [ "$OPT_LF_VAL" = 0 ] ; then
        $SFTP -v -b ./batchfile.txt -oPort=$OPT_PORT -oIdentityFile=$OPT_IDENTITY_FILE $OPT_REMOTE_USER$OPT_REMOTE_SERVER 2>&1 | $GREP 'debug'> "./Log/$DATE"Transfer_Log.txt""
        UPLOAD_ERR="${PIPESTATUS[0]}"
        TRANSFER_LOG=$($FIND . -name "*Transfer_Log.txt" -cmin -10)
        $RM ./batchfile.txt
        $RM ./*.sha1
elif [ "$OPT_LF_VAL" ] ; then
        $SFTP -v -b ./batchfile.txt -oPort=$OPT_PORT -oIdentityFile=$OPT_IDENTITY_FILE $OPT_REMOTE_USER$OPT_REMOTE_SERVER 2>&1 | $GREP 'debug' > "./Log/$DATE"Transfer_Log.txt""
        UPLOAD_ERR="${PIPESTATUS[0]}"
        TRANSFER_LOG=$($FIND . -name "*Transfer_Log.txt" -cmin -10)
        $RM ./batchfile.txt
        $RM ./*.sha1
fi
# Check and execute notification
if [ "$OPT_MAIL_RECIPIENT" ] && [ "$OPT_MAIL_SERVER" ] ; then
        if [ "$UPLOAD_ERR" = 0 ] ; then
                $PRINTF "Backup upload succeeded.\n\nTransfer details:\n\n$TRANSFER_LOG." | $SENDMAIL -t $OPT_MAIL_SERVER -s "CP FW MDS-Server Backup Status" -f SV00795@usz.ch $OPT_MAIL_RECIPIENT
        elif [ "$UPLOAD_ERR" -ne 0 ]; then
                $PRINTF "Backup upload failed, check transfer log for details.\n\nSFTP error code:$UPLOAD_ERR\n\nFor transfer details refer to:\n$TRANSFER_LOG" | $SENDMAIL -t $OPT_MAIL_SERVER -s "CP FW MDS Server Backup Status" -f SV00795@usz.ch $OPT_MAIL_RECIPIENT
                exit 1
        fi
fi

# Cleanup working dir, set file types to delete
if [ "$UPLOAD_ERR" = 0 ]; then
       cd /var/log/MDSBackup
       ./delete
       echo "Backup succeeded."
       exit 0
elif [ "$UPLOAD_ERR" -ne 0 ] ; then
       echo "SFTP error code is:$UPLOAD_ERR"
       echo "Backup failed, check actual transfer log for details: [ $TRANSFER_LOG ]"
       exit 1
fi
exit 0