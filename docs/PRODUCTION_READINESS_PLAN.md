# Piano di Production Readiness

> Questo file era una copia troncata del piano. Il piano completo e aggiornato,
> con lo stato delle checkbox per ogni task, è in
> [`REMEDIATION_PLAN.md`](../REMEDIATION_PLAN.md) nella root del repository.

## Stato (giugno 2026)

- **Fase 1 (Critical)** — completata: auth Socket.IO via JWT nell'handshake,
  `JWT_SECRET` forte obbligatorio, rate limiting su `/auth/*` e globale.
- **Fase 2 (Warning)** — completata: helmet, errori generici in produzione,
  graceful shutdown, `npm audit` a 0 vulnerabilità (override `protobufjs`),
  `neo4j-driver` 5.x con pool configurato, query Neo4j ottimizzate (PROFILE
  documentato nel codice), N+1 TMDB risolto, cleartext Android solo in
  debug/profile, password policy + `flutter_secure_storage`, password Neo4j
  obbligatoria nel compose.
- **Fase 3 (Info)** — completata salvo: adozione di `pino` per il logging
  strutturato, verifica di coerenza completa della documentazione, controllo
  contrasto WCAG dei token tema, branch protection su GitHub (impostazione
  del repository, non versionabile).

## Azioni manuali rimanenti

1. **Rotazione token TMDB**: rigenerare il token su themoviedb.org e
   aggiornare `.env` / `.env.azure` (il token locale è da considerare
   compromesso se la macchina/backup è condivisa).
2. **Smoke test deploy**: `docker-compose.azure.yml` → avvio, `/health`,
   login, swipe, movie night, realtime con token valido.
3. **Branch protection**: richiedere il check CI verde per il merge su `main`.
