#!/usr/bin/env bash

##############################################################################
# Script-Name : dovecot_backup.sh                                            #
# Description : Script to backup the mailboxes from dovecot.                 #
#               On successful execution only a LOG file will be written.     #
#               On error while execution, a LOG file and a error message     #
#               will be send by e-mail.                                      #
#                                                                            #
# Last update : 03.07.2023                                                   #
# Version     : 1.20                                                         #
#                                                                            #
# Author      : Klaus Tachtler, <klaus@tachtler.net>                         #
# DokuWiki    : http://www.dokuwiki.tachtler.net                             #
# Homepage    : http://www.tachtler.net                                      #
#                                                                            #
#  +----------------------------------------------------------------------+  #
#  | This program is free software; you can redistribute it and/or modify |  #
#  | it under the terms of the GNU General Public License as published by |  #
#  | the Free Software Foundation; either version 3 of the License, or    |  #
#  | (at your option) any later version.                                  |  #
#  +----------------------------------------------------------------------+  #
#                                                                            #
# Copyright (c) 2023 by Klaus Tachtler.                                      #
#                                                                            #
##############################################################################

##############################################################################
#                                H I S T O R Y                               #
##############################################################################
# Version     : 1.01                                                         #
# Description : Bugfix: Delete all temporary domain directories not only the #
#               last one. Thanks to Guenther J. Niederwimmer.                #
# -------------------------------------------------------------------------- #
# Version     : 1.02                                                         #
# Description : GitHub: Issue #1                                             #
#               The name of the variable to delete the number of old backup  #
#               files $DAYS_DELETE was renamed to $BACKUPFILES_DELETE. This  #
#               was done for better understanding, because if the script was #
#               running more than once a day, this could be misunderstood.   #
#               Thanks to Diane Trout.                                       #
# -------------------------------------------------------------------------- #
# Version     : 1.03                                                         #
# Description : Quota calculation double the calculated size of a mailbox,   #
#               when dict was used. See also following mailing-list entry:   #
#                                                                            #
#               https://www.dovecot.org/list/dovecot/2012-February/          #
#               063585.html                                                  #
#                                                                            #
#               Thanks to André Peters.                                      #
# -------------------------------------------------------------------------- #
# Version     : 1.04                                                         #
# Description : Typo: Correction of the return code query of                 #
#               "# Delete LOCK file." in a pure string comparison.           #
#               Thanks to Oli Sennhauser.                                    #
# -------------------------------------------------------------------------- #
# Version     : 1.05                                                         #
# Description : GitHub: Issue #4                                             #
#               Add error handling for dsync command.                        #
#               Add runtime statistics.                                      #
#               Thanks to HenrikWMG.                                         #
# -------------------------------------------------------------------------- #
# Version     : 1.06                                                         #
# Description : Avoid an error when trying to delete backup files, if the    #
#               $BACKUPFILES_DELETE count is NOT reached.                    #
#               Change file owner, after backup was created.                 #
#               Change file permissions to 600, after backup was created.    #
#               Thanks to Seep1959.                                          #
# -------------------------------------------------------------------------- #
# Version     : 1.07                                                         #
# Description : Compatibility: Change the parameter order for the step       #
#               "Delete archive files for user" for better compatibility     #
#               with FreeBSD.                                                #
#               Thanks to Alexander Preyer.                                  #
# -------------------------------------------------------------------------- #
# Version     : 1.08                                                         #
# Description : GitHub Issue #9                                              #
#               Add ability to only backup specific mailboxes, by using the  # 
#               variable FILE_USERLIST with the file path and file name as   #
#               content. The file must contain one e-mail address per line.  #
#               Add the calculation of the script runtime.                   #
#               Thanks to graue Ritter.                                      #
# -------------------------------------------------------------------------- #
# Version     : 1.09                                                         #
# Description : Add a switch to enable or disable e-mail address check, when #
#               FILE_USERLIST was set and used.                              #
#               Thanks to kbridger.                                          #
# -------------------------------------------------------------------------- #
# Version     : 1.10                                                         #
# Description : Code redesign.                                               #
# -------------------------------------------------------------------------- #
# Version     : 1.11                                                         #
# Description : GitHub Issue #12                                             #
#               Change of the temporary storage medium from DIR_BACKUP to    #
#               TMP_FOLDER for temporary storage of extracted emails from    #
#               the mailboxes was introduced. This allows the use of a       #
#               temporary storage of the extracted emails from the mailboxes #
#               on a faster storage medium, or also on a local storage       #
#               medium, which avoids rights problems if DIR_BACKUP is e.g.   #
#               an NFS mounted storage.                                      #
#               Thanks to Krisztián Hamar.                                   #
# -------------------------------------------------------------------------- #
# Version     : 1.12                                                         #
# Description : GitHub: Issue #13                                            #
#               Change in mv command detection due to initial problems with  #
#               Ubuntu 18.04 LTS.                                            #
#               Thanks to hatted.                                            #
# -------------------------------------------------------------------------- #
# Version     : 1.13                                                         #
# Description : GitHub: Issue #16                                            #
#               Changed the timezone format to hours: for example (+0100) at #
#               VAR_EMAILDATE, because not all e-Mail user interfaces can    #
#               handle the letter time zone notation.                        #
#               Thanks to velzebop.                                          #
# -------------------------------------------------------------------------- #
# Version     : 1.14                                                         #
# Description : GitHub: Issue #18                                            #
#               Add dash '-' and dot '.' to the list of valid chars for the  #
#               e-Mail address validation for the localpart and the          #
#               domainpart.                                                  #
#               Thanks to Henrocker.                                         #
# -------------------------------------------------------------------------- #
# Version     : 1.15                                                         #
# Description : GitHub: Issue #21                                            #
#               Set the required ownership on TMP_FOLDER before running the  #
#               script.                                                      #
#               Thanks to LarsBel.                                           #
# -------------------------------------------------------------------------- #
# Version     : 1.16                                                         #
# Description : Optimize ownership settings for TMP_FOLDER and DIR_BACKUP.   #
# -------------------------------------------------------------------------- #
# Version     : 1.17                                                         #
# Description : GitHub: Issue #22.                                           #
#               Bugfix - movelog does not work properly when an email is to  #
#               be sent due to an error, or a status email has been          #
#               requested.                                                   #
#               Thanks to selbitschka.                                       #
# -------------------------------------------------------------------------- #
# Version     : 1.18                                                         #
# Description : Introduction of zstd compression as an alternative choice to #
#               gzip compression. So now by setting the variable COMPRESSION #
#               the type of compression can be selected between zst and gz.  #
#               The zstd compression can lower the execution time by half.   #
#               The design of the code was also revised.                     #
#               The error handling was also been improved.                   #
#               Thanks to Marco De Lellis.                                   #
# -------------------------------------------------------------------------- #
# Version     : 1.19                                                         #
# Description : GitHub: Issue #24                                            #
#               Correct the license mismatch between GitHub and the script.  #
#               Thanks to David Haerdeman (Alphix).                          #
# -------------------------------------------------------------------------- #
# Version     : 1.20                                                         #
# Description : GitHub: Pull request #26                                     #
#               Improved FreeBSD compatibility.                              #
#               Thanks to wombelix (Dominik Wombacher)                       #
# -------------------------------------------------------------------------- #
# Version     : x.xx                                                         #
# Description : <Description>                                                #
# -------------------------------------------------------------------------- #
##############################################################################

