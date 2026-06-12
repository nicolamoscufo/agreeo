# Lavoro rimanente — post production readiness

> Stato al 2026-06-11, dopo l'esecuzione di [REMEDIATION_PLAN.md](REMEDIATION_PLAN.md)
> sul branch `hardening/production-readiness` (Fase 1 e 2 complete, Fase 3 quasi
> completa). Questo file elenca solo ciò che resta da fare.

## 🔴 Azioni manuali bloccanti per il go-live

- [ ] **Rotazione token TMDB** — il token reale presente in `.env` /
  `backend/.env` è da considerare compromesso (macchina/backup condivisi).
  Rigenerarlo su [themoviedb.org](https://www.themoviedb.org/settings/api) e
  aggiornare `.env`, `backend/.env` e `.env.azure`. Il vecchio token deve
  risultare invalido.
- [ ] **Secret di produzione** — verificare che `.env.azure` contenga un
  `JWT_SECRET` casuale ≥ 32 caratteri (`openssl rand -base64 48`) e una
  `NEO4J_PASSWORD` forte. I `.env.example` non contengono più default deboli;
  il compose fallisce senza valori espliciti.
- [ ] **Smoke test deploy** con `docker-compose.azure.yml`: avvio stack,
  `GET /health` e `GET /health/db`, registrazione/login, swipe giornaliero,
  creazione movie night con voto, eventi realtime con token valido
  (connessione senza token deve essere rifiutata).
- [ ] **Branch protection su GitHub** — richiedere il check CI verde
  (`.github/workflows/ci.yml`) per il merge su `main`. È un'impostazione del
  repository, non è versionabile.

## 🟡 Item del piano rimasti aperti (non bloccanti)

- [ ] **3.4 Logging strutturato** — introdurre `pino` (o winston) con livelli
  e log JSON. Fatto finora: rimossi input utente e URL completi dai log,
  eliminati i blocchi decorativi del mood-search.
- [ ] **3.6 Coerenza documentazione** — verifica completa di
  [docs/BACKEND_CONTRACT.md](BACKEND_CONTRACT.md) e
  [docs/ROUTING_MAP.md](ROUTING_MAP.md) contro il codice attuale
  (il README è già stato riallineato).
- [ ] **3.8 Contrasto WCAG AA** — controllo dei token tema in
  [lib/shared/theme/agreeo_tokens.dart](../lib/shared/theme/agreeo_tokens.dart)
  (testo `faint` su sfondi chiari/scuri, stati disabled). Fatto finora:
  `Semantics` sui poster, tooltip sulle icone interattive, label sui form.

## 🔵 Verifiche e follow-up consigliati

- [ ] **Build web + secure storage** — il frontend Docker è una build Flutter
  web; `flutter_secure_storage` su web usa WebCrypto (sperimentale).
  L'`AuthService` ha un fallback automatico su SharedPreferences, ma va
  verificato il flusso login/refresh nella build web reale.
- [ ] **Password Neo4j locale** — il DB locale usa ancora `password123` nel
  volume esistente. Per cambiarla: `ALTER USER neo4j SET PASSWORD ...` (o
  reset del volume) e aggiornare `.env` / `backend/.env`.
- [ ] **Developer Mode su Windows** — con il plugin `flutter_secure_storage`
  le build con plugin richiedono il supporto symlink: abilitare la modalità
  sviluppatore (`start ms-settings:developers`) sulle macchine Windows locali.
- [ ] **Test e2e Socket.IO** — i test unitari coprono il middleware di auth;
  un e2e con `socket.io-client` (connessione rifiutata senza token, eventi
  isolati per utente) darebbe copertura completa al percorso realtime.
- [ ] **HTTPS in produzione** — garantire `BACKEND_BASE_URL` https dietro
  reverse proxy/TLS; il manifest Android release ora rifiuta il cleartext.
- [ ] **Migrazione UI Daylight** — il lavoro in corso è stato committato
  (commit `fd8ad17`); completare le fasi restanti della migrazione.

## ✅ Già completato (riferimento)

Fase 1 (auth Socket.IO via JWT, `JWT_SECRET` obbligatorio, rate limiting),
Fase 2 (helmet, errori generici, graceful shutdown, `npm audit` a 0
vulnerabilità, `neo4j-driver` 5.x, query ottimizzate con PROFILE, fix N+1
TMDB, cleartext solo debug, password policy + secure storage, password Neo4j
obbligatoria) e Fase 3 (debug off, limite swipe, health probe, log privacy,
LIMIT parametrizzate, README, cleanup, a11y base, CI, rimozione TmdbService).
Dettaglio checkbox in [REMEDIATION_PLAN.md](REMEDIATION_PLAN.md).
