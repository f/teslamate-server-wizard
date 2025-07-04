services:
  traefik:
    image: traefik:v3.2
    restart: always
    command:
      - --api.insecure=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --providers.docker.network=teslamate
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      # HTTP to HTTPS redirect
      - --entrypoints.web.http.redirections.entrypoint.to=websecure
      - --entrypoints.web.http.redirections.entrypoint.scheme=https
      # Let's Encrypt
      - --certificatesresolvers.letsencrypt.acme.tlschallenge=true
      - --certificatesresolvers.letsencrypt.acme.email={{ LETSENCRYPT_EMAIL }}
      - --certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080" # Traefik dashboard (optional, remove for production)
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
    networks:
      - teslamate

  teslamate:
    image: teslamate/teslamate:latest
    restart: always
    environment:
      - ENCRYPTION_KEY={{ ENCRYPTION_KEY }}
      - DATABASE_USER=teslamate
      - DATABASE_PASS={{ DATABASE_PASS }}
      - DATABASE_NAME=teslamate
      - DATABASE_HOST=database
      - MQTT_HOST=mosquitto
    volumes:
      - ./import:/opt/app/import
    cap_drop:
      - all
    mem_limit: 4g
    memswap_limit: 4g
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=teslamate"
      # HTTP router (will redirect to HTTPS)
      - "traefik.http.routers.teslamate.rule=Host(`{{ DOMAIN }}`)"
      - "traefik.http.routers.teslamate.entrypoints=web"
      # HTTPS router
      - "traefik.http.routers.teslamate-secure.rule=Host(`{{ DOMAIN }}`)"
      - "traefik.http.routers.teslamate-secure.entrypoints=websecure"
      - "traefik.http.routers.teslamate-secure.tls=true"
      - "traefik.http.routers.teslamate-secure.tls.certresolver=letsencrypt"
      - "traefik.http.routers.teslamate-secure.middlewares=teslamate-auth"
      # Service definition
      - "traefik.http.services.teslamate.loadbalancer.server.port=4000"
      # Basic auth middleware
      - "traefik.http.middlewares.teslamate-auth.basicauth.users={{ BASIC_AUTH }}"
    networks:
      - teslamate
    depends_on:
      - database
      - mosquitto

  database:
    image: postgres:17
    restart: always
    environment:
      - POSTGRES_USER=teslamate
      - POSTGRES_PASSWORD={{ DATABASE_PASS }}
      - POSTGRES_DB=teslamate
    ports:
      - "5432:5432"
    volumes:
      - teslamate-db:/var/lib/postgresql/data
    networks:
      - teslamate

  grafana:
    image: teslamate/grafana:latest
    restart: always
    environment:
      - DATABASE_USER=teslamate
      - DATABASE_PASS={{ DATABASE_PASS }}
      - DATABASE_NAME=teslamate
      - DATABASE_HOST=database
      - MQTT_HOST=mosquitto
      - TZ={{ TIMEZONE }}
    volumes:
      - teslamate-grafana-data:/var/lib/grafana
      - {{ CURRENT_DIRECTORY }}/Teslamate-CustomGrafanaDashboards/customdashboards.yml:/etc/grafana/provisioning/dashboards/customdashboards.yml
      - {{ CURRENT_DIRECTORY }}/Teslamate-CustomGrafanaDashboards/dashboards:/TeslamateCustomDashboards
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=teslamate"
      # HTTP router (will redirect to HTTPS)
      - "traefik.http.routers.grafana.rule=Host(`{{ STATS_DOMAIN }}`)"
      - "traefik.http.routers.grafana.entrypoints=web"
      # HTTPS router
      - "traefik.http.routers.grafana-secure.rule=Host(`{{ STATS_DOMAIN }}`)"
      - "traefik.http.routers.grafana-secure.entrypoints=websecure"
      - "traefik.http.routers.grafana-secure.tls=true"
      - "traefik.http.routers.grafana-secure.tls.certresolver=letsencrypt"
      - "traefik.http.routers.grafana-secure.middlewares=grafana-auth"
      # Service definition
      - "traefik.http.services.grafana.loadbalancer.server.port=3000"
      # Basic auth middleware
      - "traefik.http.middlewares.grafana-auth.basicauth.users={{ BASIC_AUTH }}"
    networks:
      - teslamate
    depends_on:
      - database

  mosquitto:
    image: eclipse-mosquitto:2
    restart: always
    command: mosquitto -c /mosquitto-no-auth.conf
    ports:
      - "127.0.0.1:1883:1883"
    volumes:
      - mosquitto-conf:/mosquitto/config
      - mosquitto-data:/mosquitto/data
    networks:
      - teslamate

networks:
  teslamate:
    driver: bridge

volumes:
  teslamate-db:
  teslamate-grafana-data:
  mosquitto-conf:
  mosquitto-data:
