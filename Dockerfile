#
# million12/typo3-flow-neos-abstract
#
FROM million12/php-app:latest
MAINTAINER Marcin Ryzycki marcin@m12.io

# Add all files from container-files/ to the root of the container's filesystem
ADD container-files /

#
# This is "abstract" million12/typo3-flow-neos-abstract image and it doesn't do anything on its own.
# It is designed to easily build sub-images which will run any TYPO3 Flow and/or Neos version.
# See README.md for more information.
#
# Configure image build with following ENV variables:
# Checkout to specified branch/tag name
#ENV T3APP_BUILD_BRANCH 1.1.2
# Repository for installed TYPO3 Flow or Neos distribution 
#ENV T3APP_BUILD_REPO_URL git://git.typo3.org/Neos/Distributions/Base.git
# Composer install parameters
#ENV T3APP_BUILD_COMPOSER_PARAMS --dev --prefer-source
#
# If you need to access your private repository, you'll need to add ssh keys to the image
# and configure SSH to use them. You can do this in following way:
# ADD gh-repo-key /
# RUN \
#   chmod 600 /gh-repo-key && \
#   echo "IdentityFile /gh-repo-key" >> /etc/ssh/ssh_config
#
# In your image based on this one you will have to run this script:
#RUN . /build-typo3-app/pre-install-typo3-app.sh
