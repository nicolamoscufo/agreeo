# Build stage
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy dependencies first to cache them
COPY pubspec.* ./
RUN flutter pub get

# Copy all the app source
COPY . .

# Build the web version
RUN flutter build web --release

# Serve with nginx
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
