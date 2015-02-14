DOCKER_REGISTRY=docker-host.cron.stgt.vpn:5000
IMAGE_NAME=cron/docker-typo3-cms

build:
	docker build --force-rm=true --no-cache=true -t $(IMAGE_NAME) .

push:
	docker tag -f $(IMAGE_NAME) $(DOCKER_REGISTRY)/$(IMAGE_NAME)
	docker push $(DOCKER_REGISTRY)/$(IMAGE_NAME)

pull:
	docker pull $(DOCKER_REGISTRY)/$(IMAGE_NAME)
	docker -t $(DOCKER_REGISTRY)/$(IMAGE_NAME) $(IMAGE_NAME)

clean:
	docker rmi $(IMAGE_NAME)
	docker rmi $(DOCKER_REGISTRY)/$(IMAGE_NAME)
