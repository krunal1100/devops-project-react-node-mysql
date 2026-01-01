#!/bin/bash
set -euo pipefail

########################################
# CONFIG
########################################
NETWORK=devops
APP_DIR=/home/ubuntu/app
BACKEND_IMAGE="krunal1100/three-tire-backend:${IMAGE_TAG}"
FRONTEND_IMAGE="krunal1100/three-tire-frontend:${IMAGE_TAG}"

########################################
# PRECHECKS
########################################
if [ -z "${IMAGE_TAG:-}" ]; then
  echo "❌ IMAGE_TAG not set"
  exit 1
fi

echo "▶ Deploying IMAGE_TAG=${IMAGE_TAG}"

########################################
# NETWORK
########################################
echo "▶ Ensure Docker network"
docker network inspect $NETWORK >/dev/null 2>&1 || docker network create $NETWORK

########################################
# MYSQL (PERSISTENT)
########################################
echo "▶ Ensure MySQL"
if ! docker ps -a --format '{{.Names}}' | grep -q '^mysql_db$'; then
  docker run -d \
    --name mysql_db \
    --network $NETWORK \
    -e MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
    -e MYSQL_DATABASE="${MYSQL_DATABASE}" \
    -e MYSQL_USER="${MYSQL_USER}" \
    -e MYSQL_PASSWORD="${MYSQL_PASSWORD}" \
    -v mysql_data:/var/lib/mysql \
    --restart unless-stopped \
    mysql:8.0
else
  docker start mysql_db >/dev/null
fi

########################################
# BACKEND (BLUE / GREEN)
########################################
echo "▶ Backend blue/green deploy"

if docker ps --format '{{.Names}}' | grep -q backend_blue; then
  ACTIVE=blue
  NEW=green
else
  ACTIVE=green
  NEW=blue
fi

echo "▶ Active=$ACTIVE → Deploying=$NEW"

# 🔴 IMPORTANT: remove active FIRST (free alias)
if docker ps --format '{{.Names}}' | grep -q backend_${ACTIVE}; then
  echo "▶ Removing active backend_${ACTIVE}"
  docker rm -f backend_${ACTIVE}
fi

# ✅ Start new backend and claim alias
docker run -d \
  --name backend_${NEW} \
  --network $NETWORK \
  --network-alias backend \
  -e DB_HOST=mysql_db \
  -e DB_USER="${MYSQL_USER}" \
  -e DB_PASSWORD="${MYSQL_PASSWORD}" \
  -e DB_NAME="${MYSQL_DATABASE}" \
  --restart unless-stopped \
  ${BACKEND_IMAGE}

echo "▶ Waiting for backend health"
sleep 10

if ! docker exec backend_${NEW} wget -qO- http://localhost:4000/health >/dev/null; then
  echo "❌ Backend health failed"
  docker rm -f backend_${NEW}
  exit 1
fi

echo "✅ Backend now active: backend_${NEW}"

########################################
# FRONTEND
########################################
echo "▶ Deploy frontend"
docker rm -f frontend_app || true
docker run -d \
  --name frontend_app \
  --network $NETWORK \
  --restart unless-stopped \
  ${FRONTEND_IMAGE}

########################################
# NGINX (REVERSE PROXY + SSL)
########################################
echo "▶ Deploy nginx"
docker rm -f nginx_proxy || true
docker run -d \
  --name nginx_proxy \
  --network $NETWORK \
  -p 80:80 -p 443:443 \
  -v $APP_DIR/nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro \
  -v $APP_DIR/certbot/www:/var/www/certbot \
  -v $APP_DIR/certbot/conf:/etc/letsencrypt \
  --restart unless-stopped \
  nginx:alpine

########################################
# MONITORING (PROMETHEUS / GRAFANA / EXPORTERS / ALERTMANAGER)
########################################
echo "▶ Deploy monitoring stack"
cd $APP_DIR
docker compose -f docker-compose-monitor.yml up -d

########################################
# FINAL STATUS
########################################
echo "======================================"
echo "✅ LIVE DEPLOYMENT COMPLETE"
echo "Backend image : ${BACKEND_IMAGE}"
echo "Frontend image: ${FRONTEND_IMAGE}"
echo "Network       : ${NETWORK}"
echo "======================================"