##############################################################################
# >>> Please edit following lines for personal settings and custom usages. ! #
##############################################################################

# CUSTOM - Script-Name.
SCRIPT_NAME='dovecot_backup'

# CUSTOM - Backup-Files compression method - (possible values: gz zst).
COMPRESSION='gz'

# CUSTOM - Backup-Files.
TMP_FOLDER='/srv/backup'
DIR_BACKUP='/srv/backup'
FILE_BACKUP=dovecot_backup_`date '+%Y%m%d_%H%M%S'`.tar.$COMPRESSION
FILE_DELETE=$(printf '*.tar.%s' $COMPRESSION)
BACKUPFILES_DELETE=14

# CUSTOM - dovecot Folders.
MAILDIR_TYPE='maildir'
MAILDIR_NAME='Maildir'
MAILDIR_USER='vmail'
MAILDIR_GROUP='vmail'

# CUSTOM - Path and file name of a file with e-mail addresses to backup, if
#          SET. If NOT, the script will determine all mailboxes by default.
# FILE_USERLIST='/path/and/file/name/of/user/list/with/one/user/per/line'
# - OR -
# FILE_USERLIST=''
FILE_USERLIST=''

# CUSTOM - Check when FILE_USERLIST was used, if the user per line was a
#          valid e-mail address [Y|N].
FILE_USERLIST_VALIDATE_EMAIL='N'

