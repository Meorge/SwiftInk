//
//  File.swift
//  
//
//  Created by Malcolm Anderson on 8/15/23.
//

import Foundation

public class FloatValue: BaseValue {
    public var isTruthy: Bool {
        value! != 0.0
    }
    
    public var value: Float?
    
    public typealias T = Float
    
    public var valueType: ValueType {
        .Float
    }
    
    public func Cast(_ newType: ValueType) throws -> (any BaseValue)? {
        if newType == valueType {
            return self
        }
        
        if newType == .Bool {
            return BoolValue(value == 0.0 ? false : true)
        }
        
        if newType == .Int {
            return IntValue(Int(value!))
        }
        
        if newType == .String {
            return StringValue(String(describing: value!))
        }
        
        throw StoryError.badCast(valueObject: self, sourceType: valueType, targetType: newType)
    }
    
    public init(_ floatVal: Float) {
        value = floatVal
    }
    
    public convenience init() {
        self.init(0.0)
    }
}
