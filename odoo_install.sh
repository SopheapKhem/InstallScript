#!/bin/bash
################################################################################
# Script for installing Odoo V10 on Ubuntu (could be used for other version too)
# Based on installation script by Yenthe Van Ginneken https://github.com/Yenthe666/InstallScript
# Author: William Olhasque
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu server. It can install multiple Odoo instances
# in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
# Make a new file:
#  nano odoo-install.sh
# Place this content in it and then make the file executable:
#  chmod +x odoo-install.sh
# Execute the script to install Odoo:
# ./odoo-install
################################################################################

##fixed parameters
#odoo
OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
OE_ADDONS_PATH="$OE_HOME_EXT/addons,$OE_HOME/custom/addons"
#The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
#Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="False"
#Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
#Choose the Odoo version which you want to install. For example: 10.0, 9.0, 8.0, 7.0 or saas-6. When using 'trunk' the master version will be installed.
#IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 10.0
OE_VERSION="10.0"
# Set this to True if you want to install Odoo 10 Enterprise!
IS_ENTERPRISE="False"
#set the superadmin password
OE_SUPERADMIN="admin"
OE_CONFIG="${OE_USER}-server"

#Python env
OE_PYTHON_ENV="${OE_HOME}/python_env"

#PostgreSQL Version
OE_POSTGRESQL_VERSION="10"



##
###  WKHTMLTOPDF download links
## === Debian Jessie
## https://www.odoo.com/documentation/8.0/setup/install.html#deb ):
WKHTMLTOX_X64=https://nightly.odoo.com/extra/wkhtmltox-0.12.1.2_linux-jessie-amd64.deb

#
# Install dialog
#
echo -e "\n---- Update Server ----"
apt-get update >> ./install_log
echo -e "\n---- Install dialog ----"
apt-get install dialog -y >> ./install_log
#
# Remove Odoo and PostgreSQL
#
#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Upgrade Server ----"
apt-get upgrade -y >> ./install_log

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
# Add official repository
cat <<EOF > /etc/apt/sources.list.d/pgdg.list
deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main
EOF

echo -e "\n---- Install PostgreSQL Repo Key ----"
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -


echo -e "\n---- Install PostgreSQL Server ${OE_POSTGRESQL_VERSION} ----"
apt-get update >> ./install_log
apt-get install postgresql-${OE_POSTGRESQL_VERSION} postgresql-server-dev-${OE_POSTGRESQL_VERSION}   -y >> ./install_log

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n---- Install packages ----"
apt-get install libjpeg-dev libevent-dev gcc curl wget git python-pip python-virtualenv virtualenv gdebi-core python-dev libxml2-dev libxslt1-dev zlib1g-dev libldap2-dev libssl-dev libsasl2-dev node-clean-css node-less libxslt-dev python-gevent -y >> ./install_log




#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
	echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO 10 ----"
	_url=$WKHTMLTOX_X64
	wget --quiet $_url
	gdebi --n `basename $_url` >> ./install_log
	rm `basename $_url`
else
	echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi

echo -e "\n---- Create ODOO system user ----"
adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER >> ./install_log
#The user should also be added to the sudo'ers group.
adduser $OE_USER sudo >> ./install_log

echo -e "\n---- Create Log and data directory ----"
mkdir /var/log/$OE_USER >> ./install_log
mkdir /var/lib/$OE_USER >> ./install_log
chown $OE_USER:$OE_USER /var/log/$OE_USER
chown $OE_USER:$OE_USER /var/lib/$OE_USER

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/ >> ./install_log

if [ $IS_ENTERPRISE = "True" ]; then
	# Odoo Enterprise install!
	su $OE_USER -c "mkdir $OE_HOME/enterprise"
	su $OE_USER -c "mkdir $OE_HOME/enterprise/addons"

	echo -e "\n---- Adding Enterprise code under $OE_HOME/enterprise/addons ----"
	git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons"

	echo -e "\n---- Installing Enterprise specific libraries ----"
	apt-get install nodejs npm -y >> ./install_log
	npm install -g less
	npm install -g less-plugin-clean-css
	echo -e "\n--- Create symlink for node"
	ln -s /usr/bin/nodejs /usr/bin/node
	OE_ADDONS_PATH="$OE_HOME/enterprise/addons,$OE_ADDONS_PATH"
fi

echo -e "\n---- Create custom module directory ----"
su $OE_USER -c "mkdir $OE_HOME/custom" >> ./install_log
su $OE_USER -c "mkdir $OE_HOME/custom/addons" >> ./install_log


echo -e "\n---- Setting permissions on home folder ----"
chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "* Create server config file"

cat <<EOF > /etc/${OE_CONFIG}.conf
[options]
addons_path = $OE_ADDONS_PATH
logfile = /var/log/$OE_USER/$OE_CONFIG
admin_passwd =  $OE_SUPERADMIN
data_dir = /var/lib/$OE_USER/.local/share/Odoo
db_host = False
db_port = False
db_user = $OE_USER
db_password = False
limit_memory_hard = 1677721600
limit_memory_soft = 629145600
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200
max_cron_threads = 1
workers = 2
xmlrpc_port = $OE_PORT
EOF

chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
chmod 640 /etc/${OE_CONFIG}.conf


echo -e "\n---- Install python packages and virtualenv ----"
mkdir $OE_PYTHON_ENV >> ./install_log
virtualenv $OE_PYTHON_ENV -p /usr/bin/python2.7 >> ./install_log
source $OE_PYTHON_ENV/bin/activate && pip install -r $OE_HOME_EXT/requirements.txt >> ./install_log
deactivate


#--------------------------------------------------
# Adding ODOO as a deamon (initscript)
#--------------------------------------------------

echo -e "* Create service file"
cat <<EOF > ~/$OE_CONFIG.service
[Unit]
Description=Odoo server
Documentation=https://odoo.com
Requires=postgresql.service
After=postgresql.service

[Service]
Type=simple
PermissionsStartOnly=true
SyslogIdentifier=$OE_HOME_EXT
User=$OE_USER
Group=$OE_USER
ExecStart=$OE_PYTHON_ENV/bin/python $OE_HOME_EXT/odoo-bin --config=/etc/${OE_CONFIG}.conf


[Install]
WantedBy=multi-user.target

EOF

echo -e "* Security Init File"
mv ~/$OE_CONFIG.service /etc/systemd/system/$OE_CONFIG.service

echo -e "* Start ODOO on Startup"
systemctl enable $OE_CONFIG.service


echo -e "* Starting Odoo Service"
systemctl start $OE_CONFIG.service





echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $OE_PORT"
echo "User service: $OE_USER"
echo "User PostgreSQL: $OE_USER"
echo "Code location: $OE_USER"
echo "Addons folder: $OE_USER/$OE_CONFIG/addons/"
echo "Start Odoo service:  systemctl start $OE_CONFIG.service"
echo "Stop Odoo service:  systemctl stop $OE_CONFIG.service"
echo "Restart Odoo service:  systemctl restart $OE_CONFIG.service"
echo "-----------------------------------------------------------"