# CUSTOM - Mail-Recipient.
MAIL_RECIPIENT='you@example.com'

# CUSTOM - Status-Mail [Y|N].
MAIL_STATUS='N'

##############################################################################
# >>> Normaly there is no need to change anything below this comment line. ! #
##############################################################################

# Variables.
TAR_COMMAND=`command -v tar`
GZIP_COMMAND=`command -v gzip`
ZSTD_COMMAND=`command -v zstd`
TOUCH_COMMAND=`command -v touch`
RM_COMMAND=`command -v rm`
PROG_SENDMAIL=`command -v sendmail`
CAT_COMMAND=`command -v cat`
DATE_COMMAND=`command -v date`
MKDIR_COMMAND=`command -v mkdir`
CHOWN_COMMAND=`command -v chown`
CHMOD_COMMAND=`command -v chmod`
MKTEMP_COMMAND=`command -v mktemp`
GREP_COMMAND=`command -v grep`
MV_COMMAND=`command which mv`
STAT_COMMAND=`command -v stat`
FILE_LOCK='/tmp/'$SCRIPT_NAME'.lock'
FILE_LOG='/var/log/'$SCRIPT_NAME'.log'
FILE_LAST_LOG='/tmp/'$SCRIPT_NAME'.log'
FILE_MAIL='/tmp/'$SCRIPT_NAME'.mail'
FILE_MBOXLIST='/tmp/'$SCRIPT_NAME'.mboxlist'
VAR_HOSTNAME=`uname -n`
VAR_SENDER='root@'$VAR_HOSTNAME
VAR_EMAILDATE=`$DATE_COMMAND '+%a, %d %b %Y %H:%M:%S (%z)'`
declare -a VAR_LISTED_USER=()
declare -a VAR_FAILED_USER=()
VAR_COUNT_USER=0
VAR_COUNT_FAIL=0

# FreeBSD specific commands
if [ "$OSTYPE" = "FreeBSD" ]; then
        DSYNC_COMMAND=`command -v doveadm`
        STAT_COMMAND_PARAM_FORMAT='-f'
        STAT_COMMAND_ARG_FORMAT_USER='%Su'
        STAT_COMMAND_ARG_FORMAT_GROUP='%Sg'
        MKTEMP_COMMAND_PARAM_ARG="-d ${TMP_FOLDER}/${SCRIPT_NAME}-XXXXXXXXXXXX"
else
	DSYNC_COMMAND=`command -v dsync`
        STAT_COMMAND_PARAM_FORMAT='-c'
        STAT_COMMAND_ARG_FORMAT_USER='%U'
        STAT_COMMAND_ARG_FORMAT_GROUP='%G'
        MKTEMP_COMMAND_PARAM_ARG="-d -p ${TMP_FOLDER} -t ${SCRIPT_NAME}-XXXXXXXXXXXX"
fi

# Functions.
function log() {
        echo $1
        echo `$DATE_COMMAND '+%Y/%m/%d %H:%M:%S'` " INFO:" $1 >>${FILE_LAST_LOG}
}

