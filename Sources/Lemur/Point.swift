//
//  File.swift
//  
//
//  Created by Evgenij Lutz on 18.02.24.
//

import Foundation


public struct Point {
    public var x: Float
    public var y: Float
    
    public init() {
        self.x = 0
        self.y = 0
    }
    
    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
    
    public static var zero: Point {
        return .init()
    }
}


public extension Point {
    var cgPoint: CGPoint {
        return .init(x: CGFloat(x), y: CGFloat(y))
    }
}


public extension CGPoint {
    var point: Point {
        return .init(x: Float(x), y: Float(y))
    }
}
