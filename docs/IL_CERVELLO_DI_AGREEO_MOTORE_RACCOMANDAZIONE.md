# 🧠 Il Cervello di Agreeo — Guida Completa al Motore di Raccomandazione

> **Scopo di questa guida**: spiegare nel dettaglio, ma con parole chiare e concetti intuitivi, come funziona l'intero motore di raccomandazione di Agreeo. Questo documento illustra come il sistema elabora i gusti dell'utente, come cammina sul grafo, come sfrutta l'intelligenza artificiale vettoriale e come fonde tutto insieme per decidere quali film mostrarti ogni giorno.

---

## 1. La Filosofia: Perché i Sistemi Tradizionali Falliscono?

La maggior parte delle piattaforme di streaming consiglia i film basandosi su due approcci molto limitati:
1. **I filtri statici per Genere**: *"Ti è piaciuto un film d'azione? Eccoti altri 50 film d'azione a caso"*. Il problema è che *Die Hard*, *Mad Max* e *The Avengers* sono tutti "Azione", ma hanno toni, complessità e target completamente diversi.
2. **Le bolle di filtraggio (Filter Bubbles)**: Se guardi 3 film di fantascienza, il sistema ti propone solo ed esclusivamente fantascienza per sempre, stancandoti.

### La Visione di Agreeo: Il Motore Ibrido
Agreeo supera questi limiti creando un **cervello a due emisferi**:
* **L'Emisfero Sinistro (Il Grafo Sociale e Comportamentale)**: Analizza il comportamento reale delle persone. *"Chi ha amato i tuoi stessi film, cos'altro ha guardato e votato con entusiasmo?"*
* **L'Emisfero Destro (La Comprensione Semantica Vettoriale)**: Comprende il significato profondo, le atmosfere e le tematiche intime di un'opera attraverso l'Intelligenza Artificiale (*"distopia cupa"*, *"viaggi nel tempo"*, *"vendetta shakespeariana"*).

I due emisferi lavorano in parallelo e i loro risultati vengono fusi insieme da un algoritmo di arbitraggio imparziale (**Reciprocal Rank Fusion**).

---

## 2. Come l'App Ascolta i Tuoi Gusti (I Segnali di Ingresso)

Prima di calcolare qualsiasi suggerimento, il motore deve comprendere chi sei. In Agreeo ogni tua azione sull'app viene tradotta in un segnale matematico ponderato nel grafo:

```
┌─────────────────────────┬──────────────┬────────────────────────────────────────────────────────┐
│ Azione dell'Utente      │ Relazione    │ Peso / Ruolo nel Motore                                │
├─────────────────────────┼──────────────┼────────────────────────────────────────────────────────┤
│ Film preferito iniziale │ SELECTED_FAV │ 4.0 (Ancora primaria fortissima del tuo gusto)         │
│ Swipe a destra          │ LIKED        │ 3.0 (Segnale positivo forte di approvazione)           │
│ Salvataggio             │ WATCHLISTED  │ 1.25 / 1.5 (Intenzione di visione, interesse moderato) │
│ Swipe a sinistra        │ DISLIKED     │ Segnale negativo: costruisce il "profilo di rigetto"   │
│ Segna come visto + Voto │ RATED        │ Voto da 1 a 5 stelle (perfeziona la calibrazione)      │
└─────────────────────────┴──────────────┴────────────────────────────────────────────────────────┘
```

### Il "Decadimento Temporale": I tuoi gusti cambiano!
I gusti cinematografici di una persona non sono scolpiti nella pietra: ciò che ti piaceva un anno fa potrebbe non rispecchiare quello che desideri vedere oggi.
Per questo, Agreeo applica un **decadimento esponenziale nel tempo**:
$$\text{Fattore Temporale} = \exp(-0.005 \times \text{giorni trascorsi})$$

* Un *Like* messo **ieri** pesa quasi al 100%.
* Un *Like* messo **6 mesi fa** vede il suo peso progressivamente ridotto.
In questo modo, il sistema rimane sempre fresco e si adatta naturalmente all'evoluzione delle tue preferenze senza richiedere reset manuali.

---

## 3. Il Primo Pilastro: Il Filtraggio Collaborativo sul Grafo (Query `M23`)

