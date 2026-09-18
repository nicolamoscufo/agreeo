# Agreeo — Proposta demo Data Management di 5 minuti

## Obiettivo

Mostrare una catena verificabile: **azione utente → query Cypher effettive → commit → relazioni e liste aggiornate → nuove raccomandazioni**.

Analisi del 18 settembre 2026, confrontata con i sorgenti locali. La prima parte è già implementata nella branch `feat/neo4j-live-demo`: vedi la sezione 6 per lo stato.

### Stato nella branch `feat/neo4j-live-demo`

| Intervento | Stato |
| --- | --- |
| Tracing delle query dentro `tx.run` con commit/rollback/retry | Fatto |
| Storico per utente (30 azioni, 30 minuti, in memoria) e `GET /debug/neo4j/live` | Fatto |
| Snapshot prima/dopo nella stessa transazione per like, dislike, watchlist, visto e rimozioni | Fatto |
| Tab **Live**: cronologia, diff, query con contatori e libreria filtrabile | Fatto |
| Parametri JSON nella console Query, con `$uid` legato all'utente autenticato | Fatto |
| Mini-grafo visivo del diff (verde creata, rosso rimossa, grigio invariata) | Fatto |
| Percorso reale della raccomandazione con titoli e rating (`/debug/neo4j/recommendation-path`) | Fatto |
| Confronto classifica esplicito con nuovi/usciti/spostati | Fatto |
| Socket.IO push della trace a commit concluso, con polling di riserva | Fatto |
| Open in Query tab dal dettaglio Live, con filtraggio dei parametri sanitizzati | Fatto |

## 1. Cosa esiste già

| Componente | Stato verificato |
| --- | --- |
| Recommendation Lab | Tab Info, Schema, Indexes, Query, Engine, Live. |
| Query | Esecuzione manuale, EXPLAIN, PROFILE, tempi, risultati e piano. Accetta una mappa di parametri JSON; `$uid` è sempre legato all'utente autenticato. |
| Engine | Ricalcolo diagnostico del feed dell'utente autenticato, segnali, candidati, punteggi, metriche e query realmente eseguite durante quel ricalcolo. |
| Tracing backend | `captureQueryTrace()` usa AsyncLocalStorage e registra testo, parametri sanitizzati, durata, record, contatori, stato e transazione di appartenenza, sia per `neo4jService.run()` sia per `tx.run()` dentro le transazioni gestite. |
| Interazioni | Like, dislike, watchlist e visto passano da `setMovieInteraction()` in una transazione gestita; il tracing ora cattura `tx.run` e gli snapshot prima/dopo. |
| Libreria | `getUserLibrary()` restituisce liked, disliked, watchlist, alreadySeen tramite subquery separate. |
| Aggiornamenti live | Socket.IO ha già stanze per utente autenticato e l'evento `movie_state_changed`. |

Il tab Engine è una fotografia ottenuta ricalcolando il motore, non la cronologia delle richieste precedenti effettuate nell'app. Il refresh della console carica anche il report Engine: questo va considerato nella separazione fra osservazione e ricalcolo.

Riferimenti principali:
- `backend/neo4jService.js`: `run`, `captureQueryTrace`, `executeWrite`, `executeRead`.
- `backend/movieRepository.js`: `setMovieInteraction`, `getUserLibrary`, invalidazione cache e recommender.
- `backend/movieController.js`: azioni film, `recommendationDebugStats` e notifiche Socket.IO.
- `backend/neo4jDebugController.js`: query manuali e serializzazione dei risultati.
- `lib/features/debug/presentation/neo4j_console_screen.dart`.
- `lib/features/debug/presentation/recommendation_engine_tab.dart`.

## 2. Vista proposta: Live

Su desktop, tenere l'app a sinistra e il Lab a destra, in due sessioni dello stesso utente. Sul telefono, conservare la cronologia quando si torna alle impostazioni.

