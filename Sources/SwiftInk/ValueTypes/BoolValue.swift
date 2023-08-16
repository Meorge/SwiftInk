//
//  File.swift
//  
//
//  Created by Malcolm Anderson on 8/15/23.
//

import Foundation

public class BoolValue: BaseValue {
    public var isTruthy: Bool {
        value!
    }
    
    public var value: Bool?
    
    public typealias T = Bool
    
    public var valueType: ValueType {
        .Bool
    }
    
    public func Cast(_ newType: ValueType) throws -> (any BaseValue)? {
        if newType == valueType {
            return self
        }
        
        if newType == .Int {
            return IntValue(value! ? 1 : 0)
        }
        
        if newType == .Float {
            return FloatValue(value! ? 1.0 : 0.0)
        }
        
        if newType == .String {
            return StringValue(value! ? "true" : "false")
        }
        
        throw StoryError.badCast(valueObject: self, sourceType: valueType, targetType: newType)
    }
    
    public init(_ boolVal: Bool) {
        value = boolVal
    }
    
    public convenience init() {
        self.init(false)
    }
}
