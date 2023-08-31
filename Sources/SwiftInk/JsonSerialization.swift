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

public func writeListRuntimeObjs(_ list: [Object?]) -> [Any?] {
    list.map { writeRuntimeObject($0) }
}

public func writeRuntimeContainer(_ container: Container, withoutName: Bool = false) -> JSON {
    var output: [Any?] = []
    
    for c in container.content {
        output.append(writeRuntimeObject(c))
    }
    
    // Container is always an array [...]
    // But the final element is either:
    // - a dictionary containing the named content, as well as possibly
    //   the key "#" with the count flags
    // - null, if neither of the above
    let namedOnlyContent = container.namedOnlyContent
    let countFlags = container.countFlags
    let hasNameProperty = container.name != nil && !withoutName
    
    let hasTerminator = namedOnlyContent != nil || countFlags > 0 || hasNameProperty
    
    if hasTerminator {
        var terminatorObj: JSON = [:]
        
        if namedOnlyContent != nil {
            for namedContent in namedOnlyContent! {
                let name = namedContent.key
                let namedContainer = namedContent.value as! Container
                terminatorObj[name] = writeRuntimeContainer(namedContainer, withoutName: true)
            }
        }
        
        output.append(terminatorObj)
    }
    else {
        output.append(nil)
    }
    
    return JSON(output)
}

