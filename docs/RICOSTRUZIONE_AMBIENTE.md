# Ricostruzione ambiente (Docker + Neo4j + Frontend)

Questa guida serve quando le modifiche non vengono applicate o l'ambiente sembra in stato incoerente.

## 1) Rebuild standard (senza cancellare il database)

Usa questa procedura per aggiornare i container mantenendo i dati Neo4j.

1. Ricostruisci e ricrea backend e frontend:
   docker compose up -d --build --force-recreate backend frontend

2. Controlla stato servizi:
   docker compose ps

3. Verifica connessione backend -> Neo4j:
   curl -s http://localhost:3000/health/db

4. Verifica payload movie details (esempio TMDB 550):
   curl -s http://localhost:3000/movies/550

5. Verifica campo director in modo esplicito:
   curl -s http://localhost:3000/movies/550 | node -e "let s='';process.stdin.on('data',d=>s+=d);process.stdin.on('end',()=>{const j=JSON.parse(s);console.log('hasDirectorKey',Object.prototype.hasOwnProperty.call(j.movie,'director'));console.log('directorValue',JSON.stringify(j.movie.director));});"

## 2) Reset totale (anche database)

Usa questa procedura solo se il rebuild standard non basta.

1. Spegni e rimuovi container, rete e volumi:
   docker compose down -v --remove-orphans

2. (Opzionale ma consigliato) Pulisci immagini inutilizzate:
   docker image prune -f

3. Ricostruisci tutto da zero:
   docker compose up -d --build --force-recreate

4. Ricontrolla stato servizi:
   docker compose ps

5. Ricontrolla health backend:
   curl -s http://localhost:3000/health/db

## 3) Verifica che il container backend usi davvero il codice aggiornato

Se la API restituisce ancora dati vecchi, controlla il file nel container:

docker exec agreeo_backend sh -lc "grep -n 'extractDirector\|director: extractDirector\|append_to_response: '\''credits'\''' /usr/src/app/movieController.js"

docker exec agreeo_backend sh -lc "grep -n 'm.director AS director\|m.director = \$director' /usr/src/app/movieRepository.js"

Se i pattern non compaiono, rifai la sezione Rebuild standard.

## 4) Frontend: cache browser

Dopo il rebuild frontend, fai hard refresh su http://localhost:8080:
- macOS: Cmd + Shift + R

## 5) Note utili

- Il warning su docker-compose relativo a version e' innocuo.
- Puoi rimuovere la riga version: '3.8' dal file docker-compose.yml per evitare il warning.
- Se docker compose up -d termina con successo ma i dati sembrano vecchi, il problema e' quasi sempre cache immagine/container non ricreato o browser cache.
