# Introduction

This is adapted from [pschmitt/adagios](https://github.com/pschmitt/docker-adagios) and included the following features:

* **centos:7** base image
* timezone environment setting
* use your own **SSL certificate** or self signed SSL certificate
* **lighttpd** with **fastcgi** for low memory server
* **uwsgi** to host adagios application
* **nagios3** from CentOS Cloud SIG repo 
* **adagios** from git instead of old prebuilt rpms
* **nagios mobile** web interface
* automatic nagios configurations backup and restore
* sample nagios plugins checks via ssh scripts
* **postfix** for sending nagios alerts email

## Usage notes

There are sample nagios plugins checks via ssh scripts located in **_opt/_** directory, as well as the shell script that install these plugins.  Copy them to **_/opt_** volume, then add the necessary commands/services for the plugins via Adagios interface.

`custom-init-sample.sh` is kept as example alternative.

It is strongly advisable to pre-generate passphraseless SSH public key to be stored in the nagios user home directory when using these nagios plugins.

Make sure to customise **_/etc/postfix/main.cf_** to send out nagios alerts email.

Please review and edit `docker-adagios.service` systemd service file before use.

## Variables

- **ADAGIOS_HOST** : Hostname (Default: localhost)
- **ADAGIOS_USER** : Username for accessing the adagios web interface (Default: nagiosadmin)
- **ADAGIOS_PASS** : Password for accessing the adagios web interface (Default: P@ssw0rd)
- **GIT_REPO** : Whether /etc/nagios should be kept in a git repo. (Default: false)
- **LOCALTIMEZONE** : Time zone name used in value of TZ environment variable (Default: UTC)
- **SSLCERT** : path and name of the PEM file for SSL support, it should contain both the private key and the certificate. (Default: /etc/pki/tls/certs/localhost.pem self signed)

## Volumes

- /etc/adagios
- /etc/nagios
- /var/lib/pnp4nagios
- /var/log/nagios
- /opt

## Complete Example

```bash
docker build -t uqwhsu/adagios --rm=true --force-rm=true .

docker run -d -h nagios -p 80:80 -p 443:443 \
  -e ADAGIOS_USER=nagiosadmin \
  -e ADAGIOS_PASS=nagiosP@ssw0rd \
  -e GIT_REPO=true \
  -e LOCALTIMEZONE=Australia/Brisbane
  -v ~/dev/docker/adagios/data/adagios:/etc/adagios \
  -v ~/dev/docker/adagios/data/nagios:/etc/nagios \
  -v ~/dev/docker/adagios/data/pnp4nagios:/var/lib/pnp4nagios \
  -v ~/dev/docker/adagios/data/log:/var/log/nagios \
  -v ~/dev/docker/adagios/data/opt:/opt \
  -v ~/dev/docker/adagios/data/.ssh:/var/spool/nagios/.ssh \
  -v ~/dev/docker/adagios/data/main.cf:/etc/postfix/main.cf \
  uqwhsu/adagios
```
After starting the container you can visit <http://localhost/> or <http://192.168.59.103> if you use boot2docker. 


## TODO

use git revert or reset to roll back from failed nagios configuration.


***

## Additional Information
Please see: [pschmitt/adagios README](https://github.com/pschmitt/docker-adagios/blob/master/README.md)
