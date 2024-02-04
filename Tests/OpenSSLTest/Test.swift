import OpenSSL
import XCTest

class MyTest: XCTestCase {
    func testExample() {
        OPENSSL_init()
        var bytes = Array(repeating: UInt8(0), count: 8)
        let statusCode = RAND_bytes(&bytes, 8)
        XCTAssertEqual(statusCode, 1)
    }
}
