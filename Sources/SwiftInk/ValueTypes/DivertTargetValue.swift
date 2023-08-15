//
//  File.swift
//  
//
//  Created by Malcolm Anderson on 8/15/23.
//

import Foundation

public class DivertTargetValue: BaseValue, CustomStringConvertible {
    public var value: Path?
    
    public typealias T = Path
    
    public var valueType: ValueType {
        .DivertTarget
    }
    
    public var isTruthy: Bool {
        // TODO: throw an exception here
        false
    }
    
    public var targetPath: Path {
        get {
            value!
        }
        set {
            value = newValue
        }
    }
    
    public init(_ targetPath: Path?) {
        value = targetPath
    }
    
    public convenience init() {
        self.init(nil)
    }
    
    public func Cast(_ newType: ValueType) -> (any BaseValue)? {
        if newType == valueType {
            return self
        }
        
        fatalError("bad cast")
    }
    
    public var description: String {
        "DivertTargetValue(\(targetPath))"
    }
}
