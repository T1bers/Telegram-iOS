import Foundation

/// AyuGram gates. Same UserDefaults keys as AyuGram-iOS / AyuGram4A.
public enum AyuGate {
    public static let suiteName = "ayuconfig"
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    public static func bool(_ key: String, fallback: Bool) -> Bool {
        if defaults.object(forKey: key) == nil {
            return fallback
        }
        return defaults.bool(forKey: key)
    }

    public static func set(_ key: String, _ value: Bool) {
        defaults.set(value, forKey: key)
        defaults.synchronize()
    }

    public static var sendReadPackets: Bool { bool("sendReadPackets", fallback: true) }
    public static var sendOnlinePackets: Bool { bool("sendOnlinePackets", fallback: true) }
    public static var sendUploadProgress: Bool { bool("sendUploadProgress", fallback: true) }
    public static var sendOfflinePacketAfterOnline: Bool { bool("sendOfflinePacketAfterOnline", fallback: false) }
    public static var saveDeletedMessages: Bool { bool("saveDeletedMessages", fallback: true) }
    public static var saveMessagesHistory: Bool { bool("saveMessagesHistory", fallback: true) }
    public static var disableAds: Bool { bool("disableAds", fallback: true) }
    public static var localPremium: Bool { bool("localPremium", fallback: false) }
    public static var markReadAfterSend: Bool { bool("markReadAfterSend", fallback: true) }

    public static var isGhostModeActive: Bool {
        !sendReadPackets && !sendOnlinePackets && !sendUploadProgress && sendOfflinePacketAfterOnline
    }

    public static func setGhostMode(_ enabled: Bool) {
        set("sendReadPackets", !enabled)
        set("sendOnlinePackets", !enabled)
        set("sendUploadProgress", !enabled)
        set("sendOfflinePacketAfterOnline", enabled)
    }
}
