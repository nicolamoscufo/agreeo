# 🎬 Come Funziona Agreeo — Guida Semplice al Progetto

> **Obiettivo di questo documento**: spiegare a grandi linee cosa fa l'applicazione, come funziona l'esperienza utente dall'inizio alla fine e cosa succede "dietro le quinte", senza perdersi in codice o tecnicismi matematici complessi.

---

## 1. Il Problema Reale: "Cosa guardiamo stasera?"

Tutti abbiamo vissuto questa scena:
È venerdì sera, ci si trova sul divano con il partner o con un gruppo di amici per vedere un film. Si apre Netflix o Prime Video e comincia la discussione:
* *"Io voglio una commedia!"*
* *"No, basta commedie, mettiamo un thriller!"*
* *"Quello l'ho già visto..."*
* *"Questo sembra noioso..."*

Il risultato? Si passano **45 minuti a scrollare cataloghi infiniti** senza scegliere nulla, finché la voglia passa e si finisce per guardare sempre la solita puntata di una serie già vista.

### La Soluzione di Agreeo
**Agreeo** è un'applicazione mobile (sviluppata in Flutter con un cervello su database a grafi Neo4j) creata con uno scopo preciso: **far raggiungere un accordo rapido e divertente su cosa guardare, da soli o soprattutto in gruppo.**

---

## 2. Cosa Succede nell'Applicazione: Il Viaggio dell'Utente

L'esperienza in Agreeo è divisa in passaggi chiari e intuitivi:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  1. ONBOARDING  │ ──> │ 2. SWIPE GIORNO │ ──> │ 3. LA LIBRERIA  │ ──> │ 4. MOVIE NIGHT  │
│  Primi gusti    │     │ Deck quotidiano │     │ Cineteca salvata│     │ Votazione live  │
└─────────────────┘     └─────────────────┘     └─────────────────┘     └─────────────────┘
```

---

### Fase 1: Benvenuto e Scelta dei Gusti (Onboarding)
Quando un nuovo utente apre l'app per la prima volta:
1. Crea un account inserendo email, nome utente e password.
2. L'app non lo lancia subito in un catalogo vuoto, ma gli fa subito 2 domande chiave:
   * **Quali sono i tuoi generi preferiti?** (es. *Fantascienza*, *Thriller*, *Animazione*).
   * **Quali sono 3 dei tuoi film del cuore?** (es. *Interstellar*, *Pulp Fiction*, *Il Gladiatore*).
3. **Cosa succede dietro le quinte?** L'applicazione crea subito nel database i primi legami (`LIKED`, `IN_GENRE`). In questo modo il sistema non parte "al buio" (evitando il classico problema del *cold start*), ma sa già che tipo di spettatore ha davanti.

---

### Fase 2: Il Deck Quotidiano di Swipe (Stile Tinder per i Film)
Ogni giorno l'utente trova nella schermata di **Swipe** un mazzo (deck) personalizzato di circa 10-20 carte film:
* Su ogni carta compare la locandina ad alta risoluzione, il titolo, l'anno, i generi e una breve sinossi.
* Con gesti rapidi del dito:
  * 👉 **Swipe a destra**: *Like* ("Mi ispira, mi piacerebbe vederlo!").
  * 👈 **Swipe a sinistra**: *Dislike* ("Non mi interessa / Non mi piace").
  * 🔖 **Tasto Salva**: *Watchlist* ("Lo metto da parte nella mia lista personale").
  * ✔️ **Segna come visto**: Se l'ha già visto in passato, può assegnargli un voto da 1 a 5 stelle e scrivere una breve recensione.

> [!NOTE]
> **Il limite giornaliero (Quota)**: Non c'è uno scroll infinito che ipnotizza l'utente. C'è una quota giornaliera di swipe. Questo serve sia a rendere preziosa ogni scelta dell'utente, sia a dare al motore il tempo di rielaborare i consigli per il giorno successivo.

---

### Fase 3: La Libreria Personale (La tua Cineteca)
Nella scheda **Libreria**, l'utente ha sempre a portata di mano:
* Tutti i film a cui ha messo *Like*.
* I film salvati nella *Watchlist*.
* I film segnati come *Già visti*, con i propri voti e le recensioni scritte.
* Può filtrare per genere, per anno o cercare un titolo specifico.

---

### Fase 4: La Parte Social (Gli Amici)
Agreeo è pensato per essere sociale:
* Puoi cercare un amico tramite username o email e mandargli una richiesta di amicizia.
* Quando l'amico accetta, diventate collegati nell'app.
* Puoi visitare il profilo del tuo amico, vedere quali film gli sono piaciuti di recente e scoprire cosa avete in comune.

---

### Fase 5: Il Cuore dell'App — La "Movie Night" (La Serata Film di Gruppo)

Questo è il vero elemento differenziante di Agreeo. Immagina di essere a casa con 3 amici:

```
[Organizzatore] Crea "Movie Night di Venerdì"
       │
       ├─ Invita Marco, Giulia e Sara (via app o con un link)
       ▼
