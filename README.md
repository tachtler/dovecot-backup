# dovecot-backup
Dovecot backup shell script for saving emails for every mailbox from dovecot to its own tar.gz file.

This simple bash/shell script saves all emails
- from all mailboxes/user accounts
- every mailbox in its own *.tar.gz-file
- read the data from the filesystem
- with configurable parameter
- with automatic deletion of old backup-files
- and with logging in a growing up log file under /var/log

On **successful execution** only a LOG file will be written.
On **error while execution**, a LOG file and a error message will be send by e-mail.

A more confortable and detailed description is available under following link:

http://www.dokuwiki.tachtler.net/doku.php?id=tachtler:dovecot_backup_-_skript

(Only avaliable in German language)

Short description of **all** the parameter to set, inside the top part of the script:

```
##############################################################################
# >>> Please edit following lines for personal settings and custom usages. ! #
##############################################################################
 
# CUSTOM - Script-Name.
SCRIPT_NAME='dovecot_backup'
 
# CUSTOM - Backup-Files.
DIR_BACKUP='/data/backup'
FILE_BACKUP=dovecot_backup_`date '+%Y%m%d_%H%M%S'`.tar.gz
FILE_DELETE='*.tar.gz'
DAYS_DELETE=7
 
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