Il primo emisfero del motore si chiama **Filtraggio Collaborativo** e risponde alla domanda:
> *"Trovami persone che hanno gusti straordinariamente affini ai miei e scopriamo quali capolavori hanno amato che io non ho ancora visto."*

Questo calcolo non avviene confrontando tabelle numeriche gigantesche, ma compiendo un **cammino a 4 salti (4-Hop Traversal)** lungo la ragnatela del grafo Neo4j:

```
(Tu: AppUser)
   │
   │ 1° Salto: [:LIKED o :SELECTED_FAVORITE] (con peso e decadimento temporale)
   ▼
(Film Seed: Movie)
   │
   │ 2° Salto: [:MATCHES_TMDB] (Ponte verso il dataset storico)
   ▼
(Seed MovieLens: MovieLensMovie)
   │
   │ 3° Salto: [r1:RATED {rating >= 4.0}] (Cerca utenti che lo hanno amato)
   ▼
(Utente Simile: MovieLensUser)
   │
   │ 4° Salto: [r2:RATED] (Cosa consiglia questo utente simile?)
   ▼
(Film Candidato: Movie) [Escludendo i film che tu hai già visto o scartato!]
```

Per rendere questo percorso accurato e privo di errori banali, gli ingegneri di Agreeo hanno inserito **4 correttivi matematici raffinatissimi**:

---

### A. La Centratura dei Voti: Solo l'eccellenza conta
In una scala da 1 a 5 stelle, dare 3 stelle significa spesso "film mediocre, guardabile ma dimenticabile".
Nel calcolo, Agreeo **centra i voti sottraendo 3.0**:
$$\text{Impatto Voto} = (\text{Voto} - 3.0)$$
* Un voto di **5 stelle** vale $+2.0$ (entusiasmo puro).
* Un voto di **4 stelle** vale $+1.0$ (apprezzamento convinto).
* Un voto di **3 stelle o inferiore** diventa nullo o negativo e non contribuirà a consigliarti quel film!

---

### B. Smorzamento della Popolarità (Popularity Damping)
Immagina che sia a te sia a un altro utente sia piaciuto *Pulp Fiction*. Questo dimostra che avete gusti identici? **No!** *Pulp Fiction* piace praticamente a tutti.
Se invece scopriamo che sia a te sia all'altro utente è piaciuto un film d'autore poco conosciuto degli anni '70 con soli 20 voti in tutto il database, la probabilità che siate due veri "gemelli di gusto" è altissima!

Agreeo applica una formula di **damping logaritmico**:
$$\text{Peso Rarità} = \frac{1}{\sqrt{\log(\text{Numero Voti del Film} + 10)}}$$
I film ultra-popolari contribuiscono poco a definire la somiglianza tra utenti; i film di nicchia pesano invece tantissimo.

---

### C. La Contrazione del Supporto (Support Shrinkage)
Se un film candidato viene consigliato da un solo utente simile che gli ha dato 5 stelle, possiamo fidarci al punto da metterlo al primo posto? Ovviamente no, potrebbe essere una preferenza eccentrica.
Se invece viene consigliato da **15 utenti simili diversi**, la certezza statistica diventa granitica.

Agreeo usa lo **shrinkage bayesiano**:
$$\text{Support Weight} = \frac{\text{Numero Utenti Simili}}{\text{Numero Utenti Simili} + 5.0}$$
* Con 1 solo utente simile: il peso della raccomandazione è solo $\frac{1}{6} \approx 16\%$ (il resto viene trascinato verso la media generale del database).
* Con 15 utenti simili: il peso sale a $\frac{15}{20} = 75\%$, rendendo la raccomandazione solidissima.

---

### D. Lo Scudo Anti-Disgusto (Negative Genre Penalty)
Se durante i tuoi swipe hai scartato con *Dislike* 4 film horror di fila, il motore non si limita a non mostrarti più quei 4 titoli specifici.
La sotto-query rileva che hai un tasso di rigetto elevato verso l'intero genere "Horror" e calcola una **penalità proporzionale** che abbatte il punteggio finale di qualsiasi candidato appartenente a quel genere.

---

## 4. Il Secondo Pilastro: Il Motore Semantico Vettoriale (Query `M24` - `M25`)

Il secondo emisfero risponde a una domanda completamente diversa:
> *"Indipendentemente da cosa hanno fatto gli altri utenti, quali film trattano esattamente le stesse tematiche intime e filosofiche che mi appassionano?"*

