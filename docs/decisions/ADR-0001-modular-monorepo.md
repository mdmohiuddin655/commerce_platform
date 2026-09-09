# ADR-0001 — Modular monorepo with layered Flutter features

- **Status:** Accepted
- **Date:** 2026-09-09
- **Task:** FND-001
- **Source:** `SHARED_BLUEPRINT.md`, "Architectural decision"

## Context

Five role applications (admin, user, agent, picker, rider) share one commerce
domain: one order lifecycle, one assignment model, one custody chain, one
ledger. Five separate repositories would fork those rules five ways.

## Decision

One repository containing `apps/`, `packages/`, `backend/`, `infra/`, `docs/`
and `tools/`, with layered features
(`lib/features/<feature>/{domain,application,data,presentation}`), a shared
design system and shared contracts, and a trusted command backend using a
transactional outbox.

## Consequences

- Shared contracts change in one place and all five apps see it in one commit.
- Packages must never import apps; backend modules expose ports instead of
  writing each other's collections. Enforced by `tools/check_layering.sh`.
- One resolved dependency set (ADR-0002), so no app drifts onto a different
  version of a shared package.
- BLoC/Cubit is *our* selected convention for the `application` layer, not a
  requirement prescribed by Flutter.
- The domain/application split is justified by shared commerce workflows; it is
  not ceremony imported for its own sake.

## Explicit non-claims

This is a project-specific synthesis. Shopify describes explicit module
boundaries inside its monolith and Uber describes centrally modelled
fulfillment entities and lifecycles; those support the *idea* of boundaries and
orchestration. They do not mean this repository reproduces either company's
infrastructure, and no capacity claim follows from the shape of the tree.
