# 0072 - Thread-aware bulk actions for EmailList with collapseThreads using expansion and dedicated Interactors

Date: 2026-03-17

## Status

Proposed

## Context

After enabling `collapseThreads = true` (ADR-0071), each item in the `EmailList` represents a **ThreadId** instead of an individual `EmailId`.

However, the current system:

* All actions (`markAsRead`, `move`, `star`, etc.) operate on:

```dart
List<EmailId>
```

* Existing interactors:

    * `MarkAsEmailReadInteractor` (single email)
    * `MarkAsMultipleEmailReadInteractor` (bulk email)

* Existing repository:

```dart
abstract class ThreadDetailRepository {
  Future<List<EmailInThreadDetailInfo>> getThreadById(ThreadId threadId,
      Session session,
      AccountId accountId,
      MailboxId sentMailboxId,
      String ownEmailAddress,);
}
```

## Problem

When users perform actions on:

* a single thread
* multiple threads (multi-select)
* or a mix of threads and emails

the system must resolve:

```
ThreadId → List<EmailId>
```

Key challenges:

* N+1 API calls (`getThreadById`)
* Partial failures (one thread fails while others succeed)
* Duplicate `EmailId`s when merging results
* High latency with large selections
* Existing interactors are not designed for thread-level inputs

## Decision

### Adopt:

> **Thread-aware Interactors + Thread Expansion Service (cached, parallel, error-isolated) + reuse existing Email Interactors**

## Architecture Overview

```
Thread Interactor
    ↓
ThreadExpansionService
    ↓
List<EmailId>
    ↓
Existing Email Interactor
```

## 1. Thread Expansion Service

### Responsibility

* Convert `List<ThreadId>` → `List<EmailId>`
* Reuse `ThreadDetailRepository.getThreadById`
* Handle:

    * caching
    * parallel execution
    * error isolation

### Data Model

```dart
class ThreadExpansionResult {
  final List<EmailId> emailIds;
  final Map<ThreadId, Object> errors;

  ThreadExpansionResult({
    required this.emailIds,
    required this.errors,
  });
}
```

### Implementation

```dart
class ThreadExpansionService {
  final ThreadDetailRepository threadDetailRepository;

  final Map<ThreadId, List<EmailId>> _cache = {};

  ThreadExpansionService(this.threadDetailRepository);

  Future<ThreadExpansionResult> expandThreads({
    required List<ThreadId> threadIds,
    required Session session,
    required AccountId accountId,
    required MailboxId sentMailboxId,
    required String ownEmailAddress,
  }) async {
    final emailIds = <EmailId>{};
    final errors = <ThreadId, Object>{};

    final futures = threadIds.map((threadId) async {
      try {
        // Cache hit
        if (_cache.containsKey(threadId)) {
          emailIds.addAll(_cache[threadId]!);
          return;
        }

        final threadDetails = await threadDetailRepository.getThreadById(
          threadId,
          session,
          accountId,
          sentMailboxId,
          ownEmailAddress,
        );

        final ids = threadDetails
            .map((e) => e.emailId)
            .whereType<EmailId>()
            .toList();

        _cache[threadId] = ids;
        emailIds.addAll(ids);
      } catch (e) {
        // Error isolation
        errors[threadId] = e;
      }
    });

    await Future.wait(futures);

    return ThreadExpansionResult(
      emailIds: emailIds.toList(),
      errors: errors,
    );
  }

  void clearCache() => _cache.clear();
}
```

## 2. Thread-aware Interactor Pattern

### Principles

* Do not modify existing email interactors
* Do not duplicate business logic
* Only:

    * expand threads
    * delegate to existing email interactors

### Result Model

```dart
class ThreadActionResult {
  final List<EmailId> success;
  final Map<Id, SetError> actionErrors;
  final Map<ThreadId, Object> expansionErrors;

  ThreadActionResult({
    required this.success,
    required this.actionErrors,
    required this.expansionErrors,
  });
}
```

## 3. Example Implementations

