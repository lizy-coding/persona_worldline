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

## REQUIRED CHECKS

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Trigger: Web setup | assets | dependencies

```bash
flutter build web
```
