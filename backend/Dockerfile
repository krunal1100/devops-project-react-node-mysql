FROM node:20.11-alpine as builder

WORKDIR /app

COPY package*.json .

RUN npm install --production

COPY . .

FROM node:20.11-alpine

WORKDIR /app

RUN npm install pm2 -g

COPY --from=builder /app /app

EXPOSE 4000

CMD ["pm2-runtime", "start", "index.js"]
