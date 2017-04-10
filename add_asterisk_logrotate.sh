#!/bin/bash
FILE=/etc/logrotate.d/asterisk
if [ -f $FILE ]; then
# file already exists...
echo "The file '$FILE' already exists. Looks like this is already enabled."
else
# create asterisk file
cat >> $FILE <<EOT
/var/log/asterisk/messages /var/log/asterisk/*log /var/log/asterisk/cdr-csv/Master.csv {
   missingok
   rotate 5
   weekly
   postrotate
       /usr/sbin/asterisk -rx 'logger reload' > /dev/null 2> /dev/null
   endscript
}
EOT
echo "The file '$FILE' has been created."
fi
