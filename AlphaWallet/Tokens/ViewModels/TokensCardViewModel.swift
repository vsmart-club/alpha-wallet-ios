//
//  TokensCardViewModel.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/24/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit

struct TokensCardViewModel {
    let token: TokenObject
    let tokenHolders: [TokenHolder]

    init(config: Config, token: TokenObject) {
        self.token = token
        self.tokenHolders = TokenAdaptor(config: config, token: token).getTokenHolders()
    }

    func item(for indexPath: IndexPath) -> TokenHolder {
        return tokenHolders[indexPath.row]
    }

    func numberOfItems(for section: Int) -> Int {
        return tokenHolders.count
    }

    func toggleDetailsVisible(for indexPath: IndexPath) -> [IndexPath] {
        let tokenHolder = item(for: indexPath)
        var changed = [indexPath]
        if tokenHolder.areDetailsVisible {
            tokenHolder.areDetailsVisible = false
        } else {
            for (i, each) in tokenHolders.enumerated() where each.areDetailsVisible {
                each.areDetailsVisible = false
                changed.append(.init(row: i, section: indexPath.section))
            }
            tokenHolder.areDetailsVisible = true
        }
        return changed
    }
}
