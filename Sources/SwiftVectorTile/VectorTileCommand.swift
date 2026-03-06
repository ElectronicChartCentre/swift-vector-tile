//
//  VectorTileCommand.swift
//

import Foundation

internal enum VectorTileCommand : Int {

    /**
     * MoveTo: 1. (2 parameters follow)
     */
    case moveTo = 1
    
    /**
     * LineTo: 2. (2 parameters follow)
     */
    case lineTo = 2

    /**
     * ClosePath: 7. (no parameters follow)
     */
    case closePath = 7

}