function retval() {
if [ "$?" != "0" ]; then
        case "$?" in
        *)
                log "ERROR: Unknown error $?"
        ;;
        esac
fi
}

function movelog() {
	$CAT_COMMAND $FILE_LAST_LOG >> $FILE_LOG
	$RM_COMMAND -f $FILE_LAST_LOG	
	$RM_COMMAND -f $FILE_LOCK
}

function sendmail() {
        case "$1" in
        'STATUS')
                MAIL_SUBJECT='Status execution '$SCRIPT_NAME' script.'
        ;;
        *)
                MAIL_SUBJECT='ERROR while execution '$SCRIPT_NAME' script !!!'
        ;;
        esac

$CAT_COMMAND <<MAIL >$FILE_MAIL
Subject: $MAIL_SUBJECT
Date: $VAR_EMAILDATE
From: $VAR_SENDER
To: $MAIL_RECIPIENT

MAIL

$CAT_COMMAND $FILE_LAST_LOG >> $FILE_MAIL

$PROG_SENDMAIL -f $VAR_SENDER -t $MAIL_RECIPIENT < $FILE_MAIL

$RM_COMMAND -f $FILE_MAIL

}

function error () {
	# Parameters.
	CODE_ERROR="$1"

        sendmail ERROR
	movelog
	exit $CODE_ERROR
}

function headerblock () {
	# Parameters.
	TEXT_INPUT="$1"
	LINE_COUNT=68

        # Help variables.
        WORD_COUNT=`echo $TEXT_INPUT | wc -c`
        CHAR_AFTER=`expr $LINE_COUNT - $WORD_COUNT - 5`
        LINE_SPACE=`expr $LINE_COUNT - 3`

	# Format placeholder.
	if [ "$CHAR_AFTER" -lt "0" ]; then
		CHAR_AFTER="0"
	fi

	printf -v char '%*s' $CHAR_AFTER ''
	printf -v line '%*s' $LINE_SPACE ''

	log "+${line// /-}+"
	log "| $TEXT_INPUT${char// /.} |"
	log "+${line// /-}+"
}

function logline () {
	# Parameters.
	TEXT_INPUT="$1"
	TRUE_FALSE="$2"
	LINE_COUNT=68

        # Help variables.
        WORD_COUNT=`echo $TEXT_INPUT | wc -c`
        CHAR_AFTER=`expr $LINE_COUNT - $WORD_COUNT - 9`

	# Format placeholder.
	if [ "$CHAR_AFTER" -lt "0" ]; then
		CHAR_AFTER="0"
	fi

	printf -v char '%*s' $CHAR_AFTER ''

	if [ "$TRUE_FALSE" == "true" ]; then
		log "$TEXT_INPUT${char// /.}[  OK  ]"
	else
		log "$TEXT_INPUT${char// /.}[FAILED]"
	fi
}

function checkcommand () {
	# Parameters.
        CHECK_COMMAND="$1"

	if [ ! -s "$1" ]; then
		logline "Check if command '$CHECK_COMMAND' was found " false
		error 10
	else
		logline "Check if command '$CHECK_COMMAND' was found " true
	fi
}

# Main.
log ""
RUN_TIMESTAMP=`$DATE_COMMAND '+%s'`
headerblock "Start backup of the mailboxes [`$DATE_COMMAND '+%a, %d %b %Y %H:%M:%S (%z)'`]"
log ""
log "SCRIPT_NAME.................: $SCRIPT_NAME"
log ""
log "OS_TYPE.....................: $OSTYPE"
log ""
log "COMPRESSION.................: $COMPRESSION"
log ""
log "TMP_FOLDER..................: $TMP_FOLDER"
log "DIR_BACKUP..................: $DIR_BACKUP"
log ""
log "MAIL_RECIPIENT..............: $MAIL_RECIPIENT"
log "MAIL_STATUS.................: $MAIL_STATUS"
log ""
log "FILE_USERLIST...............: $FILE_USERLIST"
log "FILE_USERLIST_VALIDATE_EMAIL: $FILE_USERLIST_VALIDATE_EMAIL"
log ""

