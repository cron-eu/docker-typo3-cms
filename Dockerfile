#
# million12/typo3-flow-neos-abstract
#
FROM million12/php-app:latest
MAINTAINER Remus Lazar <rl@cron.eu>

# Add all files from container-files/ to the root of the container's filesystem
ADD container-files /

# Configure image build with following ENV variables:
# Checkout to specified branch/tag name
ENV T3APP_BUILD_BRANCH 6.2
# Repository for installed TYPO3 Flow or Neos distribution
ENV T3APP_BUILD_REPO_URL https://github.com/cron-eu/TYPO3.CMS.Console.Distribution.git
# Composer install parameters
#ENV T3APP_BUILD_COMPOSER_PARAMS --dev --prefer-source
#
# If you need to access your private repository, you'll need to add ssh keys to the image
# and configure SSH to use them. You can do this in following way:
ADD gh-repo-key /
RUN \
  chmod 600 /gh-repo-key && \
  echo "IdentityFile /gh-repo-key" >> /etc/ssh/ssh_config

# In your image based on this one you will have to run this script:
RUN . /build-typo3-app/pre-install-typo3-app.sh
