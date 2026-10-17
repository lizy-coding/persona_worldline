# AGENT RULESET

```yaml
scope: project-root/**
precedence:
  AGENTS.override.md: tighten-only
product:
  platform: Flutter Web/PWA
  runtime: client-only
  mode: single-player
  required_flow: [start, event, choice, state_change, branch, ending, profile, restart]
```

## MODULES

| Path | Role | Allowed dependencies | Forbidden |
|---|---|---|---|
| `lib/game/models.dart` | domain models; JSON contract; validation | `dart:*` | Flutter; Riverpod; storage; UI |
| `lib/game/engine.dart` | conditions; effects; transitions; results | models | Flutter; Session; storage; story-specific logic |
| `lib/game/session.dart` | application ports; coordinator; controller; session | engine; models | Flutter; storage implementations; duplicated rules |
| `lib/game/infrastructure.dart` | Asset/storage adapters | Session ports; models; Flutter plugins | game rules; story branching |
| `lib/story_catalog.dart` | story business metadata | models | asset loading; storage; UI branching |
| `lib/main.dart` | composition; Providers; UI | Session; Infrastructure; models | JSON parsing; scoring; ending logic; direct storage |
| `assets/content/*.json` | story packs | schema contract | executable code; UI types |
| `test/**` | contract and regression tests | production APIs | production-only behavior |

```text
Presentation -> Application(Session/Coordinator) -> Domain(Engine -> Models)
Presentation -> Infrastructure -> Application ports
JSON -> Infrastructure(ContentPackRepository) -> Models
```

`ARCH-001 MUST` preserve dependency direction.

`ARCH-002 MUST_NOT` use business singleton.

`ARCH-003 MUST` inject dependencies via constructor or Provider.

`ARCH-004 MUST_NOT` represent core state as generic `Map<String, dynamic>`; JSON boundary only.

`ARCH-005 MUST_NOT` encode story-specific branches in Widget, Controller, or Engine.

## CONTENT CONTRACT

Required pack fields:

```text
schemaVersion packId version title summary intro flowRules
startEventId dimensions archetypes events endings
```

`CONTENT-001 MUST` map one story line to one complete `GameContentPack` JSON.

`CONTENT-002 MUST` keep `packId` stable per story; bump `version` for content changes; bump `schemaVersion` for incompatible contract changes.

`CONTENT-003 MUST` keep event and ending IDs globally unique inside a pack.

`CONTENT-004 MUST` assign each action either one-or-more typed `routes` or `endsStory: true`, never both.

`CONTENT-005 MUST` reject duplicate IDs, unknown types, unreachable events, events without actions, invalid score references, and routes without valid targets.

`CONTENT-005A MUST` define a positive `flowRules.minimumChoiceCount` and `maximumChoiceCount >= minimumChoiceCount`.

`CONTENT-005B MUST` define initial numeric values and bounds on every score dimension; visible dimensions are presentation metadata only.

`CONTENT-005C MUST` resolve endings through ordered typed `endingRules` ending with an unconditional fallback.

`CONTENT-005D MUST` persist the deterministic random state and cap every run through `maximumChoiceCount`; cycles are allowed only because this cap guarantees termination.

`CONTENT-005E MUST` define reusable story-level random diversions once in `flowRules.randomRoutes`; do not duplicate the same random rule across actions.

`CONTENT-006 MUST` implement new action/condition/effect as typed model + parser diagnostic + executor/evaluator + tests.

`CONTENT-007 MUST_NOT` silently ignore unknown action/condition/effect types.

`CONTENT-008 MUST_NOT` use dynamic code execution, scripting language, or remote executable content.

`CONTENT-009 SHOULD` implement new events, text, initial scores, choice-count ranges, weighted routes, flags, branches, archetypes, and dynamic endings through JSON only.

`CONTENT-010 MUST` format `assets/content/*.json` with 2-space indentation, one property per line, UTF-8, trailing newline, and no comments.

Canonical example: `assets/content/core_pack.json`.

## ADD STORY

```yaml
required_changes:
  - assets/content/<pack>.json
  - pubspec.yaml: flutter.assets
  - lib/story_catalog.dart: StoryDescriptor
  - lib/main.dart: AssetContentPackRepository asset map
  - test: parse + seeded path + ending resolution
forbidden_changes_without_new_rule_type:
  - lib/game/engine.dart
  - event/intro/result widgets
storage_key: persona_worldline.save.<packId>
```

