#!/bin/sh

#######################################
# Echo/log function
# Arguments:
#   String: value to log
#######################################
log() {
  if [[ "$@" ]]; then echo "[${T3APP_NAME^^}] $@";
  else echo; fi
}

#########################################################
# Check in the loop (every 2s) if the database backend
# service is already available.
# Globals:
#   T3APP_DB_HOST: db hostname
#   T3APP_DB_PORT: db port number
#   T3APP_DB_USER: db username
#   MYSQL_CMD_PARAMS
#########################################################
function wait_for_db() {
  set +e
  local res=1
  while [[ $res -ne 0 ]]; do
    mysql $MYSQL_CMD_PARAMS --execute "status" 1>/dev/null
    res=$?
    if [[ $res -ne 0 ]]; then log "Waiting for DB service ($T3APP_DB_HOST:$T3APP_DB_PORT username:$T3APP_DB_USER)..." && sleep 2; fi
  done
  set -e

  # Display DB status...
  log "Database status:"
  mysql $MYSQL_CMD_PARAMS --execute "status"
}

#########################################################
# Moves pre-installed in /tmp TYPO3 to its
# target location ($APP_ROOT), if it's not there yet
# Globals:
#   WEB_SERVER_ROOT
#   APP_ROOT
#   T3APP_NAME
#   T3APP_BUILD_BRANCH
#########################################################
function install_typo3_app() {
  # Check if app is already installed (when restaring stopped container)
  if [ ! -d $APP_ROOT ]; then
    log "Installing TYPO3 app (from pre-installed archive)..."
    cd $WEB_SERVER_ROOT && tar -zxf /tmp/$INSTALLED_PACKAGE_NAME.tgz
    mv $INSTALLED_PACKAGE_NAME $T3APP_NAME
  fi

  cd $APP_ROOT

  # Allow switching between branches for running containers
  # E.g. user can provide different branch for `docker build` (in Dockerfile)
  # and different when launching the container.
  # Note: it's done with --force param, so local conflicting changes will be thrown away. But we assume sb who is doing this knows about it.
  git fetch && git checkout --force $T3APP_BUILD_BRANCH

  # Debug: show most recent git log messages
  log "TYPO3 app installed. Most recent commits:"
  git log -5 --pretty=format:"%h %an %cr: %s" --graph && echo # Show most recent changes

  # If app is/was already installed, pull the most recent code
  if [ "${T3APP_ALWAYS_DO_PULL^^}" = TRUE ]; then
    install_typo3_app_do_pull
  fi

  # If composer.lock has changed, this will re-install things...
  composer install $T3APP_BUILD_COMPOSER_PARAMS
}

#########################################################
# Pull the newest codebase from the remote repository.
# It tries to handle the situation even when they are
# conflicting changes.
#
# Called when T3APP_ALWAYS_DO_PULL is set to TRUE.
#
# Globals:
#   WEB_SERVER_ROOT
#   APP_ROOT
#   T3APP_NAME
#########################################################
function install_typo3_app_do_pull() {
  set +e # allow non-zero command results (git pull might fail due to code conflicts)
  log "Pulling the newest codebase (due to T3APP_ALWAYS_DO_PULL set to TRUE)..."

  if [[ ! $(git status | grep "working directory clean") ]]; then
    log "There are some changes in the current working directory. Stashing..."
    git status
    git stash --include-untracked
  fi

  if [[ ! $(git pull -f) ]]; then
    log "git pull failed. Trying once again with 'git reset --hard origin/${T3APP_BUILD_BRANCH}'..."
    git reset --hard origin/$T3APP_BUILD_BRANCH
  fi

  log "Most recent commits (after newest codebase has been pulled):"
  git log -10 --pretty=format:"%h %an %cr: %s" --graph

  set -e # restore -e setting
}

#########################################################
# Create Nginx vhost, if it doesn't exist yet
# Globals:
#   APP_ROOT
#   VHOST_FILE
#   VHOST_SOURCE_FILE
# Arguments:
#   String: virtual host name(s), space separated
#########################################################
function create_vhost_conf() {
  local vhost_names=$@
  local vhost_names_arr=($vhost_names)
  log "Configuring vhost in ${VHOST_FILE} for vhost(s) ${vhost_names}"

  # Create fresh vhost file on new data volume
  if [ ! -f $VHOST_FILE ]; then
    cat $VHOST_SOURCE_FILE > $VHOST_FILE
    log "New vhost file created."
  # Vhost already exist, but T3APP_FORCE_VHOST_CONF_UPDATE=true, so override it.
  elif [ "${T3APP_FORCE_VHOST_CONF_UPDATE^^}" = TRUE ]; then
    cat $VHOST_SOURCE_FILE > $VHOST_FILE
    log "Vhost file updated (as T3APP_FORCE_VHOST_CONF_UPDATE is TRUE)."
  fi

  sed -i -r "s#%server_name%#${vhost_names}#g" $VHOST_FILE
  sed -i -r "s#%root%#${APP_ROOT}#g" $VHOST_FILE

  # Configure redirect: www to non-www
  # @TODO: make it configurable via env var
  # @TODO: make possible reversed behaviour (non-www to www)
  sed -i -r "s#%server_name_primary%#${vhost_names_arr[0]}#g" $VHOST_FILE

  cat $VHOST_FILE
  log "Nginx vhost configured."
}