# Check if compress extension is allowed.
if [[ $COMPRESSION != 'zst' && $COMPRESSION != 'gz' ]]; then
        logline "Check compression extension" false
        log ""
        log "ERROR: Compression extension $COMPRESSION unsupported: choose between gz and zst"
        log ""
        error 19
fi

# Check if command (file) NOT exist OR IS empty.
checkcommand $DSYNC_COMMAND
checkcommand $TAR_COMMAND
checkcommand $TOUCH_COMMAND
checkcommand $RM_COMMAND
checkcommand $CAT_COMMAND
checkcommand $DATE_COMMAND
checkcommand $MKDIR_COMMAND
checkcommand $CHOWN_COMMAND
checkcommand $CHMOD_COMMAND
checkcommand $GREP_COMMAND
checkcommand $MKTEMP_COMMAND
checkcommand $MV_COMMAND
checkcommand $STAT_COMMAND
checkcommand $PROG_SENDMAIL

if [ $COMPRESSION = 'gz' ]; then
        checkcommand $GZIP_COMMAND
fi

if [ $COMPRESSION = 'zst' ]; then
        checkcommand $ZSTD_COMMAND
fi

# Check if LOCK file NOT exist.
if [ ! -e "$FILE_LOCK" ]; then
        logline "Check if the script is NOT already runnig " true

        $TOUCH_COMMAND $FILE_LOCK
else
        logline "Check if the script is NOT already runnig " false
        log ""
        log "ERROR: The script was already running, or LOCK file already exists!"
        log ""
	error 20
fi

# Check if TMP_FOLDER directory path NOT exists, else create it.
if [ ! -d "$TMP_FOLDER" ]; then
        logline "Check if TMP_FOLDER exists " false
	$MKDIR_COMMAND -p $TMP_FOLDER
	if [ "$?" != "0" ]; then
		logline "Create temporary '$TMP_FOLDER' folder " false
		error 21
	else
		logline "Create temporary '$TMP_FOLDER' folder " true
	fi
else
        logline "Check if TMP_FOLDER exists " true
fi

# Check if TMP_FOLDER is owned by $MAILDIR_USER.
if [ "$MAILDIR_USER" != `$STAT_COMMAND $STAT_COMMAND_PARAM_FORMAT "$STAT_COMMAND_ARG_FORMAT_USER" $TMP_FOLDER` ]; then
        logline "Check if TMP_FOLDER owner is $MAILDIR_USER " false
	$CHOWN_COMMAND -R $MAILDIR_USER:$MAILDIR_GROUP $TMP_FOLDER
	if [ "$?" != "0" ]; then
        	logline "Set ownership of TMP_FOLDER to $MAILDIR_USER:$MAILDIR_GROUP " false
		error 22
	else
        	logline "Set ownership of TMP_FOLDER to $MAILDIR_USER:$MAILDIR_GROUP " true
	fi
else
        logline "Check if TMP_FOLDER owner is $MAILDIR_USER " true
fi

# Check if TMP_FOLDER group is $MAILDIR_GROUP.
if [ "$MAILDIR_GROUP" != `$STAT_COMMAND $STAT_COMMAND_PARAM_FORMAT "$STAT_COMMAND_ARG_FORMAT_GROUP" $TMP_FOLDER` ]; then
        logline "Check if TMP_FOLDER group is $MAILDIR_GROUP " false
	$CHOWN_COMMAND -R $MAILDIR_USER:$MAILDIR_GROUP $TMP_FOLDER
	if [ "$?" != "0" ]; then
        	logline "Set ownership of TMP_FOLDER to $MAILDIR_USER:$MAILDIR_GROUP " false
		error 23
	else
        	logline "Set ownership of TMP_FOLDER to $MAILDIR_USER:$MAILDIR_GROUP " true
	fi
