# Agreeo - Neo4j Integration & Implementation Report
**Project:** Agreeo (formerly MoveMate)  
**Course:** User-Driven Software Engineering

## Introduction
This document tracks the technical decisions, codebase changes, and implementation steps for integrating Neo4j as the primary database for Agreeo. Because Agreeo focuses on social movie discovery and group consensus, treating data as a graph is critical; Neo4j makes calculating similarities, friends’ tastes, and group shortlists efficient.

---

## Log 1: Authentication and Base AppUser Schema Migration
**Date:** May 10, 2026

**Objective:**
Migrate the MVP from a local/mock-only authentication flow to a real Node.js backend interfacing tightly with Neo4j.

**Problems solved:**
1. **Mock IDs:** The Flutter frontend previously generated random `UUID` tokens locally and stored preferences into `SharedPreferences`.
2. **Schema conflicts & Uniqueness:** The original node `(:User)` was too broad. We need to distinguish between actual mobile users and future imported historical datasets (like `:MovieLensUser`).

**Tasks Performed:**

### 1. Backend: Node.js & Neo4j Graph Driver
- Re-architected `backend/neo4jService.js` to enforce database constraints at initialization. We introduced constraints to enforce uniqueness on `uid` and `emailNormalized` for the new `(:AppUser)` label.
- Refactored `backend/authController.js` to handle `/auth/register` and `/auth/login` completely internally. The backend executes `MERGE`/`MATCH` Cypher queries to validate credentials (using the safe `bcryptjs` instead of the broken `bcrypt` component) and issues an `accessToken` / `refreshToken` combination via JWT. 
- Created a `/me` and `/me/onboarding` endpoint for the frontend to safely sync its local state with the graph state.

### 2. Frontend: Flutter UI & Riverpod State
- Refactored `AuthService` inside Flutter to parse the Backend's JWT and interact with the `/me` endpoints instead of running Cypher directly from the client (ensuring security and decoupled logic).
- Updated the `AppController` so `login` and `register` call an internal `_syncSessionWithBackend()` method. This correctly pulls the authentic `uid` from the database directly into the persistent UI state (`AppSession`) and keeps the `onboardingComplete` flag anchored to the Neo4j source of truth.
- Aligned the `logout` flow to correctly clear JWT tokens via `AuthService` rather than just clearing local interface caches.
- Updated `Neo4jUser` in Dart to correctly reflect the new `(:AppUser)` schema fields.

**Next Steps / Roadmap:**
- Execute the backend locally, connect the mobile frontend, and verify the Authentication Flow & Onboarding Gate end-to-end to close this sub-task definitively. Follow up with the data migration script for the new model.