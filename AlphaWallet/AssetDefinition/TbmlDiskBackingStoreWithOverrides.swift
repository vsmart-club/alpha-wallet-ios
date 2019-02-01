// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

class TbmlDiskBackingStoreWithOverrides: TbmlBackingStore {
    private let officialStore = TbmlDiskBackingStore()
    private let overridesStore: TbmlBackingStore
    weak var delegate: TbmlBackingStoreDelegate?
    static let overridesDirectoryName = "tbmlOverrides"

    init(overridesStore: TbmlBackingStore? = nil) {
        if let overridesStore = overridesStore {
            self.overridesStore = overridesStore
        } else {
            let store = TbmlDiskBackingStore(directoryName: TbmlDiskBackingStoreWithOverrides.overridesDirectoryName)
            self.overridesStore = store
            store.watchDirectoryContents { [weak self] contract in
                self?.delegate?.invalidate(forContract: contract)
            }
        }
    }

    subscript(contract: String) -> String? {
        get {
            return overridesStore[contract] ?? officialStore[contract]
        }
        set(contents) {
            officialStore[contract] = contents
        }
    }

    func isOfficial(contract: String) -> Bool {
        if overridesStore[contract] != nil {
            return false
        }
        return officialStore.isOfficial(contract: contract)
    }

    func lastModifiedDateOfCachedFile(forContract contract: String) -> Date? {
        //Even with an override, we just want to fetch the latest official version. Doesn't imply we'll use the official version
        return officialStore.lastModifiedDateOfCachedFile(forContract: contract)
    }

    func forEachContractWithTbml(_ body: (String) -> Void) {
        var overriddenContracts = [String]()
        overridesStore.forEachContractWithTbml { contract in
            overriddenContracts.append(contract)
            body(contract)
        }
        officialStore.forEachContractWithTbml { contract in
            if !overriddenContracts.contains(contract) {
                body(contract)
            }
        }
    }
}
