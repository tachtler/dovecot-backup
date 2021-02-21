#!/bin/bash

##############################################################################
# Script-Name : dovecot_backup.sh                                            #
# Description : Script to backup the mailboxes from dovecot.                 #
#               On successful execution only a LOG file will be written.     #
#               On error while execution, a LOG file and a error message     #
#               will be send by e-mail.                                      #
#                                                                            #
# Last update : 21.02.2021                                                   #
# Version     : 1.15                                                         #
#                                                                            #
# Author      : Klaus Tachtler, <klaus@tachtler.net>                         #
# DokuWiki    : http://www.dokuwiki.tachtler.net                             #
# Homepage    : http://www.tachtler.net                                      #
#                                                                            #
#  +----------------------------------------------------------------------+  #
#  | This program is free software; you can redistribute it and/or modify |  #
#  | it under the terms of the GNU General Public License as published by |  #
#  | the Free Software Foundation; either version 2 of the License, or    |  #
#  | (at your option) any later version.                                  |  #
#  +----------------------------------------------------------------------+  #
#                                                                            #
# Copyright (c) 2020 by Klaus Tachtler.                                      #
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
# Version     : x.xx                                                         #
# Description : <Description>                                                #
# -------------------------------------------------------------------------- #
##############################################################################

##############################################################################
# >>> Please edit following lines for personal settings and custom usages. ! #
##############################################################################

# CUSTOM - Script-Name.
SCRIPT_NAME='dovecot_backup'

# CUSTOM - Backup-Files.
TMP_FOLDER='/srv/backup'
DIR_BACKUP='/srv/backup'
FILE_BACKUP=dovecot_backup_`date '+%Y%m%d_%H%M%S'`.tar.gz
FILE_DELETE='*.tar.gz'
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
DSYNC_COMMAND=`command -v dsync`
TAR_COMMAND=`command -v tar`
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
log "TMP_FOLDER..................: $TMP_FOLDER"
log "DIR_BACKUP..................: $DIR_BACKUP"
log ""
log "MAIL_RECIPIENT..............: $MAIL_RECIPIENT"
log "MAIL_STATUS.................: $MAIL_STATUS"
log ""
log "FILE_USERLIST...............: $FILE_USERLIST"
log "FILE_USERLIST_VALIDATE_EMAIL: $FILE_USERLIST_VALIDATE_EMAIL"
log ""

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
checkcommand $PROG_SENDMAIL

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

# Check if TMP_FOLDER directory NOT exists.
if [ ! -d "$TMP_FOLDER" ]; then
        logline "Check if TMP_FOLDER exists " false
	$MKDIR_COMMAND -p $TMP_FOLDER
	if [ "$?" != "0" ]; then
        	logline "TMP_FOLDER was NOT created " false
		error 21
	else
        	logline "TMP_FOLDER was now created " true
	fi
else
        logline "Check if TMP_FOLDER exists " true
fi

# Set ownership to the TMP_FOLDER directory.
if [ ! -d "$TMP_FOLDER" ]; then
        logline "TMP_FOLDER does NOT exists " false
	error 22
else
        logline "Set required ownership to TMP_FOLDER " true
	$CHOWN_COMMAND -R $MAILDIR_USER:$MAILDIR_GROUP $TMP_FOLDER
	if [ "$?" != "0" ]; then
        	logline "Required ownership to TMP_FOLDER was NOT set " false
		error 23
	else
        	logline "Required ownership to TMP_FOLDER was set " true
	fi
fi

# Check if DIR_BACKUP directory NOT exists.
if [ ! -d "$DIR_BACKUP" ]; then
        logline "Check if DIR_BACKUP exists " false
	$MKDIR_COMMAND -p $DIR_BACKUP
	if [ "$?" != "0" ]; then
        	logline "DIR_BACKUP was NOT created " false
		error 24
	else
        	logline "DIR_BACKUP was now created " true
	fi
else
        logline "Check if DIR_BACKUP exists " true
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

# Check if TMP_FOLDER directory path NOT exists, else create it.
if [ ! -d "$TMP_FOLDER" ]; then
        logline "Check if TMP_FOLDER exists " false
	$MKDIR_COMMAND -p $TMP_FOLDER
	if [ "$?" != "0" ]; then
		logline "Create temporary '$TMP_FOLDER' folder " false
		error 40
	else
		logline "Create temporary '$TMP_FOLDER' folder " true
	fi
else
        logline "Check if TMP_FOLDER exists " true
fi

# Make temporary directory DIR_TEMP inside TMP_FOLDER.
DIR_TEMP=$($MKTEMP_COMMAND -d -p $TMP_FOLDER -t $SCRIPT_NAME-XXXXXXXXXXXX)
if [ "$?" != "0" ]; then
	logline "Create temporary '$DIR_TEMP' folder " false
	error 41
else
	logline "Create temporary '$DIR_TEMP' folder " true
	log ""
fi

# Set rights permissions to DIR_TEMP.
$CHOWN_COMMAND -R $MAILDIR_USER:$MAILDIR_GROUP $DIR_TEMP

# Start real backup process for all users.
for users in "${VAR_LISTED_USER[@]}"; do
	log "Start backup process for user: $users ..."

	((VAR_COUNT_USER++))
	DOMAINPART=${users#*@}
	LOCALPART=${users%%@*}
	LOCATION="$DIR_TEMP/$DOMAINPART/$LOCALPART/$MAILDIR_NAME"
	USERPART="$DOMAINPART/$LOCALPART"

	log "Extract mailbox data for user: $users ..."
	$DSYNC_COMMAND -o plugin/quota= -f -u $users backup $MAILDIR_TYPE:$LOCATION

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
		$TAR_COMMAND -cvzf $users-$FILE_BACKUP $USERPART --atime-preserve --preserve-permissions

		log "Delete mailbox files for user: $users ..."
		$RM_COMMAND "$DIR_TEMP/$DOMAINPART" -rf
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
$RM_COMMAND $DIR_TEMP -rf
if [ "$?" != "0" ]; then
	logline "Delete temporary '$DIR_TEMP' folder " false
	error 42
else
	logline "Delete temporary '$DIR_TEMP' folder " true
	log ""
fi

# Set owner and rights permissions to backup directory and backup files.
$CHOWN_COMMAND -R $MAILDIR_USER:$MAILDIR_GROUP $DIR_BACKUP
$CHMOD_COMMAND 700 $DIR_BACKUP
$CHMOD_COMMAND -R 600 $DIR_BACKUP/*

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
log "Runtime: `$DATE_COMMAND -u -d "0 $END_TIMESTAMP seconds - $RUN_TIMESTAMP seconds" +'%H:%M:%S'` time elapsed."
log ""
headerblock "Finished creating the backups [`$DATE_COMMAND '+%a, %d %b %Y %H:%M:%S (%z)'`]"
log ""

# If errors occurred on user backups, exit with return code 1 instead of 0.
if [ "$VAR_COUNT_FAIL" -gt "0" ]; then
        sendmail ERROR
	movelog
	exit 1
else
	# Status e-mail.
	if [ $MAIL_STATUS = 'Y' ]; then
        	sendmail STATUS
	fi
	movelog
	exit 0
fi
