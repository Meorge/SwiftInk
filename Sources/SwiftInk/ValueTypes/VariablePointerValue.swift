//
//  File.swift
//  
//
//  Created by Malcolm Anderson on 8/15/23.
//

import Foundation

public class VariablePointerValue: BaseValue, CustomStringConvertible {
    public var valueType: ValueType {
        .VariablePointer
    }
    
    public var isTruthy: Bool {
        fatalError("Shouldn't be checking the truthiness of a variable pointer")
    }
    
    public func Cast(_ newType: ValueType) -> (any BaseValue)? {
        if newType == valueType {
            return self
        }
        
        fatalError("Bad cast")
    }
    
    public var value: String?
    
    // NOTE: the C# code says it's misleading to use the string,
    // so uhhhhh be careful about that I guess
    public typealias T = String
    
    public var variableName: String {
        get {
            value!
        }
        set {
            value = newValue
        }
    }
    
    public var description: String {
        "VariablePointerValue(\(variableName))"
    }
    
    // Where the variable is located
    // -1 = default, unknown, yet to be determined
    // 0  = in global scope
    // 1+ = callstack element index + 1 (so first doesn't conflict with special global scope)
    public var contentIndex: Int
    
    public init(_ variableName: String?, _ contentIndex: Int = -1) {
        value = variableName
        self.contentIndex = contentIndex
    }
    
    public convenience init() {
        self.init(nil)
    }
    
}