#########################################################
# Update TYPO3 app Settings.yaml with DB backend settings
# Globals:
#   SETTINGS_SOURCE_FILE
#   T3APP_DB_HOST
#   T3APP_DB_PORT
#   T3APP_DB_USER
#   T3APP_DB_PASS
# Arguments:
#   String: filepath to config file to create/configure
#   String: database name to put in Settings.yaml
#########################################################
function create_settings_yaml() {
  local settings_file=$1
  local settings_db_name=$2

  mkdir -p $(dirname $settings_file)

  if [ ! -f $settings_file ]; then
    cat $SETTINGS_SOURCE_FILE > $settings_file
    log "Configuration file $settings_file created."
  fi

  log "Configuring $settings_file..."
  sed -i -r "1,/dbname:/s/dbname: .+?/dbname: $settings_db_name/g" $settings_file
  sed -i -r "1,/user:/s/user: .+?/user: $T3APP_DB_USER/g" $settings_file
  sed -i -r "1,/password:/s/password: .+?/password: $T3APP_DB_PASS/g" $settings_file
  sed -i -r "1,/host:/s/host: .+?/host: $T3APP_DB_HOST/g" $settings_file
  sed -i -r "1,/port:/s/port: .+?/port: $T3APP_DB_PORT/g" $settings_file

  cat $settings_file
  log "$settings_file updated."
}

#########################################################
# Set correct permission for TYPO3 app
#########################################################
function set_permissions() {
  chown -R www:www $APP_ROOT
}

#########################################################
# If the installed TYPO3 app contains
# executable $T3APP_USER_BUILD_SCRIPT file, it will run it.
# This script can be used to do all necessary steps to make
# the site up&running, e.g. compile CSS.
#########################################################
function user_build_script() {
  cd $APP_ROOT;
  if [[ -x $T3APP_USER_BUILD_SCRIPT ]]; then
    # Run ./build.sh script as 'www' user
    su www -c $T3APP_USER_BUILD_SCRIPT
  fi
}

#########################################################
# Configure environment (e.g. PATH).
# Configure .bash_profile for 'www' user with all
# necessary scripts/settings like /etc/hosts settings.
# Globals:
#   APP_ROOT
#   BASH_RC_FILE
#   BASH_RC_SOURCE_FILE
#   CONTAINER_IP
#   T3APP_BUILD_BRANCH
#   T3APP_VHOST_NAMES
#   T3APP_NAME
#   T3APP_USER_NAME
#########################################################
function configure_env() {
  # Configure git, so git stash/pull always works. Otherwise git shouts about missing configuration.
  # Note: the actual values doesn't matter, most important is that they are configured.
  git config --global user.email "${T3APP_USER_NAME}@local"
  git config --global user.name $T3APP_USER_NAME

  # Add T3APP_VHOST_NAMES to /etc/hosts inside this container
  echo "127.0.0.1 $T3APP_VHOST_NAMES" | tee -a /etc/hosts

  # Copy .bash_profile and substitute all necessary variables
  cat $BASH_RC_SOURCE_FILE > $BASH_RC_FILE && chown www:www $BASH_RC_FILE
  sed -i -r "s#%CONTAINER_IP%#${CONTAINER_IP}#g" $BASH_RC_FILE
  sed -i -r "s#%APP_ROOT%#${APP_ROOT}#g" $BASH_RC_FILE
  sed -i -r "s#%T3APP_BUILD_BRANCH%#${T3APP_BUILD_BRANCH}#g" $BASH_RC_FILE
  sed -i -r "s#%T3APP_NAME%#${T3APP_NAME}#g" $BASH_RC_FILE
  sed -i -r "s#%T3APP_VHOST_NAMES%#${T3APP_VHOST_NAMES}#g" $BASH_RC_FILE

  # setup default credentials for the mysql cli
  cat <<EOF > ${WEB_SERVER_ROOT}/.my.cnf
[client]
user=${T3APP_DB_USER}
password=${T3APP_DB_PASS}
database=${T3APP_DB_NAME}
host=${T3APP_DB_HOST}
EOF
}

#########################################################
# Setup a new TYPO3 CMS Site
#########################################################
function setup_typo3_cms() {
	cd $APP_ROOT
	./typo3cms install:setup \
			   --database-user-name="${T3APP_DB_USER}" \
			   --database-user-password="${T3APP_DB_PASS}" \
			   --database-host-name="${T3APP_DB_HOST}" \
			   --database-port="${T3APP_DB_PORT}" \
			   --database-socket="false" \
			   --database-name="${T3APP_DB_NAME}" \
			   --admin-user-name="${T3APP_USER_NAME}" \
			   --admin-password="${T3APP_USER_PASS}" \
			   --site-name="${T3APP_NAME}"

	if ! grep trustedHostsPattern typo3conf/LocalConfiguration.php >/dev/null ; then
		awk '{print $0} /^\s*.SYS.\s+=>\s+array/ { print "\t\t\"trustedHostsPattern\" => \".*\"," }' \
			typo3conf/LocalConfiguration.php > typo3conf/LocalConfiguration.php_ && \
			mv typo3conf/LocalConfiguration.php_ typo3conf/LocalConfiguration.php
	fi
}
