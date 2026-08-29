import XCTest
@testable import OtpVaultCore

final class DeviceIntegrityTests: XCTestCase {

    func testSimulatorIsNotFlaggedAsCompromised() {
        XCTAssertFalse(DeviceIntegrity.isCompromised())
    }
}
