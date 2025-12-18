#!/bin/bash
set -e

NETWORK=devops
APP_DIR=/home/ubuntu/app

echo "▶ Ensure Docker network"
docker network inspect $NETWORK >/dev/null 2>&1 || docker network create $NETWORK

echo "▶ Ensure MySQL"
if ! docker ps -a --format '{{.Names}}' | grep -q '^mysql_db$'; then
  docker run -d \
    --name mysql_db \
    --network $NETWORK \
    -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
    -e MYSQL_DATABASE=$MYSQL_DATABASE \
    -e MYSQL_USER=$MYSQL_USER \
    -e MYSQL_PASSWORD=$MYSQL_PASSWORD \
    -v mysql_data:/var/lib/mysql \
    --restart unless-stopped \
    mysql:8.0
fi

echo "▶ Deploy backend"
docker rm -f backend_active || true
docker run -d \
  --name backend_active \
  --network $NETWORK \
  -e DB_HOST=mysql_db \
  -e DB_USER=$MYSQL_USER \
  -e DB_PASSWORD=$MYSQL_PASSWORD \
  -e DB_NAME=$MYSQL_DATABASE \
  --restart unless-stopped \
  krunal1100/three-tire-backend:$IMAGE_TAG

echo "▶ Deploy frontend"
docker rm -f frontend_app || true
docker run -d \
  --name frontend_app \
  --network $NETWORK \
  --restart unless-stopped \
  krunal1100/three-tire-frontend:$IMAGE_TAG

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

echo "▶ Deploy monitoring"
docker compose -f docker-compose.monitor.yml up -d

echo "✅ LIVE deployment complete"
