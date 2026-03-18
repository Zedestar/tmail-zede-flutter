# 0074 - Fix 404 on Label Refresh by Introducing Explicit `labelId` in Web Routing

Date: 2026-03-18

## Status

**Proposed**

## Context

A bug has been identified in the web application where refreshing a label view results in a **404 Not Found** error.

This issue breaks:

* Browser refresh behavior (F5)
* Deep linking (URL-based navigation)
* Bookmarking label views

## Observed Scenario

1. User opens a label (e.g., “Work”, “Important”)
2. URL updates accordingly
3. User refreshes the page
4. Application parses the URL
5. Result:

    * ❌ Label cannot be restored
    * ❌ Application redirects to 404 page

## Architecture Overview

```text
+---------------------+
|     Browser URL     |
| /dashboard?...      |
+----------+----------+
           |
           v
+---------------------+
|   Routing Layer     |
|  (RouteUtils)       |
+----------+----------+
           |
           v
+-----------------------------+
|     NavigationRouter        |
| mailboxId | labelId         |
+----------+------------------+
           |
           v
+-----------------------------+
|   Application Layer         |
|                             |
|  MailboxController          |
|   - MailboxTree (cached)    |
|   - getMailboxById()        |
|                             |
|  LabelController            |
|   - List<Label> (cached)    |
|   - getLabelById()          |
+----------+------------------+
           |
           v
+-----------------------------+
|   Presentation Layer        |
|   - PresentationMailbox     |
|   - UI Widgets              |
+-----------------------------+
```

## Key Insight

The routing layer is **type-agnostic** and relies entirely on URL semantics to reconstruct application state.

Therefore, the URL must explicitly encode:

* Entity identity (`mailboxId`, `labelId`)
* Entity type (Mailbox vs Label)

> Failing to encode entity type leads to **semantic misinterpretation during state reconstruction**.

## Root Cause Analysis

### 1. Identity ambiguity

Labels are represented using:

```dart
PresentationLabelMailbox
```

This makes labels behave similarly to mailboxes in the presentation layer, but they are **not equivalent entities**.

### 2. Incorrect URL encoding

Before the fix:

```url
/dashboard?type=normal&context=<id>
```

* `context` is intended for `mailboxId`
* But label IDs are incorrectly stored in `context`

### 3. Incorrect resolution on reload

On refresh:

1. URL is parsed
2. System interprets:

```text
mailboxId = <labelId>   // incorrect
```

3. Resolution:

```dart
findMailboxById(mailboxId)
```

❌ Fails → no matching mailbox

→ Redirect to 404

### 4. Missing routing dimension

| Entity  | Identifier |
| ------- | ---------- |
| Mailbox | mailboxId  |
| Label   | ❌ missing  |

The system lacks a way to distinguish entity types during routing.

## Sequence Diagram

### ❌ Before Fix

```text
User -> Browser: Open Label (L1)
Browser -> App: /dashboard?context=L1

App -> UI: Render Label (in-memory)

User -> Browser: Refresh

Browser -> App: /dashboard?context=L1

App -> Router: parse(context=L1)
Router -> MailboxController: mailboxId = L1

MailboxController -> MailboxTree: findMailboxById(L1)
MailboxTree --> null

App -> Router: navigate(404)
```

### ✅ After Fix

```text
User -> Browser: Open Label (L1)
Browser -> App: /dashboard?labelId=L1

User -> Browser: Refresh

Browser -> App: /dashboard?labelId=L1

App -> Router: parse(labelId=L1)
Router -> LabelController: resolve(labelId)

LabelController -> Cache: getLabelById(L1)
LabelController --> Label

App -> UI: open PresentationLabelMailbox
```

## Decision

### Introduce explicit `labelId` in routing

We introduce a new query parameter:

```text
labelId=<labelId>
```

### Updated Routing Structure

#### Mailbox

```url
/dashboard?type=normal&context=<mailboxId>
```

#### Label

```url
/dashboard?type=normal&labelId=<labelId>
```

### Navigation Model

```dart
NavigationRouter(
  mailboxId: ...,
  labelId: ...,
)
```

### Rationale

This approach is chosen because:

* Avoids overloading `mailboxId`
* Keeps routing deterministic and type-safe
* Avoids polymorphic parsing complexity
* Maintains clear separation of concerns

## Backward Compatibility Strategy

To prevent breaking existing URLs:

If `labelId` is absent but `context` exists:

```dart
if (mailboxId != null) {
  resolveMailbox(mailboxId);
} else if (labelId != null) {
  resolveLabel(labelId);
} else if (context != null) {
  resolveMailbox(context) ?? resolveLabel(context);
}
```

This ensures:

* Legacy URLs continue to function
* Smooth rollout without disruption

## Consequences

### Positive

#### 1. Fixes 404 issue

* Label views can be restored after refresh

#### 2. Deterministic routing

* Clear separation between mailbox and label

#### 3. Accurate URL state

* Supports deep linking and bookmarking
* Browser history reflects actual UI state

#### 4. Improved architecture clarity

* Routing layer becomes explicit and predictable

#### 5. Extensibility

Supports future entities:

* Smart folders
* Virtual mailboxes
* Tag-based views

### Negative

#### 1. Increased routing complexity

* Additional query parameter (`labelId`)

#### 2. Refactor required

* All navigation points must include `labelId`

#### 3. Temporary dual-logic support

* Requires fallback handling for legacy URLs

## Implementation Steps

### 1. Define query parameter

```dart
static const String paramLabelId = 'labelId';
```

### 2. Update URL generation

```dart
if (router.labelId != null)
  StringQueryParameter(paramLabelId, router.labelId!.value),
```

Applied across:

* ThreadController
* ListPresentationEmailExtension
* SearchEmailController
* MailboxDashboardController
* SingleEmailController

### 3. Update URL parsing

```dart
final labelParam = parameters[paramLabelId];
final labelId = labelParam != null ? Id(labelParam) : null;
```

### 4. Update PresentationMailbox

```dart
Id? get labelId =>
  isLabelMailbox ? (this as PresentationLabelMailbox).label.id : null;

MailboxId? get browserRouteMailboxId =>
  isLabelMailbox ? null : mailboxId;
```

### 5. Update routing resolution

```dart
if (mailboxId != null) {
  resolveMailbox(mailboxId);
} else if (labelId != null) {
  resolveLabel(labelId);
}
```

### 6. Label resolution

```dart
final matchedLabel =
  labelController.getLabelById(labelId);
```

### 7. Ensure browser URL consistency

All calls to:

```dart
RouteUtils.createUrlWebLocationBar(...)
```

must include:

```dart
labelId: selectedMailbox?.labelId
```

## Summary

### Root Cause

Label IDs were incorrectly encoded as mailbox IDs in the URL, causing resolution failure on reload.

### Solution

Introduce `labelId` as an explicit routing parameter to ensure correct entity resolution and eliminate ambiguity.

## References

* GitHub Issue: [https://github.com/linagora/tmail-flutter/issues/4384](https://github.com/linagora/tmail-flutter/issues/4384)