else
        logline "Check if TMP_FOLDER group is $MAILDIR_GROUP " true
fi

# Check if DIR_BACKUP directory NOT exists, else create it.
if [ ! -d "$DIR_BACKUP" ]; then
        logline "Check if DIR_BACKUP exists " false
	$MKDIR_COMMAND -p $DIR_BACKUP
	if [ "$?" != "0" ]; then
		logline "Create backup '$DIR_BACKUP' folder " false
		error 24
	else
		logline "Create backup '$DIR_BACKUP' folder " true
	fi
else
        logline "Check if DIR_BACKUP exists " true
fi

# Check if DIR_BACKUP is owned by $MAILDIR_USER.
if [ "$MAILDIR_USER" != `$STAT_COMMAND $STAT_COMMAND_PARAM_FORMAT "$STAT_COMMAND_ARG_FORMAT_USER" $DIR_BACKUP` ]; then
        logline "Check if DIR_BACKUP owner is $MAILDIR_USER " false
	$CHOWN_COMMAND -R $MAILDIR_USER:$MAILDIR_GROUP $DIR_BACKUP
	if [ "$?" != "0" ]; then
        	logline "Set ownership of DIR_BACKUP to $MAILDIR_USER:$MAILDIR_GROUP " false
		error 25
	else
        	logline "Set ownership of DIR_BACKUP to $MAILDIR_USER:$MAILDIR_GROUP " true
	fi
else
        logline "Check if DIR_BACKUP owner is $MAILDIR_USER " true
fi

# Check if DIR_BACKUP group is $MAILDIR_GROUP.
if [ "$MAILDIR_GROUP" != `$STAT_COMMAND $STAT_COMMAND_PARAM_FORMAT "$STAT_COMMAND_ARG_FORMAT_GROUP" $DIR_BACKUP` ]; then
        logline "Check if DIR_BACKUP group is $MAILDIR_GROUP " false
	$CHOWN_COMMAND -R $MAILDIR_USER:$MAILDIR_GROUP $DIR_BACKUP
	if [ "$?" != "0" ]; then
        	logline "Set ownership of DIR_BACKUP to $MAILDIR_USER:$MAILDIR_GROUP " false
		error 26
	else
        	logline "Set ownership of DIR_BACKUP to $MAILDIR_USER:$MAILDIR_GROUP " true
	fi
else
        logline "Check if DIR_BACKUP group is $MAILDIR_GROUP " true
fi

# Check if FILE_USERLIST NOT set OR IS empty.
log ""
if [ ! -n "$FILE_USERLIST"  ]; then
        log "Check if the variable FILE_USERLIST is set ................[  NO  ]"
        log "Mailboxes to backup will be determined by doveadm user \"*\"."

	for users in `doveadm user "*"`; do
		VAR_LISTED_USER+=($users);
	done
else
        logline "Check if the variable FILE_USERLIST is set " true
        log "Mailboxes to backup will be read from file."
        log ""
        log "- File: [$FILE_USERLIST]"

	# Check if file exists.
	if [ -f "$FILE_USERLIST" ]; then
        	logline "- Check if FILE_USERLIST exists " true
	else
        	logline "- Check if FILE_USERLIST exists " false
        	log ""
		error 30
	fi

	# Check if file is readable.
	if [ -r "$FILE_USERLIST" ]; then
        	logline "- Check if FILE_USERLIST is readable " true
	else
        	logline "- Check if FILE_USERLIST is readable " false
        	log ""
		error 31
	fi

	# Read file into variable.
	while IFS= read -r line
	do	
		# Check for valid e-mail address.
		if [ $FILE_USERLIST_VALIDATE_EMAIL = 'Y' ]; then
			# Check if basic email address syntax is valid.
			if echo "${line}" | $GREP_COMMAND '^[a-zA-Z0-9.-]*@[a-zA-Z0-9.-]*\.[a-zA-Z0-9]*$' >/dev/null; then
				VAR_LISTED_USER+=($line);
			else
        			log ""
		        	log "ERROR: The user: $line is NOT valid e-mail address!"

	                	((VAR_COUNT_FAIL++))
	                	VAR_FAILED_USER+=($line);
			fi
		else
			VAR_LISTED_USER+=($line);
		fi
	done <"$FILE_USERLIST"

	# Check if VAR_COUNT_FAIL is greater than zero. If YES, set VAR_COUNT_USER to VAR_COUNT_FAIL.
	if [ "$VAR_COUNT_FAIL" -ne "0" ]; then
		VAR_COUNT_USER=$VAR_COUNT_FAIL
	fi
