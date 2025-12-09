FROM node:20-alpine

WORKDIR /app

RUN npm install -g pm2 serve

COPY package.json .

RUN npm install

COPY . .

RUN npm run build

EXPOSE 3000

CMD ["pm2-runtime", "start", "serve", "--name", "react-app", "--", "-s", "build", "-l", "3000"]

