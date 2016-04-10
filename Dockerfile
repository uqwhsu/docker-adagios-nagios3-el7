############################################################
# Dockerfile to build a Adagios/Nagios3 server
# Based on appcontainers/nagios pschmitt/adagios
############################################################

FROM centos:7

MAINTAINER Will Hsu <uqwhsu@users.noreply.github.com>

ENV ADAGIOS_HOST adagios.local
ENV ADAGIOS_USER nagiosadmin
ENV ADAGIOS_PASS P@ssw0rd
ENV LOCALTIMEZONE UTC
ENV SSLCERT /etc/pki/tls/certs/localhost.pem

# Add repos, install packages, remove httpd
RUN yum -y update && \
wget -nv http://download.opensuse.org/repositories/isv:/ownCloud:/devel/CentOS_7/isv:ownCloud:devel.repo -O /etc/yum.repos.d/isvownClouddevel.repo && \
yum -y install --nogpgcheck libcap-dummy && \
yum -y install centos-release-openstack-liberty && \
yum -y install nagios nagios-plugins-all && \
yum -y install epel-release && \
yum -y install lighttpd lighttpd-fastcgi uwsgi uwsgi-plugin-python tar acl git \
gmp-devel pnp4nagios postfix python-pip python-django python-simplejson \
python-paramiko python-devel openssl sudo && \
rpm -ihv http://opensource.is/repo/ok-release.rpm && \
yum --enablerepo=ok-testing -y install okconfig mk-livestatus pynag && \
rpm -e --nodeps httpd && \
yum --enablerepo=ok-testing clean all

# Install supervisor and supervisor-quick. Service restarts are painfully slow
# otherwise
# https://github.com/Supervisor/meld3/issues/23
RUN pip install setuptools --upgrade && \
pip install supervisor && \
pip install supervisor-quick

# Install adagios from source
RUN cd /usr/local && \
git clone https://github.com/opinkerfi/adagios.git && \
cp -r /usr/local/adagios/adagios/etc/adagios /etc/ && \
chown -R nagios:nagios /etc/adagios/ && \
cd adagios && \
python setup.py install 