[Sala d'Attesa Virtuale] Tutti entrano nella stanza
       │
       ▼ L'app calcola i 3-5 film ideali per il gruppo
[Round di Votazione] Ognuno vota segretamente sul suo telefono
       │
       ├─ C'è un vincitore chiaro? ──> 🎉 Proclamazione con trailer e dettagli!
       └─ C'è un pareggio? ──────────> ⚔️ Mini-spareggio tra i film a pari merito
```

1. **Creazione della sessione**: L'organizzatore tocca *Nuova Movie Night*, sceglie un titolo e invita gli amici presenti.
2. **La Sala d'Attesa**: Ognuno riceve una notifica sul telefono o tocca il link di invito ed entra nella stanza virtuale.
3. **La Generazione dei Candidati (La magia)**: L'app non propone film a caso, né chiede a ogni persona di proporne uno. **Il sistema analizza i gusti di tutti i partecipanti presenti nella stanza**, incrocia i loro *Like* e le loro *Watchlist*, esclude i film che qualcuno ha già visto o a cui ha messo *Dislike*, e seleziona una rosa perfetta di 3-5 candidati.
4. **La Votazione in Tempo Reale**: A tutti i partecipanti compaiono contemporaneamente i film candidati sullo schermo del proprio telefono. Ognuno vota in segreto il film che preferisce.
5. **Lo Spareggio (Tie-Break)**: Se due film ottengono lo stesso numero di voti, l'app avvia automaticamente un mini-round di spareggio immediato solo tra i due film contesi.
6. **La Proclamazione**: Risolti i voti, compare un'animazione di vittoria con coriandoli: viene proclamato il film vincitore, con link diretto al trailer, trama e dove vederlo in streaming. **Decisione presa in meno di 2 minuti!**

---

## 3. Come Ragiona il Cervello di Agreeo (Senza Formule Complesse)

Perché l'applicazione propone proprio determinati film a un utente? Ci sono due meccanismi che lavorano insieme:

### A. Il Principio del "Cinefilo Simile" (Filtraggio Collaborativo)
Funziona con il buonsenso umano:
* Immagina che a te piacciano *Inception*, *Shutter Island* e *The Prestige*.
* Nel sistema ci sono altre persone a cui sono piaciuti esattamente quegli stessi tre film.
* Se a quelle persone è piaciuto tantissimo anche *Memento*, l'app dice: *"Ehi, voi avete gusti quasi identici: è molto probabile che Memento piaccia anche a te!"*.
L'algoritmo fa proprio questo: cerca persone con gusti simili ai tuoi e guarda quali altri film hanno amato.

### B. Il Principio del "Tema e Significato" (Ricerca Semantica con Vettori)
Non basta guardare le categorie generiche (come "Azione" o "Dramma"):
* Ogni film è descritto da parole chiave e temi profondi (es. *"viaggi nel tempo"*, *"intelligenza artificiale ribelle"*, *"distopia cyberpunk"*).
* Un modello di intelligenza artificiale traduce questi temi in concetti matematici.
* Se l'app nota che ti piacciono film con atmosfere cupe e trame investigative alla *Blade Runner*, ti proporrà film con atmosfere affini anche se appartengono a categorie diverse.

### C. La Fusione dei Due Sistemi
L'app prende i migliori film trovati con il metodo "Persone simili" e i migliori film trovati con il metodo "Temi simili", li fonde insieme in una classifica unica e bilanciata e ti presenta i più promettenti nel tuo deck quotidiano.

---

## 4. Perché Usiamo un Database a Grafi (Neo4j)?

Se hai mai visto una tabella di Excel o un database tradizionale SQL, sai che i dati sono organizzati in righe e colonne divise in tante tabelle staccate (Tabella Utenti, Tabella Film, Tabella Recensioni, Tabella Amicizie).

Quando chiedi a un database tradizionale:
> *"Trovami i film piaciuti agli amici degli utenti che hanno gusti simili a me, ma che io non ho ancora visto"*

Il database tradizionale deve fare decine di costose operazioni di confronto (chiamate `JOIN`), che consumano tantissima memoria e rallentano il sistema quando gli utenti aumentano.

### Con il Grafo (Neo4j) è tutto diverso:
I dati non stanno in tabelle rigide, ma sono **pallini (Nodi)** collegati da **frecce (Relazioni)**, esattamente come una mappa o una ragnatela:

```
(Tu: Utente) ──[:AMICO]──> (Marco: Utente)
      │
   [:PIACIUTO]
      ▼
 (Interstellar) <──[:PIACIUTO]── (Giulia: Utente) ──[:PIACIUTO]──> (Arrival)
```

Per scoprire che Giulia ha gli stessi gusti di "Tu" e che consiglia *Arrival*, il database a grafi non deve fare calcoli enormi: **segue semplicemente le frecce con le dita**, in una frazione di millisecondo! Questo rende i calcoli delle raccomandazioni e delle serate di gruppo fulminei.

---

## 5. L'Architettura dei "Due Cataloghi": TMDB e MovieLens

Una delle scelte più intelligenti del progetto è stata quella di dividere il catalogo in due mondi:

1. **La Vetrina Splendida (TMDB - The Movie Database)**:
   * È l'enciclopedia da cui prendiamo le locandine colorate, i trailer di YouTube, i nomi degli attori e le trame in italiano.
   * È ciò che rende l'app bella e moderna da usare per gli utenti.
2. **Il Cervellone Storico (MovieLens)**:
   * È un celebre archivio universitario con milioni di voti reali lasciati nel tempo da decine di migliaia di cinefili.
   * Ci fornisce la "saggezza della folla" per calcolare con precisione le affinità tra film.
3. **Il Ponte Invisibile**:
   * Nel database ogni film di MovieLens è collegato al rispettivo film di TMDB.
   * L'utente vede solo la bellissima interfaccia con le locandine di TMDB, mentre sotto il cofano l'algoritmo sfrutta i milioni di voti di MovieLens per indovinare i suoi gusti.

---

## 6. Riepilogo in Parole Povere

| Cosa fa l'utente | Cosa fa Agreeo dietro le quinte |
| :--- | :--- |
| **Si registra e sceglie 3 film** | Crea il profilo nel grafo e accende i primi collegamenti di affinità. |
| **Fa swipe a destra o a sinistra** | Rafforza la mappa dei suoi gusti ed esclude i film indesiderati. |
| **Aggiunge un amico** | Crea un legame di amicizia diretto nel grafo. |
| **Crea una Movie Night** | Trova la sovrapposizione perfetta tra i gusti di tutti i partecipanti. |
| **Il gruppo vota in tempo reale** | Sincronizza i voti all'istante, gestisce eventuali spareggi e proclama il vincitore. |
