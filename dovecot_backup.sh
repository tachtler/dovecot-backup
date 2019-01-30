#!/bin/bash

##############################################################################
# Script-Name : dovecot_backup.sh                                            #
# Description : Script to backup the mailboxes from dovecot.                 #
#               On successful execution only a LOG file will be written.     #
#               On error while execution, a LOG file and a error message     #
#               will be send by e-mail.                                      #
#                                                                            #
# Last update : 30.01.2019                                                   #
# Version     : 1.08                                                         #
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
# Copyright (c) 2019 by Klaus Tachtler.                                      #
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
# FILE_USERLIST='/path/and/file/name/of/user/list/with/one/email/per/line'
# - OR -
# FILE_USERLIST=''
FILE_USERLIST=''

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
GREP_COMMAND=`command -v grep`
FILE_LOCK='/tmp/'$SCRIPT_NAME'.lock'
FILE_LOG='/var/log/'$SCRIPT_NAME'.log'
FILE_LAST_LOG='/tmp/'$SCRIPT_NAME'.log'
FILE_MAIL='/tmp/'$SCRIPT_NAME'.mail'
FILE_MBOXLIST='/tmp/'$SCRIPT_NAME'.mboxlist'
VAR_HOSTNAME=`uname -n`
VAR_SENDER='root@'$VAR_HOSTNAME
VAR_EMAILDATE=`$DATE_COMMAND '+%a, %d %b %Y %H:%M:%S (%Z)'`
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

# Main.
log ""
RUN_TIMESTAMP=`$DATE_COMMAND '+%s'`
log "+-----------------------------------------------------------------+"
log "| Start backup of the mailboxes [`$DATE_COMMAND '+%a, %d %b %Y %H:%M:%S (%Z)'`] |"
log "+-----------------------------------------------------------------+"
log ""
log "Run script with following parameter:"
log ""
log "SCRIPT_NAME...: $SCRIPT_NAME"
log ""
log "DIR_BACKUP....: $DIR_BACKUP"
log ""
log "MAIL_RECIPIENT: $MAIL_RECIPIENT"
log "MAIL_STATUS...: $MAIL_STATUS"
log ""

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "$DSYNC_COMMAND" ]; then
        log "Check if command '$DSYNC_COMMAND' was found....................[FAILED]"
        sendmail ERROR
        movelog
        exit 11
else
        log "Check if command '$DSYNC_COMMAND' was found....................[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "$TAR_COMMAND" ]; then
        log "Check if command '$TAR_COMMAND' was found......................[FAILED]"
        sendmail ERROR
        movelog
        exit 12
else
        log "Check if command '$TAR_COMMAND' was found......................[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "$TOUCH_COMMAND" ]; then
        log "Check if command '$TOUCH_COMMAND' was found....................[FAILED]"
        sendmail ERROR
        movelog
        exit 13
else
        log "Check if command '$TOUCH_COMMAND' was found....................[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "$RM_COMMAND" ]; then
        log "Check if command '$RM_COMMAND' was found.......................[FAILED]"
        sendmail ERROR
        movelog
        exit 14
else
        log "Check if command '$RM_COMMAND' was found.......................[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "$CAT_COMMAND" ]; then
        log "Check if command '$CAT_COMMAND' was found......................[FAILED]"
        sendmail ERROR
        movelog
        exit 15
else
        log "Check if command '$CAT_COMMAND' was found......................[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "$DATE_COMMAND" ]; then
        log "Check if command '$DATE_COMMAND' was found.....................[FAILED]"
        sendmail ERROR
        movelog
        exit 16
else
        log "Check if command '$DATE_COMMAND' was found.....................[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "$MKDIR_COMMAND" ]; then
        log "Check if command '$MKDIR_COMMAND' was found....................[FAILED]"
        sendmail ERROR
        movelog
        exit 17
else
        log "Check if command '$MKDIR_COMMAND' was found....................[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "$CHOWN_COMMAND" ]; then
        log "Check if command '$CHOWN_COMMAND' was found....................[FAILED]"
        sendmail ERROR
        movelog
        exit 18
else
        log "Check if command '$CHOWN_COMMAND' was found....................[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "$CHMOD_COMMAND" ]; then
        log "Check if command '$CHMOD_COMMAND' was found....................[FAILED]"
        sendmail ERROR
        movelog
        exit 19
else
        log "Check if command '$CHMOD_COMMAND' was found....................[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "$GREP_COMMAND" ]; then
        log "Check if command '$GREP_COMMAND' was found.....................[FAILED]"
        sendmail ERROR
        movelog
        exit 20
else
        log "Check if command '$GREP_COMMAND' was found.....................[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "$PROG_SENDMAIL" ]; then
        log "Check if command '$PROG_SENDMAIL' was found................[FAILED]"
        sendmail ERROR
        movelog
        exit 21
else
        log "Check if command '$PROG_SENDMAIL' was found................[  OK  ]"
fi

# Check if LOCK file NOT exist.
if [ ! -e "$FILE_LOCK" ]; then
        log "Check if script is NOT already runnig .....................[  OK  ]"

        $TOUCH_COMMAND $FILE_LOCK
else
        log "Check if script is NOT already runnig .....................[FAILED]"
        log ""
        log "ERROR: The script was already running, or LOCK file already exists!"
        log ""
        sendmail ERROR
        movelog
        exit 30
fi

# Check if DIR_BACKUP Directory NOT exists.
if [ ! -d "$DIR_BACKUP" ]; then
        log "Check if DIR_BACKUP exists.................................[FAILED]"
        $MKDIR_COMMAND -p $DIR_BACKUP
        log "DIR_BACKUP was now created.................................[  OK  ]"