Qui entra in gioco l'Intelligenza Artificiale basata su **Dense Vector Embeddings**.

```
 Film con Tag testuali
 ("time travel", "dystopia", "artificial intelligence")
               │
               ▼ Modello di Deep Learning (multilingual-e5-small)
 Vettore matematico nello spazio a 384 dimensioni
 [0.042, -0.118, 0.841, ..., -0.053]
               │
               ▼ Salvato direttamente nei nodi Neo4j (:Tag {embedding: [...]})
 Indice Vettoriale Cosine: tag_embeddings
```

---

### A. Non tutte le parole hanno lo stesso valore: L'indice IDF
Se un film ha il tag *"cinema"*, quel tag non ci dice quasi nulla perché si applica a troppi contesti.
Se un film ha il tag *"cyberpunk"*, *"paradosso temporale"* o *"rapina in banca"*, questi concetti sono densi di significato.

Agreeo pesa ogni tag con l'**IDF (Inverse Document Frequency)**:
* Più un tag è raro e specifico nel catalogo, più alto è il suo valore informativo.
* Più un tag è generico ed ubiquo, più il suo peso viene azzerato.

---

### B. I Due Magneti: Il Vettore del Piacere e il Vettore del Rifiuto
Analizzando la cronologia delle tue interazioni positive e negative, Agreeo calcola in tempo reale **due vettori nello spazio a 384 dimensioni**:
1. **Il Vettore del Gusto Positivo**: Il baricentro (centroide) dei temi che ami.
2. **Il Vettore del Gusto Negativo**: Il baricentro dei temi che respingi.

Quando Neo4j interroga il vector index (`CALL db.index.vector.queryNodes`):
* Cerca i tag vicini al tuo **vettore positivo** usando la **Similarità Coseno**.
* Se un tag è pericolosamente vicino anche al tuo **vettore negativo** (ad esempio ti piace la fantascienza psicologica, ma detesti lo *splatter*), il sistema calcola la similarità negativa e la **sottrae**.

---

### C. La Funzione Cubica: Premiare solo i match eccezionali
Nello spazio vettoriale, le distanze possono risultare ingannevoli se appiattite linearmente. Agreeo eleva la similarità coseno al cubo:
$$\text{Forza del Match} = (\text{Similarità Coseno})^3$$
* Una similarità mediocre di $0.5$ diventa $0.5^3 = 0.125$ (praticamente ignorata).
* Una similarità eccellente di $0.9$ diventa $0.9^3 = 0.729$ (premiata con entusiasmo).

Inoltre, il punteggio finale viene normalizzato dividendo per la radice quadrata del numero totale di tag del film ($\sqrt{\text{Tag Totali}}$), così da impedire che film con centinaia di etichette generiche superino film con 4 tag perfetti.

---

## 5. La Fusione: Reciprocal Rank Fusion (RRF)

Ora il sistema si trova davanti a due classifiche eccellenti ma profondamente diverse:
* La classifica del **Filtraggio Collaborativo** (con punteggi basati su rating di persone, es. da 0 a 150).
* La classifica del **Motore Semantico** (con punteggi basati su distanze vettoriali, es. da 0 a 1).

> [!WARNING]
> **Il Grande Errore da evitare**: Non si possono sommare numeri che hanno scale, medie e distribuzioni matematiche completamente differenti (sarebbe come sommare metri e gradi centigradi).

Agreeo adotta la soluzione usata dai più moderni motori di Information Retrieval mondiali: **Reciprocal Rank Fusion (RRF)**.

### Come funziona RRF?
A RRF non importano i valori numerici grezzi: guarda solo la **posizione in classifica (il Rank)**!

$$\text{Punteggio RRF}(film) = \sum_{s \in \{\text{Collaborativo}, \text{Semantico}\}} \frac{\text{Peso Sorgente}}{60 + \text{Posizione}(film)}$$

* Se un film è arrivato **1°** nella classifica del grafo e **2°** nella classifica semantica, riceve un punteggio RRF stellare perché mette d'accordo entrambi gli emisferi!
* La costante $60$ al denominatore serve ad evitare che il primissimo classificato ottenga un vantaggio sproporzionato rispetto al secondo o al terzo.

---

## 6. Il Terzo Tassello: Lotta alla Noia e Serendipità

