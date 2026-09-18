# Recommendation Engine - Exam Demo Guide

## Preparazione

Avvia lo stack e verifica gli healthcheck:

```bash
docker compose up -d --build
curl http://localhost:3000/health/db
```

Nel file ambiente locale devono essere attivi:

```text
ENABLE_NEO4J_DEBUG=true
ENABLE_RECOMMENDATION_DEBUG=true
```

Accedi con un utente che abbia completato onboarding e alcuni swipe. Apri:

```text
Settings -> Developer -> Recommendation Lab -> Engine
```

## Sequenza consigliata (8-10 minuti)

### 1. Mostra il grafo

Nei tab `Info`, `Schema` e `Indexes` mostra:

- `AppUser`, `Movie`, `MovieLensMovie`, `MovieLensUser`, `Tag`, `Genre`;
- `LIKED`, `DISLIKED`, `WATCHLISTED`, `RATED`, `MATCHES_TMDB`, `HAS_TAG`;
- constraint di unicita;
- indice vettoriale `tag_embeddings` da 384 dimensioni.

Frase chiave:

> Neo4j non e usato come semplice key-value store: il ranking attraversa relazioni tra l'utente Agreeo, il catalogo TMDB e il grafo storico MovieLens.

### 2. Apri `Engine` e parti dagli input

Mostra i contatori e i segnali positivi/negativi. Spiega i pesi:

```text
SELECTED_FAVORITE = 4.0
LIKED             = 3.0
WATCHLISTED       = 1.25 / 1.5 nel semantico
DISLIKED          = profilo negativo
```

Fai uno screenshot o annota i valori prima della demo.

### 3. Segui la pipeline

La UI presenta cinque stadi:

1. costruzione del profilo utente;
2. collaborative filtering;
3. profilo semantico positivo/negativo;
4. Reciprocal Rank Fusion e diversificazione;
5. coda Daily Suggestions con esplorazione.

Per ogni stadio mostra il numero di elementi in output.

### 4. Spiega le formule

#### Collaborative

```text
weightedPreference = sum(similarity * (rating - 3)) / sum(abs(similarity))
supportWeight = neighbors / (neighbors + shrinkage)
final = blendedPreference * log(neighbors + 1) * 10 - genrePenalty
```

Il rating viene centrato per utilizzare sia giudizi positivi sia negativi. Lo
shrinkage impedisce a pochi vicini di generare punteggi troppo sicuri.

#### Semantic

```text
tagScore = IDF(tag) * log(1 + frequency) * positiveCosine^3
         - negativePenalty * negativeCosine^3
```

Il modello `multilingual-e5-small` genera embedding da 384 dimensioni. I tag
generici pesano meno grazie a IDF.

#### Fusion

```text
RRF(movie) = sum(sourceWeight / (K + rank))
final = 1000 * RRF / (1 + 0.15 * ignoredExposures)
```

RRF combina classifiche con scale diverse senza sommare direttamente score
collaborativi e semantici.

### 5. Apri un film raccomandato

Mostra:

- sorgente `personalized`, `semantic-tag` o `hybrid`;
- collaborative score;
- semantic score;
- posizione nelle due classifiche;
- RRF;
- penalita negative;
- tag semantici corrispondenti;
- motivazione leggibile.

### 6. Mostra il Cypher reale

Apri `Cypher actually executed`. Ogni card contiene:

- query completa;
- parametri sanitizzati;
- tempo di esecuzione;
- numero di record;
- eventuale errore.

Apri almeno queste query:

1. `Collaborative filtering`;
2. `User semantic profile`;
3. `Vector similarity search`;
4. `Exploratory candidates`;
5. `Movie hydration cache`.

La UI mostra anche `computed`, `hit` o `shared-in-flight`: Made for you e
Daily riusano lo stesso calcolo per utente, evitando due query collaborative
concorrenti e il superamento del memory pool transazionale Neo4j.

Usa il pulsante copia per portare una query nel tab `Query` ed eseguirla con
`EXPLAIN` o `PROFILE`.

### 7. Dimostra il feedback loop

1. Vai su Discover.
2. Esegui un like o dislike.
3. Torna al Recommendation Lab e premi refresh.
4. Confronta segnali, candidati, score e query.

La relazione utente-film e l'evento del batch vengono salvati atomicamente. Il
nuovo feedback influenza collaborative, semantic profile e filtri successivi.

### 8. Chiudi con le metriche

Mostra `served`, impressioni, swipe-through rate e variante A/B. Spiega che la
qualita non viene valutata contando i test unitari, ma osservando comportamento,
latenza e metriche del ranking.

## Demo ripetibile prima/dopo

Per rendere visibile una variazione:

1. scegli un film di un genere poco presente nel profilo;
2. annota i primi cinque risultati;
3. metti like al film;
4. aggiorna il Lab;
5. verifica la crescita del genere/tag collegato e il cambiamento della top 5;
6. ripeti con un dislike e osserva `negativePenalty`.

## Query manuali utili

### Profilo utente

```cypher
MATCH (u:AppUser {uid: $uid})-[r]->(m:Movie)
WHERE type(r) IN ['LIKED', 'DISLIKED', 'WATCHLISTED', 'ALREADY_SEEN', 'SELECTED_FAVORITE']
RETURN type(r), m.title, r.createdAt
ORDER BY r.createdAt DESC
```

### Bridge MovieLens-TMDB

```cypher
MATCH (ml:MovieLensMovie)-[:MATCHES_TMDB]->(m:Movie)
RETURN ml.movieLensId, m.tmdbId, m.title
LIMIT 20
```

### Tag e IDF

```cypher
MATCH (ml:MovieLensMovie)-[h:HAS_TAG]->(t:Tag)
RETURN t.name, t.idf, sum(h.frequency) AS frequency
ORDER BY t.idf DESC
LIMIT 20
```

### Eventi del recommender

```cypher
MATCH (b:RecommendationBatch)-[i:INCLUDED]->(m:Movie)
RETURN b.experimentVariant, i.position, i.source, m.title,
       i.impressedAt, i.swipedAt, i.action
ORDER BY b.createdAt DESC, i.position
LIMIT 30
```

## Limiti da dichiarare

- MovieLens Small ha copertura limitata sui film recenti.
- I pesi sono configurabili e vanno validati con A/B test.
- La trace e disponibile solo in debug perche espone dettagli interni.
- La complessita non sostituisce la valutazione: Precision@10, MRR, NDCG,
  coverage, latenza ed error rate restano le metriche decisive.
