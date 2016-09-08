# dovecot-backup
Dovecot backup shell script for saving emails for every mailbox to its own tar.gz file.

This simple bash/shell script saves all emails
- from all mailboxes/user accounts
- every mailbox in its own *.tar.gz-file
- read from and to the filesystem
- with configurable parameter
- with automatic deletion of old backup-files
- and with logging in a growing up log file under /var/log
