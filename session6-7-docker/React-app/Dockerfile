# -------------------------
# Stage 1: Build the React app
# -------------------------
FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

RUN npm run build

# -------------------------
# Stage 2: Serve the built files with Nginx
# -------------------------
FROM nginx:alpine

# Vite outputs the production build into /app/dist
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
