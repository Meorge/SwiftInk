//
//  File.swift
//  
//
//  Created by Malcolm Anderson on 8/24/23.
//

import Foundation
import SwiftyJSON

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

func JTokenToRuntimeObject(jsonToken: JSON) throws -> Object? {
    // Determine if it's an int or a float...
    if jsonToken.type == .number {
        
        if Int(exactly: jsonToken.floatValue) == jsonToken.int! {
            return CreateValue(jsonToken.int!)
        }
        else {
            return CreateValue(jsonToken.float!)
        }
    }
    else if let boolValue = jsonToken.bool {
        return CreateValue(boolValue)!
    }
    
    if var strValue = jsonToken.string {
        var firstChar = strValue.first
        if firstChar == Character("^") {
            strValue.remove(at: strValue.startIndex)
            return StringValue(strValue)
        }
        else if firstChar == Character("\n") && strValue.count == 1 {
            return StringValue("\n")
        }
        
        // Glue
        if strValue == "<>" {
            return Glue()
        }
        
        // Control commands (would looking up in a hash set be faster?)
        for i in 0 ..< _controlCommandNames.count {
            var cmdName = _controlCommandNames[i]
            if strValue == cmdName {
                return ControlCommand(ControlCommand.CommandType(rawValue: i)!)
            }
        }
        
        // Native functions
        // "^" conflictswith the way to identify strings, so now
        // we know it's not a string, we can convert back to the proper
        // symbol for the operator.
        if strValue == "L^" {
            strValue = "^"
        }
        
        if NativeFunctionCall.CallExistsWithName(strValue) {
            return NativeFunctionCall.CallWithName(strValue)
        }
        
        // Pop
        if strValue == "->->" {
            return ControlCommand(.popTunnel)
        }
        else if strValue == "~ret" {
            return ControlCommand(.popFunction)
        }
        
        // Void
        if strValue == "void" {
            return Void()
        }
    }
    
    if let dictValue = jsonToken.dictionary {
        var propValue: Any? = nil
        
        // Divert target value to path
        if var p = dictValue["^->"]?.string {
            propValue = p
            return DivertTargetValue(Path(p))
        }
        
        // VariablePointerValue
        if var p = dictValue["^var"]?.string {
            var varPtr = VariablePointerValue(p)
            if var contextIndex = dictValue["ci"]?.int {
                varPtr.contextIndex = contextIndex
            }
            return varPtr
        }
        
        var isDivert = false
        var pushesToStack = false
        var divPushType = PushPopType.Function
        var external = false
        if var p = dictValue["->"]?.object {
            propValue = p
            isDivert = true
        }
        else if var p = dictValue["f()"]?.object {
            propValue = p
            isDivert = true
            pushesToStack = true
            divPushType = .Function
        }
        else if var p = dictValue["->t->"]?.object {
            propValue = p
            isDivert = true
            pushesToStack = true
            divPushType = .Tunnel
        }
        else if var p = dictValue["x()"]?.object {
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
            
            var target = (propValue as? String) ?? "nil"
            
            if let p = dictValue["var"]?.object {
                propValue = p
                divert.variableDivertName = target
            }
            else {
                divert.targetPathString = target
            }
            
            if let p = dictValue["c"]?.object {
                propValue = p
                divert.isConditional = true
            }
            else {
                divert.isConditional = false
            }
            
            if external {
                if let p = dictValue["exArgs"]?.int {
                    divert.externalArgs = p
                }
            }
            
            return divert
        }
        
        // Choice
        if let p = dictValue["*"]?.string {
            propValue = p
            var choice = ChoicePoint()
            choice.pathStringOnChoice = p
            
            if let flags = dictValue["flg"]?.int {
                choice.flags = flags
            }
            
            return choice
        }
        
        // Variable reference
        if let varRef = dictValue["VAR?"]?.object {
            return VariableReference(String(describing: varRef))
        }
        else if let pathStringForCount = dictValue["CNT?"]?.string {
            var readCountVarRef = VariableReference()
            readCountVarRef.pathStringForCount = String(describing: pathStringForCount)
            return readCountVarRef
        }
        
        // Variable assignment
        var isVarAss = false
        var isGlobalVar = false
        if let globalVarVal = dictValue["VAR="]?.object {
            propValue = globalVarVal
            isVarAss = true
            isGlobalVar = true
        }
        else if let tempVarVal = dictValue["temp="]?.object {
            propValue = tempVarVal
            isVarAss = true
            isGlobalVar = false
        }
        
        if isVarAss {
            var varName = propValue as! String
            var isNewDecl = !dictValue.keys.contains("re")
            var varAss = VariableAssignment(varName, isNewDecl)
            varAss.isGlobal = isGlobalVar
            return varAss
        }
        
        // Legacy tag with text
        if let tagText = dictValue["#"]?.string {
            return Tag(text: tagText)
        }
        
        // List value
        if let listContent = dictValue["list"]?.dictionary {
            var rawList = InkList()
            if let origins = dictValue["origins"]?.array {
                rawList.SetInitialOriginNames(origins.map { $0.stringValue })
            }
            for nameToVal in listContent {
                var item = InkListItem(nameToVal.key)
                var val = nameToVal.value.int
                rawList.internalDict[item] = val
            }
            return ListValue(rawList)
        }
        
        // Used when serializing save state only
        if dictValue["originalChoicePath"] != nil {
            return JObjectToChoice(jsonObject: dictValue)
        }
    }
    
    // Array is always a container
    if let containerArray = jsonToken.array {
        return try JArrayToContainer(jsonArray: containerArray)
    }
    
    if jsonToken == JSON.null {
        return nil
    }
    
    fatalError("Failed to convert token to runtime object: \(jsonToken)")
}

