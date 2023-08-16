//
//  File.swift
//  
//
//  Created by Malcolm Anderson on 8/16/23.
//

import Foundation

enum StoryError: Error {
    case badCast(valueObject: Any?, sourceType: ValueType, targetType: ValueType)
    case exactInternalStoryLocationNotFound(pathStr: String)
}
