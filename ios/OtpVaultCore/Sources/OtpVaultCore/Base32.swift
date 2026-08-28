import Foundation

public enum Base32 {

    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    private static let lookup: [Character: UInt8] = {
        var table = [Character: UInt8]()
        for (index, character) in alphabet.enumerated() {
            table[character] = UInt8(index)
        }
        return table
    }()

    public static func decode(_ input: String) -> Data? {
        let cleaned = input
            .uppercased()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard !cleaned.isEmpty else { return Data() }

        var accumulatedBits = 0
        var accumulator = 0
        var output = Data()

        for character in cleaned {
            guard let value = lookup[character] else { return nil }
            accumulator = (accumulator << 5) | Int(value)
            accumulatedBits += 5
            if accumulatedBits >= 8 {
                accumulatedBits -= 8
                output.append(UInt8((accumulator >> accumulatedBits) & 0xFF))
            }
        }

        return output
    }
}
