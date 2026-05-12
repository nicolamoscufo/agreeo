# Guida all'avvio del progetto Agreeo

Questo documento spiega come avviare il progetto da zero utilizzando Docker, permettendoti di eseguirlo su qualsiasi PC (Windows, macOS o Linux) senza dover installare manualmente dipendenze di Flutter o Node.js sul tuo sistema.

## Prerequisiti

Assicurati di aver installato sul tuo sistema:
* [Docker](https://docs.docker.com/get-docker/)
* [Docker Compose](https://docs.docker.com/compose/install/) (Spesso incluso con Docker Desktop)

## Passaggi per l'avvio

1. **Configura le variabili d'ambiente (opzionale)**  
   Se hai un token di TheMovieDB (TMDB) per sfruttare le funzionalità relative ai film, apri il file `docker-compose.yml` e aggiungi/modifica la variabile `TMDB_ACCESS_TOKEN` sotto la sezione `environment` del servizio `backend`. Altrimenti, puoi ignorare questo passaggio, ricordando che senza token di TMDB alcune query remote verso i film potrebbero fallire o restituire dati fittizi/vuoti se non presenti nel database locale.

2. **Costruire i container (Build)**  
   Apri il terminale nella root del progetto (dove si trova il file `docker-compose.yml`) ed esegui il seguente comando per buildare le immagini Docker:
   ```bash
   docker-compose build
   ```
   *Nota: La prima Build impiegherà alcuni minuti, specialmente per scaricare l'SDK di Flutter e compilare la Web App e installare i moduli npm del backend.*

3. **Avviare i servizi**  
   Terminata la build, invia il seguente comando per avviare l'intero stack:
   ```bash
   docker compose up -d 
   ```
   L'opzione `-d` permette l'esecuzione in background (detached mode).

4. **Struttura dei Servizi Avviati**  
   Una volta running, potrai accedere ai servizi sui seguenti indirizzi:

   * **App Frontend (Flutter Web)**:
     * Indirizzo: [http://localhost:8080](http://localhost:8080)
     * *Questa è l'interfaccia utente web compilata di Agreeo.*
   * **Database Neo4j (Pannello Web)**:
     * Indirizzo: [http://localhost:7474](http://localhost:7474)
     * Username: `neo4j`
     * Password: `password123`
     * *Questa è console amministrativa da cui puoi visualizzare graficamente nodi del DB ed eseguire comandi Cypher direttamente.*
   * **API Backend (Node.js)**:
     * Indirizzo: `http://localhost:3000`
     * *Viene usato dal frontend. Puoi testarlo con Postman, Bruno, o curl agli endpoint come `http://localhost:3000/auth/login`.*

5. **Visualizzazione Log e Manutenzione**  
   Se desideri vedere in diretta cosa sta succedendo o eventuali errori a livello del backend di Node.js o di Neo4j:
   ```bash
   docker-compose logs -f
   ```

   Per spegnere in modo pulito l'applicazione e i servizi di background preservando i dati nel database:
   ```bash
   docker-compose stop
   ```

   Per eliminare i container e rimuovere i volumi con tutti i dati del database (quindi da usare solo in caso si voglia svuotare tutto, **operazione irreversibile**):
   ```bash
   docker-compose down -v
   ```

## Seed del Database (Opzionale)

Se hai bisogno di popolare il database con dati mock o script come Movielens dopo il primissimo avvio (quando il database Neo4j è completamente vuoto), il servizio NodeJS (backend) ha una cartella `/scripts` e file `seedInitialUsers.js`. Puoi ad esempio entrare nel terminare del backend NodeJS su docker:

```bash
docker exec -it agreeo_backend sh
node seedInitialUsers.js
```
Ovvero, assicurati di eseguire import/script di caricamento dati a seconda di quanto previsto dalla cartella `backend/scripts` (es. `import_movielens.cypher` importabile direttamente dal browser Web di Neo4j sulla porta `7474`).
