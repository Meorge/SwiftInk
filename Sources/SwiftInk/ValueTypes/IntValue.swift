//
//  File.swift
//  
//
//  Created by Malcolm Anderson on 8/15/23.
//

import Foundation

public class IntValue: BaseValue {
    public var isTruthy: Bool {
        value! != 0
    }
    
    public var value: Int?
    
    public typealias T = Int
    
    public var valueType: ValueType {
        .Int
    }
    
    public func Cast(_ newType: ValueType) throws -> (any BaseValue)? {
        if newType == valueType {
            return self
        }
        
        if newType == .Bool {
            return BoolValue(value == 0 ? false : true)
        }
        
        if newType == .Float {
            return FloatValue(Float(value!))
        }
        
        if newType == .String {
            return StringValue(String(describing: value!))
        }
        
        throw StoryError.badCast(valueObject: self, sourceType: valueType, targetType: newType)
    }
    
    public init(_ intVal: Int) {
        value = intVal
    }
    
    public convenience init() {
        self.init(0)
    }
}
