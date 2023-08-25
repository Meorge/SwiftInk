import Foundation

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
    
    public init(_ name: String, _ story: Story, _ jObject: [String: Any?]) throws {
        self.name = name
        self.callStack = CallStack(story)
        try self.callStack!.SetJsonToken(jObject["callstack"] as! [String : Any?], story)
        self.outputStream = try JArrayToRuntimeObjList(jObject["outputStream"] as! [Any?])
        self.currentChoices = try JArrayToRuntimeObjList(jObject["currentChoices"] as! [Any?]).map { $0 as! Choice }
        
        // choiceThreads is optional
        var jChoiceThreadsObj = jObject["choiceThreads"]
        try LoadFlowChoiceThreads(jChoiceThreadsObj as! Dictionary<String, Any?>, story)
    }
    
    public func WriteJson() -> [String: Any?] {
        var output: [String: Any?] = [
            "callstack": callStack?.WriteJson(),
            "outputStream": WriteListRuntimeObjs(outputStream),
        ]
        
        // choiceThreads: optional
        // Has to come BEFORE the choices themselves are written out
        // since the originalThreadIndex of each choice needs to be set
        var hasChoiceThreads = false
        var choiceThreads: [String: Any?] = [:]
        for c in currentChoices {
            c.originalThreadIndex = c.threadAtGeneration?.threadIndex
            
            if callStack?.ThreadWithIndex(c.originalThreadIndex!) == nil {
                choiceThreads[String(c.originalThreadIndex!)] = c.threadAtGeneration?.WriteJson()
            }
            
        }
        
        output["currentChoices"] = currentChoices.map { $0.WriteJson() }
        
        return output
    }
    
    // Used both to load old format and current
    public func LoadFlowChoiceThreads(_ jChoiceThreads: [String: Any?], _ story: Story) throws {
        for choice in currentChoices {
            let foundActiveThread = callStack?.ThreadWithIndex(choice.originalThreadIndex!)
            if foundActiveThread != nil {
                choice.threadAtGeneration = foundActiveThread!.Copy()
            }
            else {
                let jSavedChoiceThread = jChoiceThreads[String(describing: choice.originalThreadIndex!)] as! Dictionary<String, Any?>
                choice.threadAtGeneration = try CallStack.Thread(jSavedChoiceThread, story)
            }
        }
    }
}
