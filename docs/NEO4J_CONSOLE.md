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
| **Indici** | `SHOW INDEXES` + `SHOW CONSTRAINTS`; il vector index `tag_embeddings` è evidenziato con dimensioni (384) e similarity function (cosine) | `GET /debug/neo4j/indexes` |
| **Query** | Console Cypher live con preset, timing reali (wall time + resultAvailableAfter/resultConsumedAfter) e piano di esecuzione con `EXPLAIN`/`PROFILE` (operatori, estimated rows, db hits) | `POST /debug/neo4j/query` |

## Sicurezza

- Le query della console girano in una **read transaction**
  (`session.readTransaction`): è Neo4j stesso a rifiutare qualunque scrittura
  con `Neo.ClientError.Statement.AccessMode`, senza parsing lato server.
- I risultati sono limitati a 200 righe per risposta.
- Flag opt-in + JWT: in un deployment reale il flag resta `false`.

## Scaletta demo suggerita (esame)

1. **Info** — architettura: un solo database, due "mondi" collegati
   (AppUser/Movie da TMDB, MovieLensUser/MovieLensMovie/Tag dal dataset).
2. **Schema** — il bridge `[:MATCHES_TMDB]` tra i due mondi e le relazioni di
   interazione (`LIKED`, `RATED`, `HAS_TAG`, `FRIEND`...).
3. **Indici** — constraint di unicità creati da `neo4jService.createConstraints()`
   all'avvio, indici range sulle property calde e il **vector index** a 384
   dimensioni per la ricerca semantica.
4. **Query** — preset in ordine crescente di complessità:
   - *Top film* (lookup semplice con ordinamento)
   - *Bridge TMDB-MovieLens* (traversal tra i due dataset)
   - *Collaborative filtering* (la query di raccomandazione: utenti simili via
     rating, esclusione dei film già visti)
   - *Vector search* (`db.index.vector.queryNodes` sui tag embedding)
   - ripetere una di queste con **PROFILE** attivo per mostrare il piano di
     esecuzione e i db hits (es. confronto con/senza indice).
