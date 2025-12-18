#!/usr/bin/env bash
set -euo pipefail

NETWORK="devops"

# Ensure Docker network exists
if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK}$"; then
  echo "Docker network '${NETWORK}' not found. Creating it..."
  docker network create "${NETWORK}"
fi

if [ $# -ne 1 ]; then
  echo "Usage: $0 <image-tag>"
  exit 1
fi

TAG="$1"
REPO="krunal1100/three-tire-backend"
NETWORK="devops"
NGINX_CONTAINER="nginx_proxy"

# derive names
IMAGE="$REPO:$TAG"

echo "Pulling image $IMAGE..."
docker pull "$IMAGE"

# decide which color to bring up
if docker ps -a --format '{{.Names}}' | grep -q '^backend_blue$'; then
  # if nginx currently points to blue, we'll start green; otherwise blue
  if docker exec "$NGINX_CONTAINER" grep -q 'backend_blue' /etc/nginx/conf.d/default.conf 2>/dev/null; then
    NEW="backend_green"
  else
    NEW="backend_blue"
  fi
else
  NEW="backend_blue"
fi
OLD=$( [ "$NEW" = "backend_blue" ] && echo backend_green || echo backend_blue )

echo "New container will be: $NEW  (old: $OLD)"

# remove any previous container with the new name
docker rm -f "$NEW" 2>/dev/null || true

# launch new backend container from pulled image
docker run -d --name "$NEW" \
  --network "$NETWORK" \
  -e DB_HOST=mysql -e DB_USER="${MYSQL_USER:-devuser}" -e DB_PASSWORD="${MYSQL_PASSWORD:-devuserpassword}" -e DB_NAME="${MYSQL_DATABASE:-devopsdb}" \
  "$IMAGE"

# wait for /health to be ok
echo "Waiting for /health on $NEW..."
for i in $(seq 1 30); do
  if docker exec "$NEW" sh -c "wget -qO- http://localhost:4000/health 2>/dev/null || true" | grep -qi 'ok'; then
    echo "Health OK"
    break
  fi
  sleep 2
done

# update nginx upstream: replace server backend_xxx:4000 with new
echo "Updating nginx upstream to $NEW..."
sed -i "s/server backend_.*:4000;/server $NEW:4000;/" nginx/nginx.conf || true

# copy new config into nginx container and reload
if docker ps -a --format '{{.Names}}' | grep -q "$NGINX_CONTAINER"; then
  docker cp nginx/nginx.conf "$NGINX_CONTAINER":/etc/nginx/conf.d/default.conf
  docker kill -s HUP "$NGINX_CONTAINER"
  echo "Nginx reloaded"
else
  echo "WARNING: nginx container $NGINX_CONTAINER not found – please ensure nginx proxy is running"
fi

# remove old container
echo "Removing old container $OLD (if exists)..."
docker rm -f "$OLD" 2>/dev/null || true

echo "Blue/Green deploy complete. Live: $NEW"