```text
UTENTE DEMO                         Cattura attiva ●

AZIONI                  QUERY REALI                 PRIMA → DOPO
12:03 Like Film A        M08 DELETE incompatibili    LIKED: assente → presente
12:04 Watchlist Film A   M01 MERGE film/generi        WATCHLISTED: ...
12:05 Dislike Film A     M09 MERGE DISLIKED          DISLIKED: ...
                        Parametri / tempi          Liste aggiornate
                        Transazione: COMMITTED     Mini-grafo

[Library] [Recommendation path] [Recompute and compare]
```

### A. Cronologia delle azioni

Ogni voce deve contenere azione, film, orario, endpoint, identificatore richiesta, durata totale e risultato. Selezionandola si vedono tutte le query appartenenti a quella richiesta, nell'ordine di avvio; le query parallele devono essere riconoscibili come tali.

La cattura deve avvenire anche mentre la console non è aperta. Una cronologia breve conservata sul backend, recuperabile quando si riapre il Lab, evita di perdere le azioni. In modalità desktop, Socket.IO può notificare subito la disponibilità della trace.

### B. Cypher effettivamente eseguito

Per ogni query: testo originale, parametri, durata, righe restituite e contatori Neo4j (`relationshipsCreated`, `relationshipsDeleted`, `propertiesSet`, ecc.).

Mostrare separatamente:
- stato della query: avviata / completata / errore;
- stato della transazione: in corso / committed / rolled back;
- eventuale tentativo di retry.

Una query completata non implica che la transazione sia stata committata. I contatori di una query successivamente annullata non vanno presentati come modifiche persistenti.

Le query possono essere troppo veloci per leggerle mentre girano: la cronologia selezionabile è essenziale. Un eventuale replay deve essere una riproduzione visiva della trace registrata, senza rieseguire le scritture.

### C. Stato prima/dopo

Confrontare dati effettivamente letti da Neo4j:
- relazioni fra l'utente e il film selezionato;
- timestamp della relazione;
- appartenenza alle quattro liste;
- preferito di onboarding, se presente, come segnale separato;
- quota e metadati `INCLUDED`, quando l'azione appartiene a un batch Daily.

Il confronto deve essere per `tmdbId` e tipo di relazione, non per posizione nelle liste: la query libreria attuale non garantisce un ordine.

Per il film, acquisire lo stato prima e dopo dentro lo stesso tentativo transazionale e pubblicarlo solo dopo il commit. La libreria riletta successivamente rappresenta lo stato corrente: in presenza di altre azioni concorrenti non equivale necessariamente alla fotografia esatta di quella singola transazione. In caso di rollback, rileggere lo stato persistente e mostrare distintamente il tentativo annullato.

### D. Libreria utente leggibile

Quattro liste con titoli, ID e data, contatori, filtro e righe aggiunte/rimosse evidenziate. Mostrare la query di lettura M22 quando si apre o aggiorna la libreria.

Messaggio per il professore: «Le liste derivano dalle relazioni tipizzate che collegano questo utente agli stessi nodi Movie. Le subquery aggregano ogni lista separatamente, evitando di moltiplicare le righe fra liste diverse».

### E. Mini-grafo mirato

Visualizzare l'utente, il film selezionato e pochi nodi vicini. Verde per relazioni create, rosso tratteggiato per quelle rimosse, grigio per quelle presenti in entrambe le fotografie. Usare solo dati realmente letti; evitare un grafo globale troppo affollato.

Seconda vista: un percorso collaborativo realmente esistente con titoli e rating:

```text
AppUser -LIKED-> Movie seed
Movie seed <-MATCHES_TMDB- MovieLensMovie seed
MovieLensMovie seed <-RATED- MovieLensUser
MovieLensUser -RATED-> MovieLensMovie candidato
MovieLensMovie candidato -MATCHES_TMDB-> Movie candidato
```

