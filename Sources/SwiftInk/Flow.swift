import Foundation
import SwiftyJSON

public class Flow {
    public var name: String?
    public var callStack: CallStack?
    public var outputStream: [Object] = []
    public var currentChoices: [Choice] = []
    
    public init(_ name: String, _ story: Story) {
        self.name = name
        self.callStack = CallStack(withStoryContext: story)
        self.outputStream = []
        self.currentChoices = []
    }
    
    public init(_ name: String, _ story: Story, _ jObject: [String: JSON]) throws {
        self.name = name
        self.callStack = CallStack(withStoryContext: story)
        
        try self.callStack!.setJSONToken(jObject["callstack"]!.dictionaryValue, withStoryContext: story)
        self.outputStream = try jsonArrayToRuntimeObjList(jsonArray: jObject["outputStream"]!.arrayValue)
        self.currentChoices = try jsonArrayToRuntimeObjList(jsonArray: jObject["currentChoices"]!.arrayValue).map { $0 as! Choice }
        
        // choiceThreads is optional
        let jChoiceThreadsObj = jObject["choiceThreads"]!.dictionary!
        try loadFlow(withChoiceThreadsJSON: jChoiceThreadsObj, forStory: story)
    }
    
    public func writeJSON() -> JSON {
        var output: JSON = [
            "callstack": callStack!.writeJSON(),
            "outputStream": writeListRuntimeObjs(outputStream),
        ]

        // choiceThreads: optional
        // Has to come BEFORE the choices themselves are written out
        // since the originalThreadIndex of each choice needs to be set
        var hasChoiceThreads = false
        var choiceThreads: JSON = [:]
        for c in currentChoices {
            c.originalThreadIndex = c.threadAtGeneration?.threadIndex

            if callStack?.thread(withIndex: c.originalThreadIndex!) == nil {
                choiceThreads[String(c.originalThreadIndex!)] = c.threadAtGeneration!.writeJSON()
            }

        }

        output["currentChoices"] = JSON(currentChoices.map { $0.writeJSON() })

        return output
    }
    
    // Used both to load old format and current
    public func loadFlow(withChoiceThreadsJSON jChoiceThreads: [String: JSON], forStory story: Story) throws {
        for choice in currentChoices {
            let foundActiveThread = callStack?.thread(withIndex: choice.originalThreadIndex!)
            if foundActiveThread != nil {
                choice.threadAtGeneration = foundActiveThread!.copy()
            }
            else {
                let jSavedChoiceThread = jChoiceThreads[String(describing: choice.originalThreadIndex!)]!.dictionaryValue
                choice.threadAtGeneration = try CallStack.Thread(jSavedChoiceThread, story)
            }
        }
    }
}
