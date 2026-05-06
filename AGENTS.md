Would an agent likely miss this without help? Yes. Initialize project docs before coding.
- Would an agent likely miss this without help? Yes. Read README and root config first to understand repo layout.
- Would an agent likely miss this without help? Yes. Install and verify dependencies after pubspec changes (flutter pub get).
- Would an agent likely miss this without help? Yes. Before running tests, lint, or builds, ensure environment is clean and all tools are installed.
- Would an agent likely miss this without help? Yes. Follow executable sources of truth (CI, pre-commit, opencode.json) over prose when conflicts arise.
- Would an agent likely miss this without help? Yes. Identify entrypoints and package boundaries early (main.dart, app_controller.dart, backend_service.dart).
- Would an agent likely miss this without help? Yes. When modifying architecture, run focused verification steps (lint, typecheck, unit tests) in the correct order: lint -> typecheck -> test.
- Would an agent likely miss this without help? Yes. Keep changes small and testable; prefer patch-level edits over large rewrites.
- Would an agent likely miss this without help? Yes. Maintain a small, explicit changelog or commit messages that explain the why behind changes.
- Would an agent likely miss this without help? Yes. Document any non-default toolchain quirks (e.g., lack of Flutter driver, use of platform-specific configuration).
- Would an agent likely miss this without help? Yes. If you introduce a new database (Neo4j), provide a minimal migration path and a quick rollback plan.
- Would an agent likely miss this without help? Yes. If tests rely on external services, include a lightweight fallback or explain how to run in isolated mode.

Guidance reminders:
- Use high-signal, repo-specific guidance only. Exclude generic advice.
- Keep sections short; update in place if AGENTS.md exists. If not, create minimal but precise guidance.
- When in doubt, refer to executable sources (scripts, configs) rather than prose.

Would an agent likely miss this without help? Yes. Migration to Neo4j: this repo now uses a Neo4j-based persistence layer accessed via HTTP API; there is no official Flutter driver, so data access goes through Neo4jService.

Would an agent likely miss this without help? Yes. New important files to touch for Neo4j: 
- lib/config/neo4j_config.dart
- lib/services/neo4j_service.dart
- lib/models/neo4j/neo4j_models.dart
- lib/services/backend_service.dart (Neo4j path)
- lib/providers/app_controller.dart (initialization)

Would an agent likely miss this without help? Yes. Local dev environment for Neo4j:
- Install and run Neo4j locally (Docker):
  docker run -p 7474:7474 -p 7687:7687 -e NEO4J_AUTH=neo/password neo4j:latest
- Access management UI at http://localhost:7474
- Update neo4j_config.dart with the correct URI, username, and password

Would an agent likely miss this without help? Yes. Data migration plan (Firestore -> Neo4j):
- Define node labels: User, Movie, Group, Event, etc.
- Define relationship types: LIKED, SEEN, MEMBER_OF, VOTED_FOR, CREATED, etc.
- Export Firestore data to JSON, map to Cypher MERGE/CREATE statements, and seed Neo4j via Neo4jService.
- Implement a one-time migration script (could be in Dart or a small Node/Python tool) and run before switching production traffic.

Would an agent likely miss this without help? Yes. Validation strategy:
- Write unit tests for Neo4jService (simulated Cypher calls).
- Perform manual end-to-end checks against a local Neo4j instance; verify CRUD operations and common queries.
- Add integration test scaffolding to CI to run a lightweight subset of queries.

Would an agent likely miss this without help? Yes. Rollback plan:
- Keep Firestore-backed paths behind a feature flag if migrating incrementally; otherwise ensure data migration is complete before decommissioning Firestore usage.
- Document rollback steps in README/AGENTS.md.

Would an agent likely miss this without help? Yes. Documentation updates:
- Update README with the Neo4j migration notes, environment setup, and how to run locally.
- Add a quick reference for common Cypher queries used by the app.