### 3.1 MarkAsThreadReadInteractor

```dart
class MarkAsThreadReadInteractor {
  final ThreadExpansionService expansionService;
  final MarkAsMultipleEmailReadInteractor emailInteractor;

  MarkAsThreadReadInteractor(this.expansionService,
      this.emailInteractor,);

  Future<ThreadActionResult> execute({
    required Session session,
    required AccountId accountId,
    required MailboxId sentMailboxId,
    required String ownEmailAddress,
    List<ThreadId> threadIds = const [],
    List<EmailId> emailIds = const [],
  }) async {
    final expansion = await expansionService.expandThreads(
      threadIds: threadIds,
      session: session,
      accountId: accountId,
      sentMailboxId: sentMailboxId,
      ownEmailAddress: ownEmailAddress,
    );

    final allEmailIds = {
      ...emailIds,
      ...expansion.emailIds,
    }.toList();

    if (allEmailIds.isEmpty) {
      return ThreadActionResult(
        success: [],
        actionErrors: {},
        expansionErrors: expansion.errors,
      );
    }

    final result = await emailInteractor.execute(
      session: session,
      accountId: accountId,
      emailIds: allEmailIds,
    );

    return ThreadActionResult(
      success: result.emailIdsSuccess,
      actionErrors: result.mapErrors,
      expansionErrors: expansion.errors,
    );
  }
}
```

### 3.2 MoveThreadInteractor

```dart
class MoveThreadInteractor {
  final ThreadExpansionService expansionService;
  final MoveMultipleEmailInteractor moveInteractor;

  MoveThreadInteractor(this.expansionService,
      this.moveInteractor,);

  Future<ThreadActionResult> execute({
    required Session session,
    required AccountId accountId,
    required MailboxId destinationMailboxId,
    required MailboxId sentMailboxId,
    required String ownEmailAddress,
    List<ThreadId> threadIds = const [],
  }) async {
    final expansion = await expansionService.expandThreads(
      threadIds: threadIds,
      session: session,
      accountId: accountId,
      sentMailboxId: sentMailboxId,
      ownEmailAddress: ownEmailAddress,
    );

    if (expansion.emailIds.isEmpty) {
      return ThreadActionResult(
        success: [],
        actionErrors: {},
        expansionErrors: expansion.errors,
      );
    }

    final result = await moveInteractor.execute(
      session: session,
      accountId: accountId,
      emailIds: expansion.emailIds,
      destinationMailboxId: destinationMailboxId,
    );

    return ThreadActionResult(
      success: result.emailIdsSuccess,
      actionErrors: result.mapErrors,
      expansionErrors: expansion.errors,
    );
  }
}
```

## 4. Key Design Properties

### Error Isolation

* Each thread expansion is wrapped in `try/catch`
* Failure of one thread does not affect others

### Deduplication

```dart

final allEmailIds = {
  ...emailIds,
  ...expandedEmailIds,
};
```

### Cache

```dart
Map<ThreadId, List<EmailId>>
```

* Reduces repeated calls to `getThreadById`
* Improves performance for repeated actions

### Parallel Execution

```dart
await Future.wait(...);
```

* Minimizes latency for multi-thread operations

## 5. Cache Invalidation

Cache must be cleared when:

* Mailbox sync occurs
* Email state changes (read, star, move, delete)
* Thread content changes
* `collapseThreads` is toggled

```dart
expansionService.clearCache();
```

## Consequences

### Positive

* Reuses all existing email business logic
* No backend changes required
* Scales well for multi-selection
* Supports partial success (better UX)
* Clear separation between Thread and Email domains

### Negative

* Increased number of interactors
* Requires careful cache invalidation
* Still involves multiple API calls (mitigated via cache + parallelism)

## Summary

```
Thread Action Flow:

ThreadIds
  → expandThreads (parallel + cache + error-isolated)
  → extract EmailIds
  → deduplicate
  → call existing Email Interactor
  → return (success + actionErrors + expansionErrors)
```
