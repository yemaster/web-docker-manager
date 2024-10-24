#!/bin/bash -e

[ -f .env ] && export $(grep -v '^#' .env | xargs)
if [ "$rootless" -ne 1 ] 2>/dev/null; then
  echo "Exiting because \$rootless is not set to 1."
  exit 1
fi
if [ -z "$host_data_dir" ]; then
  echo "Please set host_data_dir in .env"
  exit 2
fi

ROOTLESS_NAME="$challenge_docker_name-rootless-daemon"
ROOTLESS_NETWORK="$challenge_docker_name-rootless-network"
DIND_IMAGE="docker:25.0-dind-rootless"
RUN_DIR="$host_data_dir/rootless_user/"
DOCKER_DIR="$host_data_dir/rootless_docker/"

sudo rm -rf "$RUN_DIR"
sudo mkdir -p "$RUN_DIR"
sudo chown 1000:1000 "$RUN_DIR"
sudo chmod 700 "$RUN_DIR"
sudo mkdir -p "$DOCKER_DIR"
sudo chown 1000:1000 "$DOCKER_DIR"
sudo chmod 755 "$DOCKER_DIR"

sudo docker rm -f "$ROOTLESS_NAME"
sudo docker network create "$ROOTLESS_NETWORK" || true
sudo docker run -d -v "$RUN_DIR":/run/user/1000 -v "$DOCKER_DIR":/home/rootless/.local/share/docker \
  --name "$ROOTLESS_NAME" --network "$challenge_docker_name-rootless-network" \
  --restart=always -p "127.0.0.1:$port:$port" --privileged "$DIND_IMAGE"

echo "Waiting for rootless daemon to be alive"

set +e
for (( i=1; i<=30; i++ ))
do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --unix-socket "$RUN_DIR"/docker.sock http://localhost/_ping)
  if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "OK!"
    break
  else
    echo "Failed (HTTP $HTTP_STATUS)... ($i/30)"
  fi
  sleep 1
done
set -e

export DOCKER_HOST=unix://"$RUN_DIR"/docker.sock
sudo "DOCKER_HOST=$DOCKER_HOST" docker compose up -d
echo "Set DOCKER_HOST=$DOCKER_HOST when operating inside rootless container..."
