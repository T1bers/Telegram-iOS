import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

private final class AyuGramSettingsArguments {
    let setGhost: (Bool) -> Void
    let setRead: (Bool) -> Void
    let setOnline: (Bool) -> Void
    let setUpload: (Bool) -> Void
    let setForceOffline: (Bool) -> Void
    let setSaveDeleted: (Bool) -> Void
    let setSaveEdits: (Bool) -> Void
    let setHideAds: (Bool) -> Void
    let setLocalPremium: (Bool) -> Void

    init(setGhost: @escaping (Bool) -> Void, setRead: @escaping (Bool) -> Void, setOnline: @escaping (Bool) -> Void, setUpload: @escaping (Bool) -> Void, setForceOffline: @escaping (Bool) -> Void, setSaveDeleted: @escaping (Bool) -> Void, setSaveEdits: @escaping (Bool) -> Void, setHideAds: @escaping (Bool) -> Void, setLocalPremium: @escaping (Bool) -> Void) {
        self.setGhost = setGhost
        self.setRead = setRead
        self.setOnline = setOnline
        self.setUpload = setUpload
        self.setForceOffline = setForceOffline
        self.setSaveDeleted = setSaveDeleted
        self.setSaveEdits = setSaveEdits
        self.setHideAds = setHideAds
        self.setLocalPremium = setLocalPremium
    }
}

private enum AyuSection: Int32 {
    case ghost = 0
    case details = 1
    case history = 2
    case extra = 3
}

private enum AyuEntry: ItemListNodeEntry {
    case ghostHeader
    case ghostValue(Bool)
    case ghostFooter
    case readValue(Bool)
    case onlineValue(Bool)
    case uploadValue(Bool)
    case forceOfflineValue(Bool)
    case historyHeader
    case saveDeleted(Bool)
    case saveEdits(Bool)
    case extraHeader
    case hideAds(Bool)
    case localPremium(Bool)

    var section: ItemListSectionId {
        switch self {
        case .ghostHeader, .ghostValue, .ghostFooter: return AyuSection.ghost.rawValue
        case .readValue, .onlineValue, .uploadValue, .forceOfflineValue: return AyuSection.details.rawValue
        case .historyHeader, .saveDeleted, .saveEdits: return AyuSection.history.rawValue
        case .extraHeader, .hideAds, .localPremium: return AyuSection.extra.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .ghostHeader: return 0
        case .ghostValue: return 1
        case .ghostFooter: return 2
        case .readValue: return 3
        case .onlineValue: return 4
        case .uploadValue: return 5
        case .forceOfflineValue: return 6
        case .historyHeader: return 7
        case .saveDeleted: return 8
        case .saveEdits: return 9
        case .extraHeader: return 10
        case .hideAds: return 11
        case .localPremium: return 12
        }
    }

    static func <(lhs: AyuEntry, rhs: AyuEntry) -> Bool { lhs.stableId < rhs.stableId }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyuGramSettingsArguments
        switch self {
        case .ghostHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "AYUGRAM", sectionId: self.section)
        case let .ghostValue(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Ghost mode", value: value, sectionId: self.section, style: .blocks, updated: { arguments.setGhost($0) })
        case .ghostFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Turns off read receipts, online status and upload progress. Same rules as AyuGram on Android."), sectionId: self.section)
        case let .readValue(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Send read receipts", value: value, sectionId: self.section, style: .blocks, updated: { arguments.setRead($0) })
        case let .onlineValue(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Send online status", value: value, sectionId: self.section, style: .blocks, updated: { arguments.setOnline($0) })
        case let .uploadValue(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Send upload progress", value: value, sectionId: self.section, style: .blocks, updated: { arguments.setUpload($0) })
        case let .forceOfflineValue(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Go offline after online", value: value, sectionId: self.section, style: .blocks, updated: { arguments.setForceOffline($0) })
        case .historyHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "MESSAGE HISTORY", sectionId: self.section)
        case let .saveDeleted(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Save deleted messages", value: value, sectionId: self.section, style: .blocks, updated: { arguments.setSaveDeleted($0) })
        case let .saveEdits(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Save edit history", value: value, sectionId: self.section, style: .blocks, updated: { arguments.setSaveEdits($0) })
        case .extraHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "EXTRA", sectionId: self.section)
        case let .hideAds(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Hide ads", value: value, sectionId: self.section, style: .blocks, updated: { arguments.setHideAds($0) })
        case let .localPremium(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Local Premium", value: value, sectionId: self.section, style: .blocks, updated: { arguments.setLocalPremium($0) })
        }
    }
}

private struct AyuState: Equatable {
    var ghost: Bool
    var read: Bool
    var online: Bool
    var upload: Bool
    var forceOffline: Bool
    var saveDeleted: Bool
    var saveEdits: Bool
    var hideAds: Bool
    var localPremium: Bool
    static func load() -> AyuState {
        AyuState(ghost: AyuGate.isGhostModeActive, read: AyuGate.sendReadPackets, online: AyuGate.sendOnlinePackets, upload: AyuGate.sendUploadProgress, forceOffline: AyuGate.sendOfflinePacketAfterOnline, saveDeleted: AyuGate.saveDeletedMessages, saveEdits: AyuGate.saveMessagesHistory, hideAds: AyuGate.disableAds, localPremium: AyuGate.localPremium)
    }
}

public func ayuGramSettingsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(AyuState.load(), ignoreRepeated: false)
    let stateValue = Atomic(value: AyuState.load())
    let updateState: ((AyuState) -> AyuState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    let reload = { updateState { _ in AyuState.load() } }
    let arguments = AyuGramSettingsArguments(
        setGhost: { AyuGate.setGhostMode($0); reload() },
        setRead: { AyuGate.set("sendReadPackets", $0); reload() },
        setOnline: { AyuGate.set("sendOnlinePackets", $0); reload() },
        setUpload: { AyuGate.set("sendUploadProgress", $0); reload() },
        setForceOffline: { AyuGate.set("sendOfflinePacketAfterOnline", $0); reload() },
        setSaveDeleted: { AyuGate.set("saveDeletedMessages", $0); reload() },
        setSaveEdits: { AyuGate.set("saveMessagesHistory", $0); reload() },
        setHideAds: { AyuGate.set("disableAds", $0); reload() },
        setLocalPremium: { AyuGate.set("localPremium", $0); reload() }
    )
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries: [AyuEntry] = [
            .ghostHeader, .ghostValue(state.ghost), .ghostFooter,
            .readValue(state.read), .onlineValue(state.online), .uploadValue(state.upload), .forceOfflineValue(state.forceOffline),
            .historyHeader, .saveDeleted(state.saveDeleted), .saveEdits(state.saveEdits),
            .extraHeader, .hideAds(state.hideAds), .localPremium(state.localPremium)
        ]
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("AyuGram"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }
    return ItemListController(context: context, state: signal)
}