fi

# Start backup.
log ""
headerblock "Run backup $SCRIPT_NAME "
log ""

# Make temporary directory DIR_TEMP inside TMP_FOLDER.
DIR_TEMP=$($MKTEMP_COMMAND $MKTEMP_COMMAND_PARAM_ARG)
if [ "$?" != "0" ]; then
	logline "Create temporary '$DIR_TEMP' folder " false
	error 40
else
	logline "Create temporary '$DIR_TEMP' folder " true
	log ""
fi

# Set ownership to DIR_TEMP.
$CHOWN_COMMAND -R $MAILDIR_USER:$MAILDIR_GROUP $DIR_TEMP
if [ "$?" != "0" ]; then
       	logline "Set ownership of DIR_TEMP to $MAILDIR_USER:$MAILDIR_GROUP " false
	error 41
else
       	logline "Set ownership of DIR_TEMP to $MAILDIR_USER:$MAILDIR_GROUP " true
	log ""
fi

# Start real backup process for all users.
for users in "${VAR_LISTED_USER[@]}"; do
	log "Start backup process for user: $users ..."

	((VAR_COUNT_USER++))
	DOMAINPART=${users#*@}
	LOCALPART=${users%%@*}
	LOCATION="$DIR_TEMP/$DOMAINPART/$LOCALPART/$MAILDIR_NAME"
	USERPART="$DOMAINPART/$LOCALPART"

	log "Extract mailbox data for user: $users ..."

        if [ "$OSTYPE" = "FreeBSD" ]; then
	        $DSYNC_COMMAND -o plugin/quota= backup -u $users $MAILDIR_TYPE:$LOCATION
	else
		$DSYNC_COMMAND -o plugin/quota= -f -u $users backup $MAILDIR_TYPE:$LOCATION
	fi

	# Check the status of dsync and continue the script depending on the result.
	if [ "$?" != "0" ]; then
		case "$?" in
		1)	log "Synchronization failed > user: $users !!!"
			;;
		2)	log "Synchronization was done without errors, but some changes couldn't be done, so the mailboxes aren't perfectly synchronized for user: $users !!!"
			;;
		esac
		if [ "$?" -gt "3" ]; then
			log "Synchronization failed > user: $users !!!"
		fi

		((VAR_COUNT_FAIL++))
		VAR_FAILED_USER+=($users);
	else
        	log "Synchronization done for user: $users ..."

		cd $DIR_TEMP

		log "Packaging to archive for user: $users ..."
		if [ "$OSTYPE" = "FreeBSD" ]; then
			$TAR_COMMAND -cvzf $users-$FILE_BACKUP $USERPART
		else
			$TAR_COMMAND -cvzf $users-$FILE_BACKUP $USERPART --atime-preserve --preserve-permissions
		fi

		log "Delete mailbox files for user: $users ..."
		$RM_COMMAND -rf "$DIR_TEMP/$DOMAINPART"
		if [ "$?" != "0" ]; then
        		logline "Delete mailbox files at: $DIR_TEMP " false
		else
        		logline "Delete mailbox files at: $DIR_TEMP " true
		fi

		log "Copying archive file for user: $users ..."
		$MV_COMMAND "$DIR_TEMP/$users-$FILE_BACKUP" "$DIR_BACKUP"
		if [ "$?" != "0" ]; then
        		logline "Move archive file for user to: $DIR_BACKUP " false
		else
        		logline "Move archive file for user to: $DIR_BACKUP " true
		fi

		cd $DIR_BACKUP

		log "Delete archive files for user: $users ..."
		(ls -t $users-$FILE_DELETE|head -n $BACKUPFILES_DELETE;ls $users-$FILE_DELETE)|sort|uniq -u|xargs -r rm
		if [ "$?" != "0" ]; then
        		logline "Delete old archive files from: $DIR_BACKUP " false
		else
        		logline "Delete old archive files from: $DIR_BACKUP " true
		fi
	fi

	log "Ended backup process for user: $users ..."
        log ""
