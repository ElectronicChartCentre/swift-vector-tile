//
//  VectorTileAttribute.swift
//

import Foundation

public enum VectorTileAttribute : Hashable {
    case attInt(Int64)
    case attFloat(Float)
    case attDouble(Double)
    case attBool(Bool)
    case attString(String)
    
    public static func == (lhs: VectorTileAttribute, rhs: VectorTileAttribute) -> Bool {
        return lhs.toInt() == rhs.toInt()
    }
    
    public func hash(into hasher: inout Hasher) {
        self.toInt().hash(into: &hasher)
    }
    
    private func toInt() -> Int {
        switch self {
        case let .attInt(aInt):
            return aInt.hashValue
        case let .attFloat(aFloat):
            return aFloat.hashValue
        case let .attDouble(aDouble):
            return aDouble.hashValue
        case let .attBool(aBool):
            return aBool.hashValue
        case let .attString(aString):
            return aString.hashValue
        }
    }
}
