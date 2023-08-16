# SwiftInk

**SwiftInk** is, as the name suggests, a Swift port of the runtime engine
for the [ink scripting language](https://github.com/inkle/ink) by [inkle](https://www.inklestudios.com).

Currently, the goal is for it to be as close to a 1:1 port of the original
C# engine as possible - this means using the same object types, variable names,
and so on. Once the port is working, I hope to begin making the API more Swift-friendly.

**For now, it should be assumed to be unstable!**

## Porting completion status
Legend:
- ✅ - Complete
- 📝 - In progress
- ❌ - Not started

Ink runtime engine:
- 📝 `CallStack`
    - JSON functions need to be implemented
- ✅ `Choice`
- ✅ `ChoicePoint`
- 📝 `Container`
- ✅ `ControlCommand`
- ✅ `DebugMetadata`
- ❌ `Divert`
- ❌ `Error`
- ❌ `Flow`
- ✅ `Glue`
- ✅ `INamedContent` (now `Nameable`)
- ✅ `InkList`
- ❌ `JsonSerialisation`
- ❌ `ListDefinition`
- ❌ `ListDefinitionsOrigin`
- ❌ `NativeFunctionCall`
- ✅ `Object`
- 📝 `Path`
    - Various fixes need to be made
- ✅ `Pointer`
- ❌ `Profiler`
- ✅ `PushPop`
- ✅ `SearchResult`
- ❌ `SimpleJson`
- ❌ `StatePatch`
- ❌ `Story`
- 📝 `StoryException` (now `StoryError`, and with separate errors)
- ❌ `StoryState`
- ❌ `StringJoinExtension`
- ✅ `Tag`
- ✅ `Value` (specific value types now in `ValueTypes` folder)
- ✅ `VariableAssignment`
- ✅ `VariableReference`
- ❌ `VariablesState`
- ✅ `Void`


## Documentation
Until a first version is complete, the code for SwiftInk will follow the C# engine
very closely. This means that the official [Running Your Ink](https://github.com/inkle/ink/blob/master/Documentation/RunningYourInk.md)
documentation from inkle should be easily translatable into SwiftInk's API.

## License
Like the original ink engine, SwiftInk is available under the [MIT License](LICENSE.md).
