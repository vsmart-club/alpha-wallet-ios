// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

protocol TbmlBackingStore {
    var delegate: TbmlBackingStoreDelegate? { get set }

    subscript(contract: String) -> String? { get set }
    func lastModifiedDateOfCachedFile(forContract contract: String) -> Date?
    func forEachContractWithTbml(_ body: (String) -> Void)
    func isOfficial(contract: String) -> Bool
    func isTbmlAvailable(forContract contract: String) -> Bool
}

extension TbmlBackingStore {
    func standardizedName(ofContract contract: String) -> String {
        return contract.add0x.lowercased()
    }

    //TODO improve performance
    func isTbmlAvailable(forContract contract: String) -> Bool {
        if let contents = self[contract], !contents.isEmpty {
            return true
        } else {
            return false
        }
    }
}

protocol TbmlBackingStoreDelegate: class {
    func invalidate(forContract contract: String)
}
