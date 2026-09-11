# Deploy Agreeo su Azure

Questa guida spiega come caricare Agreeo su Azure e far funzionare l'app con una VM Ubuntu, Docker Compose, backend Node, frontend Flutter web e Neo4j persistente.

## Scelta consigliata

Usa una VM Ubuntu con Docker Compose.

- Mantiene l'architettura attuale senza refactor.
- Supporta backend Node, Socket.io e Neo4j nello stesso stack.
- Evita di esporre Neo4j pubblicamente.
- Permette di usare Azure for Students senza servizi gestiti aggiuntivi.

## 1. Pubblica questi file su GitHub

Da macchina locale, committa e pusha i file Azure. Non includere modifiche non correlate, per esempio `lib/main.dart` se risulta modificato localmente.

```bash
git add .gitignore README.md .env.azure.example docker-compose.azure.yml deploy/azure/README.md
git commit -m "docs: add azure vm deployment path"
git push origin main
```

## 2. Crea la VM Azure

Nel portale Azure crea una nuova Virtual Machine con questi valori:

- Subscription: Azure for Students.
- Image: Ubuntu 24.04 LTS oppure Ubuntu 22.04 LTS.
- Size consigliata: `Standard_B2s`.
- Size minima per demo breve: `Standard_B1ms`.
- Evita `B1s` se vuoi importare MovieLens in Neo4j.
- OS disk: almeno 30 GB.
- Authentication: SSH key.

Configura le porte inbound nel Network Security Group:

- `22` SSH: consentila solo dal tuo IP.
- `80` HTTP: pubblico, serve il frontend Flutter web.
- `3000` Backend API: pubblico per test e app frontend.
- Non aprire `7474` e `7687`, sono porte Neo4j e devono restare private.

Prendi nota del public IP della VM, ti servira come `<vm-public-ip>`.

## 3. Entra nella VM

Dal tuo computer:

```bash
ssh <azure-user>@<vm-public-ip>
```

## 4. Installa Docker e Git nella VM

Esegui questi comandi nella VM:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git
curl -fsSL https://get.docker.com | sudo sh
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
newgrp docker
```

Verifica Docker:

```bash
docker --version
docker compose version
```

## 5. Clona il repository

Sempre nella VM:

```bash
git clone https://github.com/screamkface/agreeo.git
cd agreeo
```

## 6. Crea il file di configurazione Azure

```bash
cp .env.azure.example .env.azure
```

Apri il file:

```bash
nano .env.azure
```

Imposta almeno questi valori:

```txt
NEO4J_PASSWORD=<password forte per neo4j>
JWT_SECRET=<segreto jwt lungo>
TMDB_ACCESS_TOKEN=<token bearer tmdb>
BACKEND_BASE_URL=http://<vm-public-ip>:3000
BACKEND_PUBLIC_PORT=3000
FRONTEND_PUBLIC_PORT=80
NEO4J_HTTP_BIND=127.0.0.1
NEO4J_BOLT_BIND=127.0.0.1
```

Genera `JWT_SECRET` con:

```bash
openssl rand -hex 32
```

Il file `.env.azure` contiene segreti reali e non deve essere committato.

## 7. Avvia lo stack

Nella root del repo sulla VM:

```bash
docker compose --env-file .env.azure -f docker-compose.azure.yml up -d --build
```

Il primo avvio puo richiedere qualche minuto perche `neo4j-init` importa il dataset MovieLens.

## 8. Verifica dalla VM

Controlla che i container siano avviati:

```bash
docker compose --env-file .env.azure -f docker-compose.azure.yml ps
```

Controlla il backend e Neo4j:

```bash
curl http://localhost:3000/health/db
```

Se qualcosa non parte, leggi i log:

```bash
docker compose --env-file .env.azure -f docker-compose.azure.yml logs backend
docker compose --env-file .env.azure -f docker-compose.azure.yml logs neo4j
docker compose --env-file .env.azure -f docker-compose.azure.yml logs neo4j-init
```

## 9. Verifica dal tuo computer

Dal tuo computer locale:

```bash
curl http://<vm-public-ip>:3000/health/db
```

Apri il frontend nel browser:

```txt
http://<vm-public-ip>
```

L'app deve chiamare il backend su:

```txt
http://<vm-public-ip>:3000
```

Questo valore viene inserito nel build Flutter tramite `BACKEND_BASE_URL`.

## 10. Accedi a Neo4j Browser in modo sicuro

Non aprire le porte Neo4j su Azure. Usa un tunnel SSH dal tuo computer:

```bash
ssh -L 7474:localhost:7474 -L 7687:localhost:7687 <azure-user>@<vm-public-ip>
```

Poi apri:

```txt
http://localhost:7474
```

Credenziali:

```txt
username: neo4j
password: valore di NEO4J_PASSWORD in .env.azure
```

## Aggiornare l'app dopo nuove modifiche

Nella VM:

```bash
cd agreeo
git pull
docker compose --env-file .env.azure -f docker-compose.azure.yml up -d --build
```

## Fermare o cancellare lo stack

Ferma i container mantenendo i dati Neo4j:

```bash
docker compose --env-file .env.azure -f docker-compose.azure.yml stop
```

Cancella container e volume Neo4j:

```bash
docker compose --env-file .env.azure -f docker-compose.azure.yml down -v
```

Usa `down -v` solo se vuoi eliminare anche i dati del database.

## Note per demo pubblica

Per una demo rapida basta `http://<vm-public-ip>`. Prima di condividere l'app pubblicamente, aggiungi dominio e HTTPS con Caddy o Nginx. In quel caso aggiorna `BACKEND_BASE_URL` con l'URL HTTPS del backend e ricostruisci il frontend. Conserva le credenziali esclusivamente in `.env.azure` e ruota immediatamente qualsiasi segreto pubblicato per errore.

## Upgrade Neo4j

Locale e Azure usano lo stesso digest Neo4j. Prima di aggiornare quel digest,
crea un dump o snapshot del volume e prova il ripristino su un volume separato.
Non tentare downgrade del formato store. La procedura minima è:

```bash
docker compose --env-file .env.azure -f docker-compose.azure.yml stop
```

Con i container fermi, crea uno snapshot del disco gestito Azure che contiene il
volume `neo4j_data` e verifica il ripristino su una VM separata. Conserva lo
snapshot fino al completamento dei test di lettura e scrittura sul nuovo digest.