func JArrayToContainer(jsonArray: [JSON]) throws -> Container {
    var container = Container()
    try container.SetContent(JArrayToRuntimeObjList(jsonArray: jsonArray, skipLast: true))
    
    // Final object in the array is always a combination of
    // - named content
    // - a "#f" key with the countFlags
    // (if either exists at all, otherwise null)
    if let terminatingObj = jsonArray.last?.dictionary {
        var namedOnlyContent: [String: Object] = [:]
        for keyVal in terminatingObj {
            if keyVal.key == "#f" {
                container.countFlags = keyVal.value.intValue
            }
            else if keyVal.key == "#n" {
                container.name = keyVal.value.stringValue
            }
            else {
                var namedContentItem = try JTokenToRuntimeObject(jsonToken: keyVal.value)
                if let namedSubContainer = namedContentItem as? Container {
                    namedSubContainer.name = keyVal.key
                }
                namedOnlyContent[keyVal.key] = namedContentItem
            }
        }
        
        container.namedOnlyContent = namedOnlyContent
    }
    
    return container
}

func JArrayToRuntimeObjList(jsonArray: [JSON], skipLast: Bool = false) throws -> [Object] {
    var count = jsonArray.count
    if skipLast {
        count -= 1
    }
    
    var list: [Object] = []
    for i in 0 ..< count {
        var jTok = jsonArray[i]
        var runtimeObj = try JTokenToRuntimeObject(jsonToken: jTok)!
        list.append(runtimeObj)
    }
    
    return list
}

func JObjectToChoice(jsonObject: [String: JSON]) -> Choice {
    var choice = Choice()
    choice.text = jsonObject["text"]?.string
    choice.index = jsonObject["index"]?.int
    choice.sourcePath = jsonObject["originalChoicePath"]?.string
    choice.originalThreadIndex = jsonObject["originalThreadIndex"]?.int
    choice.pathStringOnChoice = jsonObject["targetPath"]!.string!
    return choice
}

func JObjectToDictionaryRuntimeObjs(jsonObject: [String: JSON]) throws -> [String: Object?] {
    var dict: [String: Object?] = [:]
    for keyVal in jsonObject {
        dict[keyVal.key] = try JTokenToRuntimeObject(jsonToken: keyVal.value)
    }
    return dict
}
