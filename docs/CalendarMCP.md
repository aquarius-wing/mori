## Date Format

Always use `yyyy-MM-dd'T'HH:mm:ss'Z'` format for date and time.

Example:

```swift
let date = Date()
let isoFormatter = ISO8601DateFormatter()
isoFormatter.timeZone = TimeZone.current
let isoString = isoFormatter.string(from: date)
print("ISO 8601 String:", isoString)
```