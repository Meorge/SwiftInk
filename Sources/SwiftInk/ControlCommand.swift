import Foundation

public class ControlCommand: Object, CustomStringConvertible {
    public enum CommandType: Int {
        case notSet = -1
        case evalStart
        case evalOutput
        case evalEnd
        case duplicate
        case popEvaluatedValue
        case popFunction
        case popTunnel
        case beginString
        case endString
        case noOp
        case choiceCount
        case turns
        case turnsSince
        case readCount
        case random
        case seedRandom
        case visitIndex
        case sequenceShuffleIndex
        case startThread
        case done
        case end
        case listFromInt
        case listRange
        case listRandom
        case beginTag
        case endTag
        
        case TOTAL_VALUES
    }
    
    var commandType: CommandType
    
    public init(_ commandType: CommandType) {
        self.commandType = commandType
    }
    
    // Require default constructor for serialisation
    public override convenience init() {
        self.init(.notSet)
    }
    
    public func copy() -> ControlCommand {
        return ControlCommand(commandType)
    }
    
    // NOTE: The original C# code has a bunch of static methods here for
    // making code more succinct. Luckily, Swift's dot syntax for enums
    // makes it succinct already. So, no need for those functions! :)
    
    public var description: String {
        return "ControlCommand(\(commandType))"
    }
}
