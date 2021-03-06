//
// Created by James Sangalli on 24/3/18.
//

import Foundation
@testable import AlphaWallet
import XCTest
import BigInt
import TrustKeystore

class UniversalLinkHandlerTests: XCTestCase {
    
    func testUniversalLinkParser() {
        let config = Config.make()
        guard config.server == .main else {
            XCTFail("This test expects itself to be run on Mainnet.")
            return
        }

        let testUrl = "https://aw.app/AQAAAAAAAACjNHyO0TRETCUWmHLJCmNg1Cs2kQFxEtQiQ269SZP2r2Y6CETiCqCE3HGQa63LYjsaCOccJi0mj9bpsmnZCwFkjVcNaaJ6Ed8lVU83UiGILQZ4CcFhHA=="
        if let signedOrder = UniversalLinkHandler(config: config).parseUniversalLink(url: testUrl, prefix: Constants.mainnetMagicLinkPrefix) {
            XCTAssertGreaterThanOrEqual(signedOrder.signature.count, 130)
            let url = UniversalLinkHandler(config: config).createUniversalLink(signedOrder: signedOrder)
            print(url)
            XCTAssertEqual(testUrl, url)
        }
    }
    
    func testCreateUniversalLink() {
        var indices = [UInt16]()
        indices.append(1)
        let contractAddress = "0x1"
        let testOrder1 = Order(price: BigUInt("1000000000")!,
                               indices: indices,
                               expiry: BigUInt("0")!,
                               contractAddress: contractAddress,
                               count: 3,
                               nonce: BigUInt(0),
                               tokenIds: [BigUInt](),
                               spawnable: false,
                               nativeCurrencyDrop: false
        )
        
        var testOrders = [Order]()
        testOrders.append(testOrder1)
//        let account = try! EtherKeystore().getAccount(for: Address(string: "0x007bEe82BDd9e866b2bd114780a47f2261C684E3")!)
//        let signedOrder = try! OrderHandler().signOrders(orders: testOrders, account: account!)
//        let url = UniversalLinkHandler().createUniversalLink(signedOrder: signedOrder[0])
//        print(url)
    }

}