else
        log "Check if DIR_BACKUP exists.................................[  OK  ]"
fi

# Check if FILE_USERLIST NOT set OR IS empty.
log ""
if [ ! -n "$FILE_USERLIST"  ]; then
        log "Check if the variable FILE_USERLIST is set.................[  NO  ]"
        log "Mailboxes to backup will be determined by doveadm user \"*\"."

        for users in `doveadm user "*"`; do
                VAR_LISTED_USER+=($users);
        done
else
        log "Check if the variable FILE_USERLIST is set.................[  OK  ]"
        log "Mailboxes to backup will read from file."
        log ""
        log "- File: [$FILE_USERLIST]"

        # Check if file exists.
        if [ -f "$FILE_USERLIST" ]; then
                log "- Check if FILE_USERLIST exists............................[  OK  ]"
        else
                log "- Check if FILE_USERLIST exists............................[FAILED]"
                log ""
                sendmail ERROR
                movelog
                exit 40
        fi

        # Check if file is readable.
        if [ -r "$FILE_USERLIST" ]; then
                log "- Check if FILE_USERLIST is readable.......................[  OK  ]"
        else
                log "- Check if FILE_USERLIST is readable.......................[FAILED]"
                log ""
                sendmail ERROR
                movelog
                exit 41
        fi

        # Read file into variable.
        while IFS= read -r line
        do
                # Check if basic email address syntax is valid.
                if echo "${line}" | $GREP_COMMAND '^[a-zA-Z0-9]*@[a-zA-Z0-9]*\.[a-zA-Z0-9]*$' >/dev/null; then
                        VAR_LISTED_USER+=($line);
                else
                        log ""
                        log "ERROR: The email address: $line is not valid!"

                        ((VAR_COUNT_FAIL++))
                        VAR_FAILED_USER+=($line);
                fi
        done <"$FILE_USERLIST"
fi

# Check if VAR_COUNT_FAIL is greater than zero. If YES set counter to VAR_COUNT_USER.
if [ "$VAR_COUNT_FAIL" -ne "0" ]; then
        VAR_COUNT_USER=$VAR_COUNT_FAIL
fi

# Start backup.
log ""
log "+-----------------------------------------------------------------+"
log "| Run backup $SCRIPT_NAME ..................................... |"
log "+-----------------------------------------------------------------+"
log ""

# Start real backup process for all users.
for users in "${VAR_LISTED_USER[@]}"; do
        log "Start backup process for user: $users ..."

        ((VAR_COUNT_USER++))
        DOMAINPART=${users#*@}
        LOCALPART=${users%%@*}
        LOCATION="$DIR_BACKUP/$DOMAINPART/$LOCALPART/$MAILDIR_NAME"
        USERPART="$DOMAINPART/$LOCALPART"

        log "Extract mailbox data for user: $users ..."
        $DSYNC_COMMAND -o plugin/quota= -f -u $users backup $MAILDIR_TYPE:$LOCATION

        # Check the status of dsync and continue the script depending on the result.
        if [ "$?" != "0" ]; then
                case "$?" in
                1)      log "Synchronization failed > user: $users !!!"
                        ;;
                2)      log "Synchronization was done without errors, but some changes couldn't be done, so the mailboxes aren't perfectly synchronized for user: $users !!!"
                        ;;
                esac
                if [ "$?" -gt "3" ]; then
                        log "Synchronization failed > user: $users !!!"
                fi

                ((VAR_COUNT_FAIL++))
                VAR_FAILED_USER+=($users);
        else
                log "Synchronization done for user: $users ..."

                cd $DIR_BACKUP

                log "Packaging to archive for user: $users ..."
                $TAR_COMMAND -cvzf $users-$FILE_BACKUP $USERPART --atime-preserve --preserve-permissions

                log "Delete archive files for user: $users ..."
                (ls -t $users-$FILE_DELETE|head -n $BACKUPFILES_DELETE;ls $users-$FILE_DELETE)|sort|uniq -u|xargs -r rm
                if [ "$?" != "0" ]; then
                        log "Delete old archive files $DIR_BACKUP .....................[FAILED]"
                else
                        log "Delete old archive files $DIR_BACKUP .....................[  OK  ]"
                fi

                log "Delete mailbox files for user: $users ..."
                $RM_COMMAND "$DIR_BACKUP/$DOMAINPART" -rf
                if [ "$?" != "0" ]; then
                        log "Delete mailbox files at: $DIR_BACKUP .....................[FAILED]"
                else
                        log "Delete mailbox files at: $DIR_BACKUP .....................[  OK  ]"
                fi
        fi

        log "Ended backup process for user: $users ..."
        log ""
done

# Set owner and rights permissions to backup directory and backup files.
$CHOWN_COMMAND -R $MAILDIR_USER:$MAILDIR_GROUP $DIR_BACKUP
$CHMOD_COMMAND 700 $DIR_BACKUP
$CHMOD_COMMAND -R 600 $DIR_BACKUP/*

# Delete LOCK file.
if [ "$?" != "0" ]; then
        retval $?
        log ""
        $RM_COMMAND -f $FILE_LOCK
        sendmail ERROR
        movelog
        exit 99
else
        log "+-----------------------------------------------------------------+"
        log "| End backup $SCRIPT_NAME ..................................... |"
        log "+-----------------------------------------------------------------+"
        log ""
fi

# Finish syncing with runntime statistics.
log "+-----------------------------------------------------------------+"
log "| Runtime statistics............................................. |"
log "+-----------------------------------------------------------------+"
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
log "+-----------------------------------------------------------------+"
log "| Finished creating the backups [`$DATE_COMMAND '+%a, %d %b %Y %H:%M:%S (%Z)'`] |"
log "+-----------------------------------------------------------------+"
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