`STORY-001 MUST` route story selection through `GameCoordinator`.

`STORY-002 MUST` load content through `ContentPackRepository`.

`STORY-003 MUST` isolate saves by `packId`; validate save schema and pack version.

`STORY-004 MUST` reuse Intro/Event/Result UI for every pack.

`STORY-005 MUST_NOT` expose asset paths through `StoryDescriptor` or Widget.

`STORY-006 MUST_NOT` add remote catalogs, registry frameworks, or story-specific routes without explicit requirement.

## STATE / SAVE

`STATE-001 MUST` advance flow only through `GameController`/`GameRuntime`.

`STATE-002 MUST` autosave after each valid action.

`STATE-003 MUST` serialize `schemaVersion` and `contentPackVersion`.

`STATE-004 MUST` clear corrupt/incompatible save and allow new game.

`STATE-005 MUST` update round-trip serialization tests for every state-field change.

## SCOPE DENYLIST

```text
backend auth multiplayer analytics AI_API remote_content_update
free_text_action full_RPG complex_map inventory monetization
generic_workflow_engine empty_future_pages empty_future_services
```

`SCOPE-001 MUST_NOT` add denylisted capability without explicit user requirement.

## CHANGE POLICY

`CHANGE-001 MUST` prefer incremental changes.

`CHANGE-002 MUST` preserve module roles unless a concrete requirement cannot fit existing boundary.

`CHANGE-003 MUST_NOT` commit `build/`, `.dart_tool/`, logs, secrets, IDE state, or generated caches.

## REMOTE MAINTENANCE

- Canonical repository: https://github.com/lizy-coding/persona_worldline. Daily development uses a focused branch and a pull request targeting `master`.
- Start by inspecting the branch, HEAD, Git status, remote baseline, this guide, and the files named by the task. Preserve existing dirty work and expand reads through concrete imports or contracts.
- Project workflows must run from any checkout path. They must not require personal skill libraries, local assistant installations, login state, or neighboring repositories.
- Keep personal assistant plans, task receipts, private skills, credentials, and runtime state local. The committed project documentation is sufficient for maintenance.
- Git actions follow the current task's authorization. Do not ask again for already authorized actions. Without authorization, do not commit, push, merge, publish, or change repository settings. Never force-push over another contributor's work.
- Pushing a feature branch or opening a PR does not deploy the site. Merging into `master` triggers the existing Pages deployment; merging and deployment require the applicable task authorization.

## REQUIRED CHECKS

The verified toolchain is Flutter 3.47.2 / Dart 3.13.2. CI and Pages use the same Flutter version. Resolve the committed lockfile through the standard pub.dev registry.

```bash
bash tool/check.sh
```

This installs locked dependencies, checks formatting in `lib`, `test`, and `tool`, runs static analysis and tests, and validates every story pack plus the documentation template. Do not skip failures or replace a failed validator with `|| true`.

For Web, asset, dependency, or deployment changes also run:

```bash
flutter build web --release
```

PR CI always checks the Web build. For story or UI changes, record the tested path, viewport, save/reload behavior, and screenshots when useful. Automated build evidence and browser interaction evidence are separate.

For documentation-only work, check changed Markdown, referenced paths, and `git diff --check`; rely on PR CI for the unchanged application gate unless a concrete concern needs local reproduction.

## ADD STORY WORKFLOW

Follow `docs/ADDING_STORIES.md`. The reusable starter is `docs/templates/story_pack.json`, outside the bundled game assets.

1. Copy the template into `assets/content/<pack>.json`, fill in the story contract, and validate it with `dart run tool/validate_pack.dart <path>`.
2. Register business metadata in `lib/story_catalog.dart` and the asset mapping in `lib/main.dart`. The existing `assets/content/` declaration covers new files.
3. Add parsing, seeded-path, and ending-resolution coverage; do not add story-specific logic to the engine or widgets.
4. Run the shared gate and Web build, then verify the requested story flow in the browser.

## CODE REVIEW RULES

- New content must preserve typed schema validation, deterministic saved random state, bounded choice counts, and an unconditional ending fallback.
- Story selection and persistence must remain isolated by pack ID and content version. UI and storage adapters must not duplicate game rules.
- Reject prerequisites on private local Agent files or personal directory layouts. Validation failures must propagate; historical task receipts are not current evidence.
