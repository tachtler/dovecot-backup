# dovecot-backup
This is a shell script for saving up all emails from the mailboxes of Dovecot (MDA) to an email mailbox specific archive file in ``tar.gz`` **or** ``tar.zst`` format.

This simple bash/shell script save the emails
- **DEFAULT** from all mailboxes/user accounts, determined with ``doveadm user "*"``
- **OR** only from these mailboxes/user accounts, which are stored in a file.
- every mailbox/user into a separate ``*.tar.gz`` or ``*.tar.zst`` file
- reading the data from the filesystem
- with configurable parameter
- with automatic deletion of old backup-files
- and with logging into a growing up log file under ``/var/log``
- with **statistic summary** at the end of the script execution
- with **runtime summary** at the end of the script execution
- on **successful execution** a LOG file will be written, or configurable a message will be send by e-mail.
- on **error while execution**, a LOG file will be written and an error message will be send by e-mail.

A more confortable and detailed description is available under following link:

http://www.dokuwiki.tachtler.net/doku.php?id=tachtler:dovecot_backup_-_skript

(Sorry, by now, only avaliable in **German language**)

Full description of **all** the parameter to set **to get the script to work**, inside the top part of the script:

```
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
# SET. If NOT, the script will determine all mailboxes by default.
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
```

##### **Note**: The script doesn't work with Multi-dbox (mdbox). BUT following changes can solve that issue:

Please change/replace the line
```
$DSYNC_COMMAND -o plugin/quota= -f -u $users backup $MAILDIR_TYPE:$LOCATION
```
with
```
doveadm backup -n inbox -f -u $users $MAILDIR_TYPE:$LOCATION:LAYOUT=fs
```

```Issue #6``` - Thanks to SvenSFS
