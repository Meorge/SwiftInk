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
    
    public init(_ name: String, _ story: Story, _ jObject: [String: Any?]) {
        self.name = name
        self.callStack = CallStack(story)
        self.callStack!.SetJsonToken(jObject["callstack"] as! Dictionary<String, Any?>, story)
        self.outputStream = Json.JArrayToRuntimeObjList(jObject["outputStream"] as! Array<Any?>)
        self.currentChoices = Json.JArrayToRuntimeObjList<Choice>(jObject["currentChoices"] as! Array<Any?>)
        
        // choiceThreads is optional
        var jChoiceThreadsObj = jObject["choiceThreads"]
        LoadFlowChoiceThreads(jChoiceThreadsObj as! Dictionary<String, Any?>, story)
    }
    
    // TODO: WriteJson()
    
    // Used both to load old format and current
    public func LoadFlowChoiceThreads(_ jChoiceThreads: [String: Any?], _ story: Story) throws {
        for choice in currentChoices {
            var foundActiveThread = callStack?.ThreadWithIndex(choice.originalThreadIndex!)
            if foundActiveThread != nil {
                choice.threadAtGeneration = foundActiveThread!.Copy()
            }
            else {
                var jSavedChoiceThread = jChoiceThreads[String(describing: choice.originalThreadIndex!)] as! Dictionary<String, Any?>
                choice.threadAtGeneration = try CallStack.Thread(jSavedChoiceThread, story)
            }
        }
    }
}
