import Foundation

// Courtesy of https://stackoverflow.com/a/40868784
extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

// Courtesy of https://gist.github.com/harlanhaskins/a8a1837831af17cc81b90f26445c7aca
extension BinaryInteger {
    /// Gets the bit at the specified bit index in the receiver, reading from
    /// least to most-significant bit.
    ///
    /// For example,
    /// ```
    /// 0b0010.bit(at: 0) == false
    /// 0b0010.bit(at: 1) == true
    /// ```
    func bit<I>(at index: I) -> Bool where I: UnsignedInteger {
        return (self >> index) & 1 == 1
    }
    
    /// Sets the bit at the specified bit index in the receiver, reading from
    /// least to most-significant bit.
    ///
    /// For example,
    /// ```
    /// 0b0010.setBit(at: 0, to: true) → 0b0011
    /// 0b0010.setBit(at: 1, to: false) → 0b0000
    /// ```
    mutating func setBit<I>(at index: I, to bool: Bool) where I: UnsignedInteger {
        if bool {
            self |= (1 << index)
        } else {
            self &= ~(1 << index)
        }
    }
}

func degreesToRadians<F: BinaryFloatingPoint>(_ number: F) -> F {
    return (number * .pi) / 180
}
