//
//  File.swift
//  
//
//  Created by Malcolm Anderson on 8/15/23.
//

import Foundation

public class StringValue: BaseValue {
    public var isTruthy: Bool {
        value!.count > 0
    }
    
    public var value: String?
    
    public typealias T = String
    
    public var valueType: ValueType {
        .String
    }
    
    private(set) var isNewline: Bool
    private(set) var isInlineWhitespace: Bool
    public var isNonWhitespace: Bool {
        !isNewline && !isInlineWhitespace
    }
    
    public init(_ str: String) {
        value = str
        // Classify whitespace status
        isNewline = value == "\n"
        isInlineWhitespace = true
        for c in value! {
            if c != " " && c != "\t" {
                isInlineWhitespace = false
                break
            }
        }
    }
    
    public convenience init() {
        self.init("")
    }
    
    public func Cast(_ newType: ValueType) -> (any BaseValue)? {
        if newType == valueType {
            return self
        }
        
        // NOTE: no casting to bool??
        
        if newType == .Int {
            if let parsedInt = Int(value!) {
                return IntValue(parsedInt)
            }
            else {
                return nil
            }
        }
        
        if newType == .Float {
            if let parsedFloat = Float(value!) {
                return FloatValue(parsedFloat)
            }
            else {
                return nil
            }
        }
        
        fatalError("bad cast")
    }
}
