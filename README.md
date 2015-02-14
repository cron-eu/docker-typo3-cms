TYPO3 CMS | Docker image
========================

This is a TYPO3 CMS Docker-Image for development, heavily inspired by:

https://github.com/million12/docker-typo3-neos

which we're using for Flow/Neos-Development.

Current Status
--------------

Currently WIP, use this image at your own risk:)

## Usage

Set the variables in the `Dockerfile` and then call `make`.

### Select the TYPO3 CMS Version

The variable `T3APP_BUILD_BRANCH` in the Dockerfile selects the TYPO3
CMS branch and defaults to `TYPO3_6-2` (the current 6.2 LTS
Release). Make sure to rebuild the image using `make` afterwards.

### fig

After the Image was successfully built, you can kickstart a fresh
TYPO3 CMS environment using fig:

```
fig up -d
```

Make sure to also adapt the settings in the fig-file to suit your
needs (hostnames, github user etc.).

### Import an existing Site

```
export T3APP_VHOST_NAMES
make site=daz.preview.cron.eu db=daz_preview
```

Make sure to put your ssh-pub-key in `authorized_keys` from the user
`www-data` on the remote server.
