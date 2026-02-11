# Dockerfile pour builder STF sur ARM64
FROM node:18-bullseye AS builder

# Installer les dépendances système
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    python3 \
    pkg-config \
    libzmq3-dev \
    libprotobuf-dev \
    graphicsmagick \
    yasm \
    && rm -rf /var/lib/apt/lists/*

# Cloner et builder STF
WORKDIR /app
RUN git clone --depth 1 https://github.com/DeviceFarmer/stf.git .

# Installer les dépendances et builder
RUN npm install --legacy-peer-deps && \
    npm run build

# Image finale
FROM node:18-bullseye-slim

# Installer les dépendances runtime
RUN apt-get update && apt-get install -y \
    graphicsmagick \
    adb \
    libzmq5 \
    libprotobuf23 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copier l'application buildée
WORKDIR /app
COPY --from=builder /app /app

# Exposer les ports (variables selon le service)
EXPOSE 3000 7150 7160 7170 7250 7260 7270 7400

# Point d'entrée
ENTRYPOINT ["/app/bin/stf"]
CMD ["--help"]