done

# Delete the temporary folder DIR_TEMP.
$RM_COMMAND -rf $DIR_TEMP
if [ "$?" != "0" ]; then
	logline "Delete temporary '$DIR_TEMP' folder " false
	error 42
else
	logline "Delete temporary '$DIR_TEMP' folder " true
	log ""
fi

# Set ownership to backup directory, again.
$CHOWN_COMMAND -R $MAILDIR_USER:$MAILDIR_GROUP $DIR_BACKUP
if [ "$?" != "0" ]; then
       	logline "Set ownership of DIR_BACKUP to $MAILDIR_USER:$MAILDIR_GROUP " false
	error 43
else
       	logline "Set ownership of DIR_BACKUP to $MAILDIR_USER:$MAILDIR_GROUP " true
fi

# Set rights permission to backup directory.
$CHMOD_COMMAND 700 $DIR_BACKUP
if [ "$?" != "0" ]; then
       	logline "Set permission of DIR_BACKUP to drwx------ " false
	error 44
else
       	logline "Set permission of DIR_BACKUP to drwx------ " true
fi

# Set rights permissions to backup files.
$CHMOD_COMMAND -R 600 $DIR_BACKUP/*
if [ "$?" != "0" ]; then
       	logline "Set file permissions in DIR_BACKUP to -rw------- " false
	error 45
else
       	logline "Set file permissions in DIR_BACKUP to -rw------- " true
	log ""
fi

# Delete LOCK file.
if [ "$?" != "0" ]; then
        retval $?
        log ""
        $RM_COMMAND -f $FILE_LOCK
	error 99
else
	headerblock "End backup $SCRIPT_NAME "
        log ""
fi

# Finish syncing with runntime statistics.
headerblock "Runtime statistics "
log ""
log "- Number of determined users: $VAR_COUNT_USER"
log "- ...Summary of failed users: $VAR_COUNT_FAIL"

if [ "$VAR_COUNT_FAIL" -gt "0" ]; then
	log "- ...Mailbox of failed users: "
	for i in "${VAR_FAILED_USER[@]}"
	do
		log "- ... $i"
	done
fi

log ""
END_TIMESTAMP=`$DATE_COMMAND '+%s'`
if [ "$OSTYPE" = "FreeBSD" ]; then
        DELTA=$((END_TIMESTAMP-RUN_TIMESTAMP))
        log "$(printf 'Runtime: %02d:%02d:%02d time elapsed.\n' $((DELTA/3600)) $((DELTA%3600/60)) $((DELTA%60)))"
else
	log "Runtime: `$DATE_COMMAND -u -d "0 $END_TIMESTAMP seconds - $RUN_TIMESTAMP seconds" +'%H:%M:%S'` time elapsed."
fi
log ""
headerblock "Finished creating the backups [`$DATE_COMMAND '+%a, %d %b %Y %H:%M:%S (%z)'`]"
log ""

# If errors occurred on user backups, exit with return code 1 instead of 0.
if [ "$VAR_COUNT_FAIL" -gt "0" ]; then
        sendmail ERROR
	# Move the log to the permanent log file.
	movelog
	exit 1
else
	# Status e-mail.
	if [ $MAIL_STATUS = 'Y' ]; then
        	sendmail STATUS
	fi
	# Move the log to the permanent log file.
	movelog
	exit 0
fi
