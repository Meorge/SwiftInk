import Foundation
import SwiftyJSON

public class Flow {
    public var name: String?
    public var callStack: CallStack?
    public var outputStream: [Object] = []
    public var currentChoices: [Choice] = []
    
    public init(_ name: String, _ story: Story) {
        self.name = name
        self.callStack = CallStack(story)
        self.outputStream = []
        self.currentChoices = []
    }
    
    public init(_ name: String, _ story: Story, _ jObject: [String: JSON]) throws {
        self.name = name
        self.callStack = CallStack(story)
        
        // TODO: Reimplement for SwiftyJSON
        try self.callStack!.SetJsonToken(jObject["callstack"]!.dictionaryValue, story)
        self.outputStream = try JArrayToRuntimeObjList(jsonArray: jObject["outputStream"]!.arrayValue)
        self.currentChoices = try JArrayToRuntimeObjList(jsonArray: jObject["currentChoices"]!.arrayValue).map { $0 as! Choice }
        
        // choiceThreads is optional
        var jChoiceThreadsObj = jObject["choiceThreads"]!.dictionary!
        try LoadFlowChoiceThreads(jChoiceThreadsObj, story)
    }
    
    // TODO: Reimplement for SwiftyJSON
    public func WriteJson() -> [String: Any?] {
        fatalError("Reimplement for SwiftyJSON")
//        var output: [String: Any?] = [
//            "callstack": callStack?.WriteJson(),
//            "outputStream": WriteListRuntimeObjs(outputStream),
//        ]
//
//        // choiceThreads: optional
//        // Has to come BEFORE the choices themselves are written out
//        // since the originalThreadIndex of each choice needs to be set
//        var hasChoiceThreads = false
//        var choiceThreads: [String: Any?] = [:]
//        for c in currentChoices {
//            c.originalThreadIndex = c.threadAtGeneration?.threadIndex
//
//            if callStack?.ThreadWithIndex(c.originalThreadIndex!) == nil {
//                choiceThreads[String(c.originalThreadIndex!)] = c.threadAtGeneration?.WriteJson()
//            }
//
//        }
//
//        output["currentChoices"] = currentChoices.map { $0.WriteJson() }
//
//        return output
    }
    
    // Used both to load old format and current
    public func LoadFlowChoiceThreads(_ jChoiceThreads: [String: JSON], _ story: Story) throws {
        for choice in currentChoices {
            let foundActiveThread = callStack?.ThreadWithIndex(choice.originalThreadIndex!)
            if foundActiveThread != nil {
                choice.threadAtGeneration = foundActiveThread!.Copy()
            }
            else {
                let jSavedChoiceThread = jChoiceThreads[String(describing: choice.originalThreadIndex!)]!.dictionaryValue
                choice.threadAtGeneration = try CallStack.Thread(jSavedChoiceThread, story)
            }
        }
    }
}