È un percorso completo di **cinque relazioni**. Un percorso visualizzato spiega una parte dell'evidenza; il punteggio finale aggrega più vicini e può includere anche la componente semantica.

## 3. Transizioni reali da dimostrare

| Azione | Relazione assicurata da MERGE | Relazioni incompatibili eliminate |
| --- | --- | --- |
| Like | LIKED | DISLIKED |
| Dislike | DISLIKED | LIKED, WATCHLISTED |
| Watchlist | WATCHLISTED | DISLIKED, ALREADY_SEEN |
| Visto | ALREADY_SEEN | WATCHLISTED |

**Like e watchlist possono coesistere.** Anche like e visto possono coesistere. `SELECTED_FAVORITE` non viene rimosso da queste transizioni: scegliere per la dimostrazione un film che non sia un preferito di onboarding rende più chiaro il passaggio da segnale positivo a negativo.

Sequenza consigliata sullo stesso film inizialmente senza interazioni:

1. Like: compare LIKED.
2. Watchlist: si aggiunge WATCHLISTED mantenendo LIKED.
3. Dislike: spariscono LIKED e WATCHLISTED, compare DISLIKED.

Questa sequenza rende tangibile l'integrità dello stato meglio di due swipe su film diversi. Prima della presentazione va verificato il percorso concreto dei pulsanti nella UI. Una possibile integrazione è un selettore film nel Lab con gli stessi comandi applicativi, attraverso gli endpoint esistenti.

Per un'azione Daily la sequenza nel repository è:
**M05 verifica batch → M06 quota → M08 rimozione incompatibili → M01 upsert film → M09 interazione → M10 telemetria → commit → invalidazione cache**.

Senza contesto Daily viene verificata M07 al posto di M05/M06. Non ogni like incrementa una quota. Il controller può inoltre aggiornare il runtime del film prima di entrare nella transazione: la trace deve rendere visibili questi confini, senza attribuire alla transazione l'intera richiesta HTTP.

## 4. Scaletta esatta: 5 minuti

| Tempo | Cosa mostrare | Cosa dire |
| --- | --- | --- |
| 0:00–0:30 | Utente demo, film scelto e stato iniziale | «Seguiamo un'azione dall'interfaccia fino ai dati e al loro riutilizzo nel motore di raccomandazione». |
| 0:30–1:15 | Like, query M09, diff prima/dopo e lista | «MERGE trova o crea la relazione; createdAt appartiene all'arco. Il film è un nodo condiviso». |
| 1:15–2:00 | Watchlist, poi dislike sullo stesso film | «Questa azione elimina gli stati incompatibili e crea DISLIKED nella stessa transazione. Ecco le differenze persistite». |
| 2:00–2:35 | Library, query M22 e liste prima/dopo | «Le liste sono letture delle relazioni. Le subquery separano le aggregazioni evitando la moltiplicazione delle righe». |
| 2:35–3:55 | Percorso collaborativo reale e tab Engine | «Dai miei segnali attraversiamo il ponte TMDB–MovieLens, troviamo vicini e candidati. Il film già interagito viene escluso; gli altri segnali contribuiscono al ranking». Mostrare brevemente indice vettoriale e origine hybrid se disponibili. |
| 3:55–4:40 | PROFILE su lettura del profilo o percorso mirato | «EXPLAIN pianifica; PROFILE esegue e misura. Qui leggiamo accesso tramite indice, espansioni, righe e DbHits». Commentare gli operatori realmente presenti. |
| 4:40–5:00 | Riepilogo azione → grafo → risultato | «Neo4j rappresenta le relazioni, mantiene le modifiche transazionali e le attraversa per produrre raccomandazioni spiegabili». |

Movie Night e rollback della quota sono ottimi approfondimenti per le domande. Nel percorso principale il tempo è investito sul ciclo utente–dati–raccomandazioni.

## 5. Preparazione della demo

