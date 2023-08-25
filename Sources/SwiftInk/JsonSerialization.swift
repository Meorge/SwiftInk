//
//  File.swift
//  
//
//  Created by Malcolm Anderson on 8/24/23.
//

import Foundation

let _controlCommandNames: [Int: String] = [
    ControlCommand.CommandType.evalStart.rawValue: "ev",
    ControlCommand.CommandType.evalOutput.rawValue: "out",
    ControlCommand.CommandType.evalEnd.rawValue: "/ev",
    ControlCommand.CommandType.duplicate.rawValue: "du",
    ControlCommand.CommandType.popEvaluatedValue.rawValue: "pop",
    ControlCommand.CommandType.popFunction.rawValue: "~ret",
    ControlCommand.CommandType.popTunnel.rawValue: "->->",
    ControlCommand.CommandType.beginString.rawValue: "str",
    ControlCommand.CommandType.endString.rawValue: "/str",
    ControlCommand.CommandType.noOp.rawValue: "nop",
    ControlCommand.CommandType.choiceCount.rawValue: "choiceCnt",
    ControlCommand.CommandType.turns.rawValue: "turn",
    ControlCommand.CommandType.turnsSince.rawValue: "turns",
    ControlCommand.CommandType.readCount.rawValue: "readc",
    ControlCommand.CommandType.random.rawValue: "rnd",
    ControlCommand.CommandType.seedRandom.rawValue: "srnd",
    ControlCommand.CommandType.visitIndex.rawValue: "visit",
    ControlCommand.CommandType.sequenceShuffleIndex.rawValue: "seq",
    ControlCommand.CommandType.startThread.rawValue: "thread",
    ControlCommand.CommandType.done.rawValue: "done",
    ControlCommand.CommandType.end.rawValue: "end",
    ControlCommand.CommandType.listFromInt.rawValue: "listInt",
    ControlCommand.CommandType.listRange.rawValue: "range",
    ControlCommand.CommandType.listRandom.rawValue: "lrnd",
    ControlCommand.CommandType.beginTag.rawValue: "#",
    ControlCommand.CommandType.endTag.rawValue: "/#"
]

public func WriteListRuntimeObjs(_ list: [Object?]) -> [Any?] {
    list.map { WriteRuntimeObject($0) }
}

public func WriteRuntimeContainer(_ container: Container, withoutName: Bool = false) -> [Any?] {
    var output: [Any?] = []
    
    for c in container.content {
        output.append(WriteRuntimeObject(c))
    }
    
    // Container is always an array [...]
    // But the final element is either:
    // - a dictionary containing the named content, as well as possibly
    //   the key "#" with the count flags
    // - null, if neither of the above
    var namedOnlyContent = container.namedOnlyContent
    var countFlags = container.countFlags
    var hasNameProperty = container.name != nil && !withoutName
    
    var hasTerminator = namedOnlyContent != nil || countFlags > 0 || hasNameProperty
    
    if hasTerminator {
        var terminatorObj: [String: Any?] = [:]
        
        if namedOnlyContent != nil {
            for namedContent in namedOnlyContent! {
                var name = namedContent.key
                var namedContainer = namedContent.value as! Container
                terminatorObj[name] = WriteRuntimeContainer(namedContainer, withoutName: true)
            }
        }
        
        output.append(terminatorObj)
    }
    else {
        output.append(nil)
    }
    
    return output
}

