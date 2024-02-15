FROM node:20.11.0-alpine
WORKDIR /usr/src/app
COPY package*.json ./
COPY ./src ./src
RUN npm install
EXPOSE 3000
CMD ["node", "src/index.js"]