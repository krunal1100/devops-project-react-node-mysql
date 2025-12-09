FROM node:20-alpine

WORKDIR /app

RUN npm install pm2 -g

COPY package.json .

RUN npm install

COPY . .

EXPOSE 4000

CMD ["pm2-runtime", "start", "index.js"]
