import Foundation

public enum DeviceIntegrity {

    public static func isCompromised() -> Bool {
        #if os(iOS) && !targetEnvironment(simulator)
        return suspiciousPathExists() || canWriteOutsideSandbox()
        #else
        return false
        #endif
    }

    #if os(iOS) && !targetEnvironment(simulator)
    private static let suspiciousPaths = [
        "/Applications/Cydia.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/bin/bash",
        "/usr/sbin/sshd",
        "/etc/apt",
        "/private/var/lib/apt/"
    ]

    private static func suspiciousPathExists() -> Bool {
        suspiciousPaths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    private static func canWriteOutsideSandbox() -> Bool {
        let probe = "/private/otpvault_integrity_probe"
        do {
            try "probe".write(toFile: probe, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(atPath: probe)
            return true
        } catch {
            return false
        }
    }
    #endif
}
