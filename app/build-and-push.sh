#!/bin/bash

REGISTRY_ID="your-registry-id"
IMAGE_NAME="diploma-app"
TAG=${1:-latest}

docker build -t cr.yandex/$REGISTRY_ID/$IMAGE_NAME:$TAG .
docker push cr.yandex/$REGISTRY_ID/$IMAGE_NAME:$TAG
echo "Image pushed: cr.yandex/$REGISTRY_ID/$IMAGE_NAME:$TAG"