public func WriteRuntimeObject(_ obj: Object?) -> Any? {
    if let container = obj as? Container {
        return WriteRuntimeContainer(container)
    }
    
    if let divert = obj as? Divert {
        var divTypeKey = "->"
        if divert.isExternal {
            divTypeKey = "x()"
        }
        else if divert.pushesToStack {
            if divert.stackPushType == .Function {
                divTypeKey = "f()"
            }
            else if divert.stackPushType == .Tunnel {
                divTypeKey = "->t->"
            }
        }
        
        var targetStr: String?
        if divert.hasVariableTarget {
            targetStr = divert.variableDivertName
        }
        else {
            targetStr = divert.targetPathString
        }
        
        var outputObject: [String: Any?] = [:]
        outputObject[divTypeKey] = targetStr
        
        if divert.hasVariableTarget {
            outputObject["var"] = true
        }
        
        if divert.isConditional {
            outputObject["c"] = true
        }
        
        if divert.externalArgs > 0 {
            outputObject["exArgs"] = divert.externalArgs
        }
        
        return outputObject
    }
    
    if let choicePoint = obj as? ChoicePoint {
        var outputObject: [String: Any?] = [:]
        outputObject["*"] = choicePoint.pathStringOnChoice
        outputObject["flg"] = choicePoint.flags
        return outputObject
    }
    
    if let boolVal = obj as? BoolValue {
        return boolVal.valueObject
    }
    
    if let intVal = obj as? IntValue {
        return intVal.valueObject
    }
    
    if let floatVal = obj as? FloatValue {
        return floatVal.valueObject
    }
    
    if let strVal = obj as? StringValue {
        if strVal.isNewline {
            return "\n"
        }
        else {
            return "^\(strVal.value)"
        }
    }
    
    if let listVal = obj as? ListValue {
        return WriteInkList(listVal)
    }
    
    if let divTargetVal = obj as? DivertTargetValue {
        return ["^->": divTargetVal.value?.componentsString]
    }
    
    if let varPtrVal = obj as? VariablePointerValue {
        return ["^var": varPtrVal.value, "ci": varPtrVal.contextIndex]
    }
    
    if let glue = obj as? Glue {
        return "<>"
    }
    
    if let controlCmd = obj as? ControlCommand {
        return _controlCommandNames[controlCmd.commandType.rawValue]
    }
    
    if let nativeFunc = obj as? NativeFunctionCall {
        var name = nativeFunc.name
        
        // Avoid collision with ^ used to indicate a string
        if name == "^" {
            name = "L^"
        }
        
        return name
    }
    
    if let varRef = obj as? VariableReference {
        var outputObj: [String: Any?] = [:]
        
        if let readCountPath = varRef.pathStringForCount {
            outputObj["CNT?"] = readCountPath
        }
        else {
            outputObj["VAR?"] = varRef.name
        }
        
        return outputObj
    }
    
    if let varAss = obj as? VariableAssignment {
        var outputObj: [String: Any?] = [:]
        
        var key = varAss.isGlobal ? "VAR=" : "temp="
        outputObj[key] = varAss.variableName
        
        // Reassignment?
        if !varAss.isNewDeclaration {
            outputObj["re"] = true
        }
        
        return outputObj
    }
    
    if let voidObj = obj as? Void {
        return "void"
    }
    
    if let tag = obj as? Tag {
        return ["#": tag.text]
    }
    
    // Used when serializing save state only
    if let choice = obj as? Choice {
        return choice.WriteJson()
    }
    
    fatalError("Failed to write runtime object to JSON: \(obj)")
    return nil
}

func WriteInkList(_ listVal: ListValue) -> [String: Any?] {
    var rawList = listVal.value
    
    var outputObj: [String: Any?] = [:]
    
    var listStuff: [String: Any?] = [:]
    for itemAndValue in rawList!.internalDict {
        var item = itemAndValue.key
        var itemVal = itemAndValue.value
        
        listStuff["\(item.originName ?? "?").\(item.itemName!)"] = itemVal
    }
    
    outputObj["list"] = listStuff
    
    if rawList!.internalDict.isEmpty && rawList?.originNames != nil && !(rawList!.originNames!.isEmpty) {
        outputObj["origins"] = rawList?.originNames!
    }
    
    return outputObj
}

func WriteListRuntimeObjs(_ list: [Object]) -> [Any?] {
    list.map { WriteRuntimeObject($0) }
}

