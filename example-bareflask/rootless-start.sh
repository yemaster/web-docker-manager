#!/bin/bash -e

[ -f .env ] && source .env
if [ "$rootless" -ne 1 ] 2>/dev/null; then
  echo "Exiting because \$rootless is not set to 1."
  exit 1
fi
if [ -z "$host_data_dir" ]; then
  echo "Please set host_data_dir in .env"
  exit 2
fi

RUN_DIR="$PWD/run"
VOL_DIR="${host_data_dir}/vol"

start() {
	sudo mkdir -p "${VOL_DIR}"
	sudo chown 1000:1000 "${VOL_DIR}"
	sudo chmod 755 "${VOL_DIR}"

	docker compose -f docker-compose-rootless.yml up -d --build --remove-orphans
	
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
	sudo "DOCKER_HOST=$DOCKER_HOST" docker compose up -d --build
	echo "Set DOCKER_HOST=$DOCKER_HOST when operating inside rootless container..."
}

stop() {
	DOCKER_SOCK="$RUN_DIR"/docker.sock
	DOCKER_HOST=unix://"$RUN_DIR"/docker.sock
	if socat -u OPEN:/dev/null UNIX-CONNECT:"$DOCKER_SOCK"; then
		sudo "DOCKER_HOST=$DOCKER_HOST" docker compose down
	fi
	sudo docker compose -f docker-compose-rootless.yml down
}

update() {
	DOCKER_HOST=unix://"$RUN_DIR"/docker.sock
	DOCKER_SOCK="$RUN_DIR"/docker.sock
	if socat -u OPEN:/dev/null UNIX-CONNECT:"$DOCKER_SOCK"; then
		sudo "DOCKER_HOST=$DOCKER_HOST" docker compose up -d --build --remove-orphans
	else
		start
	fi
}

case "${1}" in
	start|stop|update)
		"${1}"
		;;
	*)
		echo "Usage: start|stop|update"
		;;
esac
