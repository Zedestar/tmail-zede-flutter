# 0075. Fix load more not triggered on iOS when fast scrolling to bottom

Date: 2026-03-31

## Status

- Issues:
  - [TF-4425 Bug: load more is not working](https://github.com/linagora/tmail-flutter/issues/TF-4425)

## Context

On iOS 18, the `handleLoadMoreEmailsRequest()` was not called when users fast-scrolled to the bottom of the email list.

The scroll listener in `thread_view.dart` used an exact equality check to detect when the user had reached the bottom:

```dart
bool _handleScrollNotificationListener(ScrollNotification scrollInfo) {
  if (scrollInfo is ScrollEndNotification &&
      scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent &&
      !controller.loadingMoreStatus.value.isRunning &&
      scrollInfo.metrics.axisDirection == AxisDirection.down
  ) {
    controller.handleLoadMoreEmailsRequest();
  }
  return false;
}
```

**Root cause: iOS `BouncingScrollPhysics` causes overscroll past `maxScrollExtent`.**

The `ListView` uses `AlwaysScrollableScrollPhysics()` without an explicit `parent`. This means the effective physics inherits from the platform's ambient `ScrollConfiguration`:
- **Android** → `ClampingScrollPhysics`: clamps `pixels` within `[0, maxScrollExtent]`. When the user reaches the bottom, `pixels` is always exactly equal to `maxScrollExtent` when `ScrollEndNotification` fires.
- **iOS** → `BouncingScrollPhysics`: allows `pixels` to overshoot `maxScrollExtent` (the rubber-band/bounce effect). When the user fast-scrolls and lifts their finger, `pixels > maxScrollExtent` at the moment `ScrollEndNotification` fires. The spring-back animation that follows only emits `ScrollUpdateNotification` — no second `ScrollEndNotification` is ever fired once the content settles at `maxScrollExtent`.

As a result, the condition `pixels == maxScrollExtent` is **never true** at `ScrollEndNotification` time on iOS during fast scrolling, so `handleLoadMoreEmailsRequest()` is never called.

This became more pronounced on iOS 18 because Apple increased scroll momentum and overscroll sensitivity, making the overshoot happen more frequently and with a larger delta.

## Decision

Change the equality check to a greater-than-or-equal check:

```dart
bool _handleScrollNotificationListener(ScrollNotification scrollInfo) {
  if (scrollInfo is ScrollEndNotification &&
      scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent &&
      !controller.loadingMoreStatus.value.isRunning &&
      scrollInfo.metrics.axisDirection == AxisDirection.down
  ) {
    controller.handleLoadMoreEmailsRequest();
  }
  return false;
}
```

Using `>=` instead of `==` ensures that:
- On **iOS**: when `pixels > maxScrollExtent` (overscroll) at `ScrollEndNotification` time, the condition is still satisfied and load more is triggered correctly.
- On **Android**: behaviour is unchanged — `pixels == maxScrollExtent` still satisfies `>=`.

The `loadingMoreStatus.isRunning` guard already prevents duplicate requests, so triggering on overscroll does not cause multiple concurrent load-more calls.

## Consequences

- Load more is correctly triggered on iOS 18 when fast-scrolling to the bottom of the email list.
- No change in behavior on Android.
- No risk of duplicate requests due to the existing `isRunning` guard.