func JTokenToListDefinitions(_ obj: Any?) -> ListDefinitionsOrigin {
    var defsObj = obj as! Dictionary<String, Any?>
    var allDefs: [ListDefinition] = []
    
    for kv in defsObj {
        var name = kv.key
        var listDefJson = kv.value as! Dictionary<String, Any?>
        
        // Cast (string, object) to (string, int) for items
        var items: [String: Int] = [:]
        for nameValue in listDefJson {
            items[nameValue.key] = nameValue.value as? Int
        }
        
        var def = ListDefinition(name, items)
        allDefs.append(def)
    }
    
    return ListDefinitionsOrigin(allDefs)
}

func JTokenToRuntimeObject(_ token: Any?) throws -> Object? {
    if token is Int || token is Float || token is Bool {
        return CreateValue(token) as! Object
    }
    
    if var str = token as? String {
        var firstChar = str.first
        if firstChar == Character("^") {
            str.remove(at: str.startIndex)
            return StringValue(str)
        }
        else if firstChar == Character("\n") && str.count == 1 {
            return StringValue("\n")
        }
        
        // Glue
        if str == "<>" {
            return Glue()
        }
        
        // Control commands (would looking up in a hash set be faster?)
        for i in 0 ..< _controlCommandNames.count {
            var cmdName = _controlCommandNames[i]
            if str == cmdName {
                return ControlCommand(ControlCommand.CommandType(rawValue: i)!)
            }
        }
        
        // Native functions
        // "^" conflictswith the way to identify strings, so now
        // we know it's not a string, we can convert back to the proper
        // symbol for the operator.
        if str == "L^" {
            str = "^"
        }
        
        if NativeFunctionCall.CallExistsWithName(str) {
            return NativeFunctionCall.CallWithName(str)
        }
        
        // Pop
        if str == "->->" {
            return ControlCommand(.popTunnel)
        }
        else if str == "~ret" {
            return ControlCommand(.popFunction)
        }
        
        // Void
        if str == "void" {
            return Void()
        }
    }
    
    if let obj = token as? Dictionary<String, Any?> {
        var propValue: Any? = nil
        // Divert target value to path
        if var p = obj["^->"] {
            propValue = p
            return DivertTargetValue(Path(propValue as! String))
        }
        
        // VariablePointerValue
        if var p = obj["^var"] {
            propValue = p
            var varPtr = VariablePointerValue(propValue as! String)
            if var propValue = obj["ci"] {
                varPtr.contextIndex = propValue as! Int
            }
            return varPtr
        }
        
        // Divert
        var isDivert = false
        var pushesToStack = false
        var divPushType = PushPopType.Function
        var external = false
        if var p = obj["->"] {
            propValue = p
            isDivert = true
        }
        else if var p = obj["f()"] {
            propValue = p
            isDivert = true
            pushesToStack = true
            divPushType = .Function
        }
        else if var p = obj["->t->"] {
            propValue = p
            isDivert = true
            pushesToStack = true
            divPushType = .Tunnel
        }
        else if var p = obj["x()"] {
            propValue = p
            isDivert = true
            external = true
            pushesToStack = false
            divPushType = .Function
        }
        
        if isDivert {
            var divert = Divert()
            divert.pushesToStack = pushesToStack
            divert.stackPushType = divPushType
            divert.isExternal = external
            
            var target = String(describing: propValue)
            
            if let p = obj["var"] {
                propValue = p
                divert.variableDivertName = target
            }
            else {
                divert.targetPathString = target
            }
            
            if let p = obj["c"] {
                propValue = p
                divert.isConditional = true
            }
            else {
                divert.isConditional = false
            }
            
            if external {
                if let p = obj["exArgs"] {
                    divert.externalArgs = p as! Int
                }
            }
        }
        
        if let p = obj["*"] {
            propValue = p
            var choice = ChoicePoint()
            choice.pathStringOnChoice = String(describing: propValue)
            
            if let p = obj["flg"] {
                choice.flags = propValue as! Int
            }
            
            return choice
        }
        
        // Variable reference
        if let p = obj["VAR?"] {
            return VariableReference(String(describing: p))
        }
        else if let p = obj["CNT?"] {
            var readCountVarRef = VariableReference()
            readCountVarRef.pathStringForCount = String(describing: p)
            return readCountVarRef
        }
        
        // Variable assignment
        var isVarAss = false
        var isGlobalVar = false
        if let p = obj["VAR="] {
            propValue = p
            isVarAss = true
            isGlobalVar = true
        }
        else if let p = obj["temp="] {
            propValue = p
            isVarAss = true
            isGlobalVar = false
        }
        
        if isVarAss {
            var varName = String(describing: propValue)
            var isNewDecl = !obj.keys.contains("re")
            var varAss = VariableAssignment(varName, isNewDecl)
            varAss.isGlobal = isGlobalVar
            return varAss
        }
        
        // Legacy tag with text
        if let p = obj["#"] {
            propValue = p
            return Tag(text: propValue as! String)
        }
        
        // List value
        if let p = obj["list"] {
            propValue = p
            var listContent = propValue as! Dictionary<String, Any?>
            var rawList = InkList()
            if let p = obj["origins"] {
                propValue = p
                var namesAsObj = propValue as! [Any?]
                rawList.SetInitialOriginNames(namesAsObj.map { $0 as! String })
            }
            for nameToVal in listContent {
                var item = InkListItem(nameToVal.key)
                var val = nameToVal.value as! Int
                rawList.internalDict[item] = val
            }
            return ListValue(rawList)
        }
        
        // Used when serializing save state only
        if obj["originalChoicePath"] != nil {
            return JObjectToChoice(obj)
        }
    }
    
    // Array is always a Container
    if let containerArray = token as? [Any?] {
        return try JArrayToContainer(containerArray)
    }
    
    if token == nil {
        return nil
    }
    
    fatalError("Failed to convert token to runtime object: \(token)")
}

