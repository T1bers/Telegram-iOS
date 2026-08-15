# AyuGram patches on Telegram-iOS

This fork of [TelegramMessenger/Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS) adds native AyuGram behaviour.

Project hub: https://github.com/stillemptyNOW/AyuGram-iOS

## What is wired

| Setting | Hook |
| --- | --- |
| Ghost: no read receipts | `ApplyMaxReadIndexInteractively.swift` skips `notifyAppliedIncomingReadMessages` |
| Ghost: no online | `ManagedAccountPresence.swift` skips `account.updateStatus(offline: false)` |
| Ghost: force offline | same file sends `updateStatus(offline: true)` |
| Settings screen | `SettingsUI` → `ayuGramSettingsController` / `makeAyuGramSettingsController` |

Toggles persist in UserDefaults suite `ayuconfig` (same keys as AyuGram4A).