public func writeRuntimeObject(_ obj: Object?) -> JSON {
    if let container = obj as? Container {
        return writeRuntimeContainer(container)
    }
    
    if let divert = obj as? Divert {
        var divTypeKey = "->"
        if divert.isExternal {
            divTypeKey = "x()"
        }
        else if divert.pushesToStack {
            if divert.stackPushType == .function {
                divTypeKey = "f()"
            }
            else if divert.stackPushType == .tunnel {
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
        
        var outputObject = JSON()
        outputObject[divTypeKey] = JSON(targetStr!)
        
        if divert.hasVariableTarget {
            outputObject["var"] = JSON(true)
        }
        
        if divert.isConditional {
            outputObject["c"] = JSON(true)
        }
        
        if divert.externalArgs > 0 {
            outputObject["exArgs"] = JSON(divert.externalArgs)
        }
        
        return outputObject
    }
    
    if let choicePoint = obj as? ChoicePoint {
        var outputObject = JSON()
        outputObject["*"] = JSON(choicePoint.pathStringOnChoice)
        outputObject["flg"] = JSON(choicePoint.flags)
        return outputObject
    }
    
    if let boolVal = obj as? BoolValue {
        return JSON(boolVal.valueObject!)
    }
    
    if let intVal = obj as? IntValue {
        return JSON(intVal.valueObject!)
    }
    
    if let floatVal = obj as? FloatValue {
        return JSON(floatVal.valueObject!)
    }
    
    if let strVal = obj as? StringValue {
        if strVal.isNewline {
            return "\n"
        }
        else {
            return JSON("^\(strVal.value!)")
        }
    }
    
    if let listVal = obj as? ListValue {
        return writeInkList(listVal)
    }
    
    if let divTargetVal = obj as? DivertTargetValue {
        return JSON(["^->": divTargetVal.value?.componentsString])
    }
    
    if let varPtrVal = obj as? VariablePointerValue {
        return JSON(["^var": JSON(varPtrVal.value!), "ci": JSON(varPtrVal.contextIndex)])
    }
    
    if obj is Glue {
        return JSON("<>")
    }
    
    if let controlCmd = obj as? ControlCommand {
        return JSON(_controlCommandNames[controlCmd.commandType.rawValue]!)
    }
    
    if let nativeFunc = obj as? NativeFunctionCall {
        var name = nativeFunc.name
        
        // Avoid collision with ^ used to indicate a string
        if name == "^" {
            name = "L^"
        }
        
        return JSON(name)
    }
    
    if let varRef = obj as? VariableReference {
        var outputObj = JSON()
        
        if let readCountPath = varRef.pathStringForCount {
            outputObj["CNT?"] = JSON(readCountPath)
        }
        else {
            outputObj["VAR?"] = JSON(varRef.name!)
        }
        
        return outputObj
    }
    
    if let varAss = obj as? VariableAssignment {
        var outputObj = JSON()
        
        let key = varAss.isGlobal ? "VAR=" : "temp="
        outputObj[key] = JSON(varAss.variableName!)
        
        // Reassignment?
        if !varAss.isNewDeclaration {
            outputObj["re"] = JSON(true)
        }
        
        return outputObj
    }
    
    if obj is Void {
        return JSON("void")
    }
    
    if let tag = obj as? Tag {
        return JSON(["#": tag.text])
    }
    
    // Used when serializing save state only
    if let choice = obj as? Choice {
        return choice.writeJSON()
    }
    
    fatalError("Failed to write runtime object to JSON: \(String(describing: obj))")
}

func writeInkList(_ listVal: ListValue) -> JSON {
    let rawList = listVal.value
    
    var outputObj = JSON()
    
    var listStuff = JSON()
    for itemAndValue in rawList!.internalDict {
        let item = itemAndValue.key
        let itemVal = itemAndValue.value
        
        listStuff["\(item.originName ?? "?").\(item.itemName!)"] = JSON(itemVal)
    }
    
    outputObj["list"] = listStuff
    
    if rawList!.internalDict.isEmpty && rawList?.originNames != nil && !(rawList!.originNames!.isEmpty) {
        outputObj["origins"] = JSON(rawList!.originNames!)
    }
    
    return outputObj
}

func writeListRuntimeObjs(_ list: [Object]) -> JSON {
    JSON(list.map { writeRuntimeObject($0) })
}

func jsonTokenToListDefinitions(_ obj: Any?) -> ListDefinitionsOrigin {
    let defsObj = obj as! Dictionary<String, Any?>
    var allDefs: [ListDefinition] = []
    
    for kv in defsObj {
        let name = kv.key
        let listDefJson = kv.value as! Dictionary<String, Any?>
        
        // Cast (string, object) to (string, int) for items
        var items: [String: Int] = [:]
        for nameValue in listDefJson {
            items[nameValue.key] = nameValue.value as? Int
        }
        
        let def = ListDefinition(named: name, withItems: items)
        allDefs.append(def)
    }
    
    return ListDefinitionsOrigin(allDefs)
}

func jsonTokenToRuntimeObject(jsonToken: JSON) throws -> Object? {
    // Determine if it's an int or a float...
    if jsonToken.type == .number {
        
        if Int(exactly: jsonToken.floatValue) == jsonToken.int! {
            return createValue(fromAny: jsonToken.int!)
        }
        else {
            return createValue(fromAny: jsonToken.float!)
        }
    }
    else if let boolValue = jsonToken.bool {
        return createValue(fromAny: boolValue)!
    }
    
    if var strValue = jsonToken.string {
        let firstChar = strValue.first
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
            let cmdName = _controlCommandNames[i]
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
        
        if NativeFunctionCall.callExists(named: strValue) {
            return NativeFunctionCall.callFunction(named: strValue)
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
        if let p = dictValue["^->"]?.string {
            propValue = p
            return DivertTargetValue(Path(fromComponentsString: p))
        }
        
        // VariablePointerValue
        if let p = dictValue["^var"]?.string {
            let varPtr = VariablePointerValue(p)
            if let contextIndex = dictValue["ci"]?.int {
                varPtr.contextIndex = contextIndex
            }
            return varPtr
        }
        
        var isDivert = false
        var pushesToStack = false
        var divPushType = PushPopType.function
        var external = false
        if let p = dictValue["->"]?.object {
            propValue = p
            isDivert = true
        }
        else if let p = dictValue["f()"]?.object {
            propValue = p
            isDivert = true
            pushesToStack = true
            divPushType = .function
        }
        else if let p = dictValue["->t->"]?.object {
            propValue = p
            isDivert = true
            pushesToStack = true
            divPushType = .tunnel
        }
        else if let p = dictValue["x()"]?.object {
            propValue = p
            isDivert = true
            external = true
            pushesToStack = false
            divPushType = .function
        }
        if isDivert {
            let divert = Divert()
            divert.pushesToStack = pushesToStack
            divert.stackPushType = divPushType
            divert.isExternal = external
            
            let target = (propValue as? String) ?? "nil"
            
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
            let choice = ChoicePoint()
            choice.pathStringOnChoice = p
            
            if let flags = dictValue["flg"]?.int {
                choice.flags = flags
            }
            
            return choice
        }
        
        // Variable reference
        if let varRef = dictValue["VAR?"]?.object {
            return VariableReference(forVariableNamed: String(describing: varRef))
        }
        else if let pathStringForCount = dictValue["CNT?"]?.string {
            let readCountVarRef = VariableReference()
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
            let varName = propValue as! String
            let isNewDecl = !dictValue.keys.contains("re")
            let varAss = VariableAssignment(forVariableNamed: varName, isNewDeclaration: isNewDecl)
            varAss.isGlobal = isGlobalVar
            return varAss
        }
        
        // Legacy tag with text
        if let tagText = dictValue["#"]?.string {
            return Tag(text: tagText)
        }
        
        // List value
        if let listContent = dictValue["list"]?.dictionary {
            let rawList = InkList()
            if let origins = dictValue["origins"]?.array {
                rawList.setInitialOriginNames(origins.map { $0.stringValue })
            }
            for nameToVal in listContent {
                let item = InkListItem(nameToVal.key)
                let val = nameToVal.value.int
                rawList.internalDict[item] = val
            }
            return ListValue(rawList)
        }
        
        // Used when serializing save state only
        if dictValue["originalChoicePath"] != nil {
            return jsonObjectToChoice(jsonObject: dictValue)
        }
    }
    
    // Array is always a container
    if let containerArray = jsonToken.array {
        return try jsonArrayToContainer(jsonArray: containerArray)
    }
    
    if jsonToken == JSON.null {
        return nil
    }
    
    fatalError("Failed to convert token to runtime object: \(jsonToken)")
}

func jsonArrayToContainer(jsonArray: [JSON]) throws -> Container {
    let container = Container()
    try container.setContent(jsonArrayToRuntimeObjList(jsonArray: jsonArray, skipLast: true))
    
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
                let namedContentItem = try jsonTokenToRuntimeObject(jsonToken: keyVal.value)
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

func jsonArrayToRuntimeObjList(jsonArray: [JSON], skipLast: Bool = false) throws -> [Object] {
    var count = jsonArray.count
    if skipLast {
        count -= 1
    }
    
    var list: [Object] = []
    for i in 0 ..< count {
        let jTok = jsonArray[i]
        let runtimeObj = try jsonTokenToRuntimeObject(jsonToken: jTok)!
        list.append(runtimeObj)
    }
    
    return list
}

func jsonObjectToChoice(jsonObject: [String: JSON]) -> Choice {
    let choice = Choice()
    choice.text = jsonObject["text"]?.string
    choice.index = jsonObject["index"]?.int
    choice.sourcePath = jsonObject["originalChoicePath"]?.string
    choice.originalThreadIndex = jsonObject["originalThreadIndex"]?.int
    choice.pathStringOnChoice = jsonObject["targetPath"]!.string!
    return choice
}

func jsonObjectToDictionaryRuntimeObjs(jsonObject: [String: JSON]) throws -> [String: Object?] {
    var dict: [String: Object?] = [:]
    for keyVal in jsonObject {
        dict[keyVal.key] = try jsonTokenToRuntimeObject(jsonToken: keyVal.value)
    }
    return dict
}
