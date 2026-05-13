# Ricostruzione ambiente

Guida rapida per portare lo stack da zero e verificare che tutto sia tornato pulito. Il database fa parte dello stack Docker, quindi qui viene trattato una sola volta e non ripetuto in ogni comando.

## 1) Reset totale da zero

Da eseguire nella root del progetto, dove si trova `docker-compose.yml`:

```bash
docker compose down -v --remove-orphans
docker image prune -f
docker compose up -d --build --force-recreate
```

Cosa fa:
- `down -v` rimuove container, rete e volumi del progetto
- `--remove-orphans` elimina eventuali container rimasti fuori composizione
- `image prune -f` pulisce le immagini non più usate
- `up -d --build --force-recreate` ricostruisce e ricrea tutto da zero

## 2) Controlli dopo l'avvio

```bash
docker compose ps
docker compose logs -f
```

Se vuoi verificare il backend:

```bash
curl -s http://localhost:3000/health/db
```

Se vuoi verificare il frontend, apri:
- http://localhost:8080

## 3) Riavvio normale senza reset completo

Se non vuoi cancellare i volumi:

```bash
docker compose up -d --build --force-recreate
```

Se vuoi solo fermare tutto:

```bash
docker compose stop
```

Se vuoi spegnere e rimuovere solo i container, lasciando i volumi:

```bash
docker compose down --remove-orphans
```

## 4) Note pratiche

- Il volume Neo4j viene eliminato solo con `down -v`.
- Se i cambiamenti non si vedono, il primo controllo da fare e' `docker compose logs -f`.
- Se il browser mostra ancora contenuti vecchi, fai un hard refresh su `http://localhost:8080`.
