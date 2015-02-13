#!/bin/sh

#
# Initialise/configure TYPO3 app pre-installed during 'docker build'
# and located in /tmp/INSTALLED_PACKAGE_NAME.tgz (@see install_typo3_app() function)
#

set -e
set -u

source ./include-functions.sh
source ./include-variables.sh

# Internal variables - there is no need to change them
CWD=$(pwd) # Points to /build-typo3-app/ directory, where this script is located
WEB_SERVER_ROOT="/data/www"
APP_ROOT="${WEB_SERVER_ROOT}/${T3APP_NAME}"
SETTINGS_SOURCE_FILE="${CWD}/Settings.yaml"
VHOST_SOURCE_FILE="${CWD}/vhost.conf"
VHOST_FILE="/data/conf/nginx/hosts.d/${T3APP_NAME}.conf"
MYSQL_CMD_PARAMS="-u$T3APP_DB_USER -p$T3APP_DB_PASS -h $T3APP_DB_HOST -P $T3APP_DB_PORT"
CONTAINER_IP=$(ip -4 addr show eth0 | grep inet | cut -d/ -f1 | awk '{print $2}')
BASH_RC_FILE="$WEB_SERVER_ROOT/.bash_profile"
BASH_RC_SOURCE_FILE="$CWD/.bash_profile"



# Configure some environment aspects (PATH, /etc/hosts, 'www' user profile etc)
configure_env

#
# TYPO3 app installation
#
install_typo3_app
cd $APP_ROOT
wait_for_db

#
# Regular TYPO3 app initialisation
#
if [ "${T3APP_DO_INIT^^}" = TRUE ]; then
  log "Configuring TYPO3 CMS app..." && log

  #create_app_db $T3APP_DB_NAME
  #create_settings_yaml "Configuration/Settings.yaml" $T3APP_DB_NAME

fi
# Regular TYPO3 app initialisation (END)


set_permissions
create_vhost_conf $T3APP_VHOST_NAMES
user_build_script

log "Installation completed." && echo
