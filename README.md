# dovecot-backup
Dovecot backup shell script for saving all e-mail for every mailbox from dovecot into a e-mail account specific tar.gz file.

This simple bash/shell script save all e-mail
- from all mailboxes/user accounts
- every mailbox into a separate *.tar.gz-file
- read the data from the filesystem
- with configurable parameter
- with automatic deletion of old backup-files
- and with logging into a growing up log file under ``/var/log``
- with **statistic summary** at the end of the script execution
- on **successful execution** only a LOG file will be written.
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
 
# CUSTOM - Backup-Files.
DIR_BACKUP='/srv/backup'
FILE_BACKUP=dovecot_backup_`date '+%Y%m%d_%H%M%S'`.tar.gz
FILE_DELETE='*.tar.gz'
BACKUPFILES_DELETE=7
 
# CUSTOM - dovecot Folders.
MAILDIR_TYPE='maildir'
MAILDIR_NAME='Maildir'
MAILDIR_USER='vmail'
MAILDIR_GROUP='vmail'
 
# CUSTOM - Mail-Recipient.
MAIL_RECIPIENT='you@example.com'
 
# CUSTOM - Status-Mail [Y|N].
MAIL_STATUS='N'
```
