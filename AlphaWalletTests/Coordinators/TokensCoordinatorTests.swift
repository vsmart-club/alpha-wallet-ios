// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class TokensCoordinatorTests: XCTestCase {
    
    func testRootViewController() {
        let coordinator = TokensCoordinator(
            navigationController: FakeNavigationController(),
            session: .make(),
            keystore: FakeKeystore(),
            tokensStorage: FakeTokensDataStore(),
            ethPrice: Subscribable<Double>(nil),
            assetDefinitionStore: AssetDefinitionStore(),
            tbmlStore: TbmlStore()
        )
        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is TokensViewController)
    }
}