- Abilitare `ENABLE_NEO4J_DEBUG=true` e `ENABLE_RECOMMENDATION_DEBUG=true` sul backend.
- Preparare un account con onboarding completato e qualche segnale positivo.
- Scegliere un film con bridge MovieLens, rating utili e, per il semantico, tag con embedding. Verificare queste condizioni sui dati effettivi.
- Preparare uno stato iniziale noto e annotare le relazioni del film. Provare l'intera sequenza e predisporre il ripristino dell'account demo fra le prove.
- Verificare TMDB: le attuali azioni like/dislike/watchlist recuperano i dettagli tramite API esterna.
- Usare lo stesso account nelle due finestre: il tab Live si aggiorna ogni 2 secondi e mostra le azioni fatte altrove; il pulsante Pause updates ferma gli aggiornamenti durante la spiegazione.
- Preparare la query PROFILE e i parametri prima della presentazione. Non scrivere a mano la lunga M23 durante i cinque minuti.
- Per il confronto del ranking usare snapshot e ricalcolo esplicito. Un singolo like non garantisce il cambio della top 5; un singolo dislike non garantisce l'attivazione di una penalità di genere soggetta a soglia. L'esclusione del film già interagito e la modifica delle relazioni sono evidenze più stabili.
- Per una dimostrazione della quota occorrono un batch valido e la configurazione `ENABLE_DAILY_SWIPE_LIMIT`/`DAILY_SWIPE_LIMIT`. Il limite non è sempre attivo.

## 6. Interventi realizzati e lavoro residuo

Realizzati nella branch `feat/neo4j-live-demo`:

1. **Tracing transazionale** in `neo4jService.js`: anche `tx.run` è intercettato; tentativi di retry, `committed`, `rolled_back` e `commit_unknown` sono distinti; i contatori restano nella transazione a cui appartengono.
2. **Contesto per richiesta**: `neo4jLiveTrace.js` collega utente, azione, film e trace; storico breve per utente (30 azioni, 30 minuti); il tab Live lo recupera dal backend e riceve anche il push `neo4j_live_action` via Socket.IO, con polling di riserva ogni 2 s.
3. **Snapshot e diff**: prima/dopo nella stessa transazione per like, dislike, watchlist, visto e rimozioni; il diff è testuale (`+`/`−`/`=` con presenza prima e dopo) e grafico. Il contesto Daily compare nello snapshot con quota e azione del batch.
4. **Tab Live** con cronologia, dettaglio query, libreria filtrabile, mini-grafo, percorso della raccomandazione e confronto classifica.
5. **Parametri nella console**: mappa JSON validata; `$uid` viene sempre rilegato all'utente autenticato anche se il client tenta di sovrascriverlo.
6. **Preset personali**: "La mia libreria" e il preset collaborativo ora usano `$uid` con testo Dart correttamente escapato.
7. **Mini-grafo del diff**: frecce verdi (creata), rosse tratteggiate (rimossa), grigie (invariata) fra `(:AppUser)` e `(:Movie)`.
8. **Percorso reale**: `GET /debug/neo4j/recommendation-path` restituisce il cammino utente → seed → MovieLens → vicino → candidato con titoli e rating, limitato per la demo.
9. **Confronto classifica**: cattura del riferimento e ricalcolo esplicito del Motore con nuovi/usciti/spostati.
10. **Open in Query tab**: trasferisce testo e parametri non sanitizzati, contando quelli esclusi.

Non resta lavoro pianificato. Possibili estensioni future: persistenza dello storico su disco, push differenziale con il payload completo e integrazione del percorso nel tab Engine.

La trace è generata dalle chiamate effettive al driver, non ricostruita da stringhe didattiche. Gli endpoint delle azioni restano l'unica logica applicativa: la console li osserva soltanto. I dati diagnostici sono pubblicati solo all'utente pertinente e il tracing è subordinato ai flag di debug.

