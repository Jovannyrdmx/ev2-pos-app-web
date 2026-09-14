FROM node:20-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY api/src ./src
COPY data ./data
EXPOSE 3000
CMD ["node", "src/server.js"]
