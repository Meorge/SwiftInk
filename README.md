# SwiftInk

**SwiftInk** is, as the name suggests, a Swift port of the runtime engine
for the [ink scripting language](https://github.com/inkle/ink) by [inkle](https://www.inklestudios.com).

**For now, it should be assumed to be unstable!**

## Documentation
Until a first version is complete, the code for SwiftInk will follow the C# engine
very closely. This means that the official [Running Your Ink](https://github.com/inkle/ink/blob/master/Documentation/RunningYourInk.md)
documentation from inkle should be easily translatable into SwiftInk's API.

### Differences from C# version
To fit Swift language conventions, SwiftInk uses `pascalCase` for method names and
enumeration cases instead of `CamelCase` as C# does.

Here's a basic "engine" for playing Ink scripts:
```swift
let story = try Story(jsonString)
while true {
    print(try story.continueMaximally())
    if !story.currentChoices.isEmpty {
        for (i, choice) in s.currentChoices.enumerated() {
            print("\(i): \(choice.text!)")
        }
        
        var playerChoice: Int? = nil
        while playerChoice == nil {
            playerChoice = Int(readLine() ?? "0")
        }
                    
        try s.ChooseChoiceIndex(playerChoice!)
    }
    else {
        print("Story complete!")
        break
    }
}
```

## License
Like the original ink engine, SwiftInk is available under the [MIT License](LICENSE.md).