Verificato con i test: transizioni like → watchlist → dislike → rimozione; commit/rollback/retry/commit_unknown; storico, limiti e separazione utenti; parametri della console e binding di `$uid`; push Socket.IO con riepilogo; percorso a 11 segmenti; polling e pausa; mini-grafo, trasferimento query e confronto classifica nei widget test. La verifica end-to-end con Neo4j reale è nel test d'integrazione `recommendation.integration.test.js` (`NEO4J_INTEGRATION=true`); l'esecuzione effettiva su database resta da fare nell'ambiente della demo.

## 7. Correzioni ai materiali utili all'orale

1. **Cinque relazioni nel percorso completo**: slide e note parlano spesso di quattro hop. Usare “traversal multi-hop” oppure contare esplicitamente le cinque relazioni sopra.
2. **Confronto SQL/Neo4j**: evitare affermazioni universali come “i JOIN sono esponenziali” o “Neo4j è sempre O(degree)”. Il vantaggio è la rappresentazione e l'attraversamento diretto delle relazioni; costo complessivo, cardinalità, indici, cache e piano vanno misurati.
3. **FRIEND**: Neo4j memorizza relazioni orientate. Il pattern senza freccia cerca in entrambe le direzioni e permette di modellare un'amicizia simmetrica con un solo arco.
4. **Preset collaborativo P03**: oggi parte da tutti gli AppUser e aggrega risultati fra utenti; inoltre è una semplificazione della query di produzione. Per la demo personale serve `$uid` e una distinzione esplicita fra preset didattico e M23 reale.
5. **Copia query e PROFILE**: la guida suggerisce copia-incolla. Ora il tab Live trasferisce query e parametri al tab Query con **Open in Query tab**; i valori sanitizzati (uid, liste lunghe) vengono esclusi e `$uid` è rilegato dal backend. Restano esclusi i vettori abbreviati, che non sono rieseguibili così come sono.
6. **RRF**: nel progetto la fusione è calcolata nel backend JavaScript; traversal collaborativo e ricerca vettoriale sono eseguiti da Neo4j.
7. **Onboarding**: i segnali sono SELECTED_FAVORITE e PREFERS_GENRE; la guida funzionale semplifica erroneamente in LIKED/IN_GENRE.
8. **Dataset**: distinguere il dataset configurato/importato dai numeri delle altre edizioni MovieLens citati nella guida. Usare i conteggi live, non promettere milioni di rating.
9. **Query dei materiali**: alcune sono abbreviate o divergono dal sorgente, per esempio M23 nel file delle top query e l'accettazione amicizia etichettata S06. Il codice e la trace della richiesta sono la fonte per la demo.

## 8. Metodo e limiti dell'analisi

Consultati note del relatore, istruzioni, presentazione HTML, guida funzionale PDF, sezioni della guida tecnica e dello schema HTML, catalogo/mappa query e documentazione del repository, confrontandoli con console Flutter, servizio Neo4j, controller e repository delle interazioni e delle raccomandazioni.

Graphify è disponibile: effettuata una nuova scansione AST su 145 file di codice. L'estrazione completa della cartella si è arrestata perché il corpus documentale richiede estrazione semantica; sono inoltre segnalati problemi di parsing/grammatiche per 11 file. Consultato con `graphify query` anche il grafo già presente nel repository, il cui report dichiara 206 file, 1461 nodi e 1746 archi. La ricostruzione diretta del grafo dal frammento AST è stata rifiutata per riferimenti non risolti. Gli output dei tentativi sono nella cartella temporanea del tool.

Non è una certificazione di lettura integrale di ogni asset: gli audio non sono stati trascritti e i PDF duplicati delle versioni HTML non sono stati tutti riletti. Non sono stati avviati backend/app/database: comportamento visuale, tempi, disponibilità dei dati e prestazioni restano da provare sull'ambiente della demo.
