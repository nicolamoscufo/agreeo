# Neo4j Console (debug in-app)

Schermata read-only dentro l'app (**Settings → Developer → Neo4j Console**) per
dimostrare dal vivo la configurazione e il funzionamento di Neo4j durante la
presentazione del progetto.

## Abilitazione

La console è spenta di default. Si abilita sul backend con:

```
ENABLE_NEO4J_DEBUG=true
```

(nel `.env` per docker-compose, già previsto in `.env.example`). Gli endpoint
richiedono comunque un JWT valido; con il flag a `false` rispondono `404`.

## Cosa mostra

| Tab | Contenuto | Endpoint |
|-----|-----------|----------|
| **Info** | Versione/edizione del server, URI bolt, conteggi nodi/relazioni/property key, nodi per label e relazioni per tipo | `GET /debug/neo4j/overview` |
| **Schema** | I pattern reali del grafo `(:From)-[:REL]->(:To)` con il numero di relazioni per ciascuno | `GET /debug/neo4j/schema` |
| **Indexes** | `SHOW INDEXES` + `SHOW CONSTRAINTS`; il vector index `tag_embeddings` è evidenziato con dimensioni (384) e similarity function (cosine) | `GET /debug/neo4j/indexes` |
| **Query** | Console Cypher live con preset, timing reali (wall time + resultAvailableAfter/resultConsumedAfter) e piano di esecuzione con `EXPLAIN`/`PROFILE` (operatori, estimated rows, db hits). Accetta una mappa di parametri JSON; `$uid` è sempre associato all'utente autenticato | `POST /debug/neo4j/query` |
| **Live** | Cronologia breve delle azioni realmente eseguite (like, dislike, watchlist, visto, rimozioni, libreria) con query, parametri sanitizzati, contatori, stato della transazione (committed/rolled_back/commit_unknown), snapshot prima/dopo delle relazioni, **mini-grafo** del diff, **percorso reale della raccomandazione**, **confronto classifica** e libreria corrente. Aggiornamento ogni 2 s più push Socket.IO, senza ricalcolare le raccomandazioni | `GET /debug/neo4j/live`, `GET /debug/neo4j/recommendation-path` |

## Tracing Live

- `neo4jService.captureQueryTrace()` usa `AsyncLocalStorage`: le query della
  richiesta (anche dentro `tx.run`) finiscono nel tab **Live** senza threading
  manuale.
- Lo snapshot prima/dopo è letto nella stessa transazione dell'azione. Se la
  transazione viene annullata, lo stato persistito non cambia.
- Lo storico è in memoria per processo: ultime 30 azioni per utente, scadenza
  dopo 30 minuti di inattività, perso al riavvio del backend.
- I parametri sono sanitizzati (`uid`, array lunghi, password/token) e la trace
  è limitata alle prime 100 query per richiesta.
- A commit concluso il backend emette `neo4j_live_action` nella stanza
  dell'utente; il payload è solo un segnale di risveglio, il tab rilegge sempre
  lo storico autoritativo.
- **Open in Query tab** trasferisce testo e parametri non sanitizzati
  (`<current-user>`, `<array:N>` e `<redacted>` vengono esclusi e contati).

### Mini-grafo del diff

Il pannello disegna i due nodi `(:AppUser)` e `(:Movie)` e, per ogni tipo di
relazione, una freccia: verde piena se creata, rossa tratteggiata se rimossa,
grigia se invariata. È una vista derivata dagli snapshot, non una query extra.

### Percorso reale della raccomandazione

`GET /debug/neo4j/recommendation-path` restituisce un cammino realmente
esistente per l'utente autenticato:

```text
(AppUser)-[:LIKED]->(Movie)<-[:MATCHES_TMDB]-(MovieLensMovie)
<-[:RATED]-(MovieLensUser)-[:RATED]->(MovieLensMovie)-[:MATCHES_TMDB]->(Movie)
```

Il risultato è limitato a un cammino e il limite delle relazioni attraversate
(input) è imposto nella query; ogni segmento espone titolo, ID e rating. È una
illustrazione didattica: il ranking di produzione aggrega più vicini e la
componente semantica.

### Confronto classifica

I pulsanti **Capture ranking** e **Recompute and compare** eseguono
esplicitamente il report del tab Engine (bypass cache) e mostrano nuovi,
usciti e spostati. Le azioni osservate non toccano il ranking: il confronto
richiede un passaggio voluto, così la demo distingue l'osservazione delle
scritture dal ricalcolo del motore.

## Sicurezza

- Le query della console girano in una **read transaction**
  (`session.readTransaction`): è Neo4j stesso a rifiutare qualunque scrittura
  con `Neo.ClientError.Statement.AccessMode`, senza parsing lato server.
- I risultati sono limitati a 200 righe per risposta.
- Flag opt-in + JWT: in un deployment reale il flag resta `false`.
- Lo storico Live è separato per `uid` autenticato e non è mai condiviso.

## Scaletta demo suggerita (esame)

0. **Live** — esegui un like/dislike/watchlist nell'app e mostra nel tab Live la
   transazione (`committed`), le query con i contatori, il mini-grafo con
   frecce verdi/rosse e il diff `absent → present` / `present → absent`;
   poi il **percorso reale** e la libreria aggiornata. Con **Capture
   ranking** / **Recompute and compare** mostri l'effetto sul ranking.
   Chiudi aprendo una query nel tab **Query** e lanciandola con `PROFILE`.

1. **Info** — architettura: un solo database, due "mondi" collegati
   (AppUser/Movie da TMDB, MovieLensUser/MovieLensMovie/Tag dal dataset).
2. **Schema** — il bridge `[:MATCHES_TMDB]` tra i due mondi e le relazioni di
   interazione (`LIKED`, `RATED`, `HAS_TAG`, `FRIEND`...).
3. **Indexes** — constraint di unicità creati da `neo4jService.createConstraints()`
   all'avvio, indici range sulle property calde e il **vector index** a 384
   dimensioni per la ricerca semantica.
4. **Query** — preset in ordine crescente di complessità:
   - *Top movies* (lookup semplice con ordinamento)
   - *Bridge TMDB-MovieLens* (traversal tra i due dataset)
   - *Collaborative filtering* (la query di raccomandazione: utenti simili via
     rating, esclusione dei film già visti)
   - *Vector search* (`db.index.vector.queryNodes` sui tag embedding)
   - ripetere una di queste con **PROFILE** attivo per mostrare il piano di
     esecuzione e i db hits (es. confronto con/senza indice).