# Remove cache and default passwd file
# Check all permissions
# Adagios will write to /etc/nagios/adagios, ensure directory exists and
# nagios.cfg knows about it.
# Status view needs broker modules livestatus and pnp4nagios, so configure nagios.cfg
# Add nagios to apache group
# Prepare lighttpd config files
# https://github.com/CentOS/sig-cloud-instance-images/issues/20
# Patch service script to not redirect to systemd
RUN rm -rf /var/cache/* /etc/nagios/passwd && \
chown -R nagios /etc/nagios/* && \
setfacl -R -m group:nagios:rwx /etc/nagios/ && \
setfacl -R -m d:group:nagios:rwx /etc/nagios/ && \
mkdir -p /etc/nagios/adagios && \
pynag config --append cfg_dir=/etc/nagios/adagios && \
pynag config --append "broker_module=/usr/lib64/nagios/brokers/npcdmod.o config_file=/etc/pnp4nagios/npcd.cfg" && \
pynag config --append "broker_module=/usr/lib64/mk-livestatus/livestatus.o /var/spool/nagios/cmd/livestatus" && \
pynag config --set "process_performance_data=1" && \
usermod -G apache,lighttpd nagios && \
usermod -G apache,nagios lighttpd && \
cd /etc/lighttpd && \
sed -i 's|server.use-ipv6 = "enable"|server.use-ipv6 = "disable"|g' lighttpd.conf && \
sed -i 's|include "conf.d/access_log.conf"|#include "conf.d/access_log.conf"|g' lighttpd.conf && \
sed -i 's|server.errorlog             = log_root + "/error.log"|server.errorlog = "/dev/null"|g' lighttpd.conf && \
sed -i 's|#include "conf.d/config.conf"|include "ssl.conf"|g' lighttpd.conf && \
sed -i 's|#  "mod_alias",|  "mod_alias",|g' modules.conf && \
sed -i 's|#  "mod_auth",|  "mod_auth",|g' modules.conf && \
sed -i 's|#  "mod_redirect",|  "mod_redirect",|g' modules.conf && \
sed -i 's|#  "mod_rewrite",|  "mod_rewrite",|g' modules.conf && \
sed -i 's|#  "mod_setenv",|  "mod_setenv",|g' modules.conf && \
sed -i 's|#include "conf.d/fastcgi.conf"|include "conf.d/fastcgi.conf"|g' modules.conf && \
sed -i 's|#include "conf.d/cgi.conf"|include "conf.d/cgi.conf"|g' modules.conf && \
sed -i 's|## ========================|include "nagios.conf"|g' modules.conf && \
sed -i 's|OPTIONS=|OPTIONS=\nexport SYSTEMCTL_SKIP_REDIRECT=1|g' /usr/sbin/service 

# Copy lighttpd and uwsgi enabled supervisor config over to the container
COPY supervisord.conf /etc/supervisord.conf

# Copy lighttpd, and uwsgi related files
COPY lighttpd/nagios.conf /etc/lighttpd/nagios.conf
COPY lighttpd/ssl.conf /etc/lighttpd/ssl.conf
COPY uwsgi/uwsgi.adagios.ini /etc/uwsgi.adagios.ini

# Copy index.html to redirect to adagios or nagios mobile
COPY lighttpd/index.html /var/www/html/index.html

# Copy over our custom init script
COPY run.sh /usr/bin/run.sh

# Copy custom nagios init.d script (for adagios web interface)
COPY nagios.initd.autobackuprestore /etc/init.d/nagios

# Copy custom supervisor init.d script (for nagios genpid)
COPY nagios-supervisor-wrapper.sh /usr/bin/nagios-supervisor-wrapper.sh

# Create childlogdir
# Make run.sh and supervisor wrapper script executable
RUN sed -i 's|^\(nagios_init_script\)=\(.*\)$|\1="sudo /etc/init.d/nagios"|g' /etc/adagios/adagios.conf && \
echo "nagios ALL=NOPASSWD: /etc/init.d/nagios *" >> /etc/sudoers && \
echo "nagios ALL=NOPASSWD: /sbin/service nagios *" >> /etc/sudoers && \
echo "nagios ALL=NOPASSWD: /usr/sbin/nagios -v *" >> /etc/sudoers && \
sed -i 's|Defaults    requiretty|Defaults    !requiretty|g' /etc/sudoers && \
mkdir /var/log/supervisor && \
chmod 755 /usr/bin/run.sh /usr/bin/nagios-supervisor-wrapper.sh

# Install nagios mobile
# https://assets.nagios.com/downloads/exchange/nagiosmobile/Installing_Nagios_Mobile.pdf
RUN cd /tmp && \
curl -O https://assets.nagios.com/downloads/exchange/nagiosmobile/nagiosmobile.tar.gz && \
tar xf nagiosmobile.tar.gz && \
cd nagiosmobile && \
sed -i 's|AuthUserFile /usr/local/nagios/etc/htpasswd.users|AuthUserFile /etc/nagios/passwd|g' nagiosmobile_apache.conf && \
sed -i 's|/usr/local/nagios/var/status.dat|/var/log/nagios/status.dat|g' include.inc.php && \
sed -i 's|/usr/local/nagios/var/rw/nagios.cmd|/var/spool/nagios/cmd/nagios.cmd|g' include.inc.php && \
sed -i 's|/usr/local/nagios/etc/cgi.cfg|/etc/nagios/cgi.cfg|g' include.inc.php && \
sed -i 's|/usr/local/nagios/var/objects.cache|/var/log/nagios/objects.cache|g' include.inc.php && \
sed -i 's|$output = system($service." restart",$code);|$output = ""; $code = 0;|g' INSTALL.php && \
sed -i 's|exit($errors);|exit(0);|g' INSTALL.php && \
sed -i 's|/nagiosxi|/adagios|g' includes/main.inc.php && \
sed -i 's|Nagios XI|Adagios|g' includes/main.inc.php && \
./INSTALL.php && \
chmod 644 /etc/httpd/conf.d/nagiosmobile.conf && \
cd /tmp && rm -rf nagiosmobile && rm nagiosmobile.tar.gz

WORKDIR /etc/nagios

CMD ["/usr/bin/run.sh"]

EXPOSE 80 443

VOLUME ["/etc/adagios", "/etc/nagios", "/var/lib/pnp4nagios", "/var/log/nagios", "/opt"]

