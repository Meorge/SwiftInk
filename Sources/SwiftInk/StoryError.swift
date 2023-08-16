import Foundation

enum StoryError: Error {
    case badCast(valueObject: Any?, sourceType: ValueType, targetType: ValueType)
    case exactInternalStoryLocationNotFound(pathStr: String)
}