func JArrayToContainer(_ jArray: [Any?]) throws -> Container {
    var container = Container()
    try container.SetContent(JArrayToRuntimeObjList(jArray, skipLast: true))
    
    // Final object in the array is always a combination of
    // - named content
    // - a "#f" key with the countFlags
    // (if either exists at all, otherwise null)
    if var terminatingObj = jArray.last as? Dictionary<String, Any?> {
        var namedOnlyContent: [String: Object] = [:]
        for keyVal in terminatingObj {
            if keyVal.key == "#f" {
                container.countFlags = keyVal.value as! Int
            }
            else if keyVal.key == "#n" {
                container.name = keyVal.value as! String
            }
            else {
                var namedContentItem = try JTokenToRuntimeObject(keyVal.value)
                if var namedSubContainer = namedContentItem as? Container {
                    namedSubContainer.name = keyVal.key
                }
                namedOnlyContent[keyVal.key] = namedContentItem
            }
        }
        
        container.namedOnlyContent = namedOnlyContent
    }
    
    return container
}

func JArrayToRuntimeObjList(_ jArray: [Any?], skipLast: Bool = false) throws -> [Object] {
    var count = jArray.count
    if skipLast {
        count -= 1
    }
    
    var list: [Object] = []
    for i in 0 ..< count {
        var jTok = jArray[i]
        var runtimeObj = try JTokenToRuntimeObject(jTok)!
        list.append(runtimeObj)
    }
    
    return list
}

func JObjectToChoice(_ jObj: [String: Any?]) -> Choice {
    var choice = Choice()
    choice.text = jObj["text"]! as? String
    choice.index = jObj["index"] as? Int
    choice.sourcePath = jObj["originalChoicePath"] as? String
    choice.originalThreadIndex = jObj["originalThreadIndex"] as? Int
    choice.pathStringOnChoice = jObj["targetPath"] as! String
    return choice
}

func JObjectToDictionaryRuntimeObjs(_ jObject: [String: Any?]) throws -> [String: Object?] {
    var dict: [String: Object?] = [:]
    for keyVal in jObject {
        dict[keyVal.key] = try JTokenToRuntimeObject(keyVal.value)
    }
    
    return dict
}

func TextToDictionary(_ jsonString: String) throws -> [String: Any?]? {
    if let data = jsonString.data(using: .utf8) {
        return try JSONSerialization.jsonObject(with: data) as? [String: Any?]
    }
    return nil
}
