---
description: 
globs: 
alwaysApply: true
---
When use LazyVStack, use index as id instead of using id of data

Example:
```swift
ScrollView {
    LazyVStack(spacing: 16) {
        ForEach(events.indices, id: \.self) { index in
            CalendarEventDetailRow(event: events[index])
                .padding(.horizontal, 20)
        }
    }
    .padding(.top, 20)
    .padding(.bottom, max(20, geometry.safeAreaInsets.bottom))
}
```