Un ottimo motore di raccomandazione non deve essere solo preciso: deve essere anche **vivo e vario**.

### A. La Fatica da Esposizione (Query `M26` - Unacted Exposures)
Ti è mai capitato su altre piattaforme di vedere sempre la stessa locandina proposta all'infinito per settimane anche se non la clicchi mai?
Agreeo tiene traccia di ogni volta che una carta film ti è apparsa a schermo senza che tu abbia fatto swipe (*impression senza interazione*).
Se un film ti è già stato mostrato 3 volte negli ultimi 30 giorni e non l'hai calcolato, il suo punteggio viene progressivamente penalizzato:
$$\text{Score Reale} = \frac{\text{Score RRF}}{1 + (0.15 \times \text{Numero di Impression Ignorate})}$$
Il film scivola dolcemente indietro per fare spazio a novità, senza però essere eliminato per sempre.

### B. La Serendipità: Candidati Esplorativi (Query `M27`)
Nel deck giornaliero, Agreeo non inserisce solo certezze matematiche. Riserva una piccola percentuale a film acclamati dalla critica o appartenenti a generi che hai dichiarato di gradire ma di cui non hai ancora esplorato i titoli. Questo introduce la **Serendipità**: la sorpresa piacevole di scoprire qualcosa che non sapevi di amare.

---

## 7. La Caching Intelligente: Prestazioni da Formula 1

Le query complesse come `M23` e `M25` eseguono calcoli profondi sul grafo. Se un utente apre la Home, poi va alla schermata di Swipe, poi torna indietro, l'app rifà tutti i calcoli da zero?
**Assolutamente no!**

Il backend implementa un'architettura a tre livelli di stato:
* **`computed`**: I candidati vengono calcolati per la prima volta.
* **`hit`**: Nelle chiamate successive della stessa sessione, i risultati vengono serviti istantaneamente dalla memoria RAM in meno di 2 millisecondi.
* **`shared-in-flight`**: Se due richieste simultanee (es. il widget della Home e il mazzo dello Swipe) chiedono le raccomandazioni nello stesso istante, il backend le raggruppa in un'unica esecuzione condivisa verso Neo4j, proteggendo il database da sovraccarichi di memoria.

---

## 8. Tabella di Sintesi per l'Esame

Se i professori vi chiedono di riassumere i pilastri del motore di raccomandazione, ecco la mappa concettuale perfetta:

| Componente | Tecnica Utilizzata | Scopo Architetturale |
| :--- | :--- | :--- |
| **Pesi Interazioni** | Matrice pesata (4.0, 3.0, 1.25) | Distinguere tra passione vera, interesse e semplice curiosità. |
| **Decadimento Temporale** | Funzione esponenziale $\exp(-\lambda \cdot t)$ | Catturare i gusti attuali dell'utente senza farlo restare ancorato al passato. |
| **Traversata a 4 Salti** | Cypher `MATCH` con Index-Free Adjacency | Trovare film raccomandati tramite utenti simili senza fare JOIN relazionali. |
| **Centratura Voti** | Offset $(r - 3.0)$ | Escludere i film mediocri e valorizzare solo i voti da 4 e 5 stelle. |
| **Popularity Damping** | Ponderazione inversa con $\log(\text{voti})$ | Evitare che i blockbuster ovvi appiattiscano la personalizzazione. |
| **Support Shrinkage** | Fattore $\frac{N}{N + 5}$ | Evitare che il parere isolato di un solo utente falsifichi il ranking. |
| **Vector Embeddings** | Vettori 384-D (`multilingual-e5-small`) | Catturare temi intimi e profondi dei film al di là del semplice genere. |
| **IDF sui Tag** | Inverse Document Frequency | Dare valore ai dettagli narrativi specifici ed azzerare le parole comuni. |
| **Similarità Cubica** | $\text{Cosine}^3$ | Premiare le affinità tematiche fortissime e filtrare quelle incerte. |
| **Reciprocal Rank Fusion** | $\sum \frac{w}{60 + \text{rank}}$ | Fondere collaborativo e semantico senza distorsioni di scala numerica. |
| **Anti-Fatica** | Divisione per $(1 + 0.15 \cdot \text{esposizioni})$ | Rimuovere i film ignorati e mantenere il catalogo stimolante ogni giorno. |
