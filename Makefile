build:
	docker build --force-rm=true --no-cache=true -t cron/docker-typo3-cms .

clean:
	docker rmi cron/docker-typo3-cms
