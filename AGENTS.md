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
- Install and run Neo4j locally using docker-compose (Recommended):
  docker-compose up -d neo4j
- Or run manually with persistence volumes:
  docker run -p 7474:7474 -p 7687:7687 -v neo4j_data:/data -e NEO4J_AUTH=neo4j/password123 neo4j:latest
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


## vexp <!-- vexp v2.0.25 -->

**MANDATORY: use `run_pipeline` - do NOT grep or glob the codebase.**
vexp returns pre-indexed, graph-ranked context in a single call.

### Workflow
1. `run_pipeline` with your task description - ALWAYS FIRST (replaces all other tools)
2. Make targeted changes based on the context returned
3. `run_pipeline` again only if you need more context

### Available MCP tools
- `run_pipeline` - **PRIMARY TOOL**. Runs capsule + impact + memory in 1 call.
  Auto-detects intent. Includes file content. Example: `run_pipeline({ "task": "fix auth bug" })`
- `get_skeleton` - compact file structure
- `index_status` - indexing status
- `expand_vexp_ref` - expand V-REF placeholders in v2 output

### Agentic search
- Do NOT use built-in file search, grep, or codebase indexing - always call `run_pipeline` first
- If you spawn sub-agents or background tasks, pass them the context from `run_pipeline`
  rather than letting them search the codebase independently

### Smart Features
Intent auto-detection, hybrid ranking, session memory, auto-expanding budget.

### Multi-Repo
`run_pipeline` auto-queries all indexed repos. Use `repos: ["alias"]` to scope. Run `index_status` to see aliases.
<!-- /vexp -->

## graphify <!-- graphify knowledge graph -->

A knowledge graph of the entire codebase is available as an MCP server. Agents can use it
to answer structural questions, find shortest paths between concepts, and discover
cross-module relationships without searching files one by one.

### Available MCP tools (via @graphify)
- `query_graph` — BFS/DFS traversals from a starting concept
- `get_node` — inspect a specific node's attributes
- `get_neighbors` — immediate neighbors of a node
- `get_community` — all nodes in a community
- `god_nodes` — most connected hub nodes
- `graph_stats` — summary statistics
- `shortest_path` — shortest path between two concepts

### When to use
- **First**: Check graphify first when asked about architecture or relationships.
  One query can replace 5-10 file reads.
- **Cross-module questions**: "What connects X to Y?" → `shortest_path`
- **Impact analysis**: "What does module Z touch?" → `get_neighbors` / BFS on Z
- **Orientation**: "What are the core abstractions?" → `god_nodes`

The graph lives at `.graphify/graph.json`. To regenerate after significant changes,
run `/graphify . --update`.

## Graphify MCP

Use the `graphify` MCP server when graph traversal is a better fit than plain text search.

- Build or refresh the workspace graph with `graphify_run` and `graphify_update`.
- Use `graphify_query`, `graphify_explain`, `graphify_path`, and `graphify_stats` for agent-facing navigation.
- Graphify output is generated under `.graphify/` and is already ignored by git.