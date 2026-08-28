import Foundation

let sha1Secret = Data("12345678901234567890".utf8)
let sha256Secret = Data("12345678901234567890123456789012".utf8)
let sha512Secret = Data("1234567890123456789012345678901234567890123456789012345678901234".utf8)

struct Vector {
    let secret: Data
    let algorithm: TOTP.Algorithm
    let seconds: TimeInterval
    let expected: String
}

let vectors: [Vector] = [
    Vector(secret: sha1Secret, algorithm: .sha1, seconds: 59, expected: "94287082"),
    Vector(secret: sha1Secret, algorithm: .sha1, seconds: 1111111109, expected: "07081804"),
    Vector(secret: sha1Secret, algorithm: .sha1, seconds: 1111111111, expected: "14050471"),
    Vector(secret: sha1Secret, algorithm: .sha1, seconds: 1234567890, expected: "89005924"),
    Vector(secret: sha1Secret, algorithm: .sha1, seconds: 2000000000, expected: "69279037"),
    Vector(secret: sha1Secret, algorithm: .sha1, seconds: 20000000000, expected: "65353130"),
    Vector(secret: sha256Secret, algorithm: .sha256, seconds: 59, expected: "46119246"),
    Vector(secret: sha512Secret, algorithm: .sha512, seconds: 59, expected: "90693936"),
]

var failures = 0
for vector in vectors {
    let totp = TOTP(secret: vector.secret, digits: 8, period: 30, algorithm: vector.algorithm)
    let actual = totp.code(at: Date(timeIntervalSince1970: vector.seconds))
    let ok = actual == vector.expected
    if !ok { failures += 1 }
    print("\(ok ? "PASS" : "FAIL")  t=\(Int(vector.seconds))  expected=\(vector.expected)  actual=\(actual)")
}

print(failures == 0 ? "\nall vectors passed" : "\n\(failures) vector(s) failed")
exit(failures == 0 ? 0 : 1)
