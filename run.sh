#!/usr/bin/env bash

set -e

ADAGIOS_HOST=${ADAGIOS_HOST:-localhost}
ADAGIOS_USER=${ADAGIOS_USER:-nagiosadmin}
ADAGIOS_PASS=${ADAGIOS_PASS:-P@ssw0rd}
GIT_REPO=${GIT_REPO:-false}
LOCALTIMEZONE=${LOCALTIMEZONE:-UTC}
SSLCERT=${SSLCERT:-/etc/pki/tls/certs/localhost.pem}

# Set / generate SSL certificate
if [[ -f $SSLCERT ]]
then
   chgrp lighttpd $SSLCERT
   chmod 640 $SSLCERT
   if [ "$(grep -c "$SSLCERT" /etc/lighttpd/ssl.conf)" -eq 0 ]
   then 
      sed -i "s|  ssl.pemfile \= \"/etc/pki/tls/certs/localhost.pem\"|  ssl.pemfile \= \"${SSLCERT}\"|g" /etc/lighttpd/ssl.conf
   fi
fi

if [[ ! -f /etc/pki/tls/certs/localhost.pem ]]
then
   cd /etc/pki/tls/certs
   /etc/pki/tls/certs/make-dummy-cert /etc/pki/tls/certs/localhost.pem
   chgrp lighttpd /etc/pki/tls/certs/localhost.pem
   chmod 640 /etc/pki/tls/certs/localhost.pem
fi

# Set timezone
if [ -f /usr/share/zoneinfo/$LOCALTIMEZONE ] ; then
   sed -i "s|;date.timezone \=|date.timezone \= ${LOCALTIMEZONE}|g" /etc/php.ini 
   rm /etc/localtime
   ln -s /usr/share/zoneinfo/$LOCALTIMEZONE /etc/localtime
else
   sed -i 's|;date.timezone =|date.timezone = UTC|g' /etc/php.ini 
   rm /etc/localtime 
   ln -s /usr/share/zoneinfo/UTC /etc/localtime
fi

# Set password if htpasswd file does not exist yet
if [[ ! -f /etc/nagios/passwd ]]
then
    htpasswd -c -b /etc/nagios/passwd "$ADAGIOS_USER" "$ADAGIOS_PASS"
fi

# Init git repo at /etc/nagios
if [[ "$GIT_REPO" = "true" && ! -d /etc/nagios/.git ]]
then
    cd /etc/nagios
    echo "passwd" > .gitignore
    git init
    git add .
    git commit -m "Initial commit"
    git config user.email "${ADAGIOS_USER}@${ADAGIOS_HOST}"
    git config user.name "${ADAGIOS_USER}"
    chown -R nagios /etc/nagios/.git
fi
# Set git user
if [[ "$GIT_REPO" = "true" && -d /etc/nagios/.git ]]
then
    cd /etc/nagios
    git config user.email "${ADAGIOS_USER}@${ADAGIOS_HOST}"
    git config user.name "${ADAGIOS_USER}"
    chown -R nagios /etc/nagios/.git
fi

# Create necessary logfile structure
touch /var/log/nagios/nagios.log
for dir in /var/log/nagios/{archives,spool/checkresults}
do
    if [[ ! -d "$dir" ]]
    then
        mkdir -p "$dir"
    fi
done

if [[ ! -d /var/spool/nagios/.ssh ]]
then
    mkdir -p /var/spool/nagios/.ssh
fi

if [[ ! -d /var/lib/adagios ]]
then
    mkdir -p /var/lib/adagios
fi

# Fix permissions
chown -R nagios:nagios /etc/nagios /var/log/nagios /var/spool/nagios /etc/adagios /var/lib/pnp4nagios /var/lib/adagios
chmod 750 /etc/nagios /var/log/nagios
chmod u+s /bin/ping

# Execute custom init scripts
for script in $(ls -1 /opt/*.sh 2> /dev/null)
do
    [[ -x "$script" ]] && "$script"
done

exec /usr/bin/supervisord -n -c /etc/supervisord.conf
