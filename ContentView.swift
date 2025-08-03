import SwiftUI


class ViewModel: ObservableObject {
    @Published  var mutableAString: NSMutableAttributedString
    @Published var userSelectedRange: NSRange
    
    init() {
        let string = ""
        self.mutableAString = NSMutableAttributedString(string: string)
        self.userSelectedRange = NSRange(location: 0, length: string.count)
        
        mutableAString.setAttributes([NSMutableAttributedString.Key.font: UIFont.systemFont(ofSize: 72.0), NSMutableAttributedString.Key.foregroundColor: UIColor.green], range: NSRange(location: 0, length: string.count))
    }
    
    func updateStringTest(input: String) -> Void {
        let newAttributedString = NSMutableAttributedString(string: input)
        let oldString = self.mutableAString.string
        let newString = input
        
        // Build a character-level attribute map from the old string
        var characterAttributes: [[NSAttributedString.Key: Any]] = []
        for i in 0..<oldString.count {
            let attributes = self.mutableAString.attributes(at: i, effectiveRange: nil)
            characterAttributes.append(attributes)
        }
        
        // Find the edit position by comparing old and new strings
        let editInfo = findEditPosition(oldString: oldString, newString: newString)
        
        // Apply attributes to the new string based on the edit type
        applyAttributesToNewString(
            newAttributedString: newAttributedString,
            characterAttributes: characterAttributes,
            editInfo: editInfo
        )
        
        // Trigger the View redraw
        self.mutableAString = newAttributedString
        fetchAttribsAtLocation(location: self.userSelectedRange.location, attributedString: self.mutableAString)
    }
    
    func updateSelectedRange(inputRange: NSRange) -> Void {
        self.userSelectedRange = inputRange
    }
    
    /*
     Returns typingAttributes that should be applied in UITextView, based on relevant attributes of self.mutableAString. This will ensure that if new text is typed in the middle of already-formatted text, then that new text will inherit the attributes of the text that it is in the middle of.
     
     Attributes will only be returned if the text at self.userSelectedRange actually applies any attributes (other than the default).
     */
    func provideTypingAttributes() -> Void {
        
    }
    
    func bold() -> Void {
        let copyString = self.mutableAString
        // Save the existing attributes of the String being bolded.
        let copyStringAttributes = extractAttribsWithRanges(attributedString: copyString)
        
        // Create a brand new String to bold. If this completely new string isn't created from copyString, the view does not refresh. I think this is because copyString is a reference type, so assigning a new referece to nsAttributedString isn't enough to trigger a view refresh.
        let newAttributedString = NSMutableAttributedString(string: copyString.string)
        
        // Iterate over the existing attributes of the String whose part is being bolded, and 're-add' them to the new String.
        for attrib in copyStringAttributes {
            newAttributedString.addAttributes(attrib.0, range: attrib.1)
        }
        
        // Add the bold attribute to the new String.
        newAttributedString.addAttributes([NSMutableAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 72.0)], range: self.userSelectedRange)
        
        // Assign the new String to self.mutableAString to trigger a View re-draw.
        self.mutableAString = newAttributedString
        
    }
}

struct AttributedStringView: UIViewRepresentable {
    //TODO: think we might need to add a separate line for mutableAString here
    var viewModel: ViewModel
    // THIS IS THE CHANGE THAT BREAKS THE CURSOR 
    @Binding var mutableAString: NSMutableAttributedString
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    func makeUIView(context: Context) -> UITextView {
        let uiTextView = UITextView()
        // THIS IS THE CHANGE THAT BREAKS THE CURSOR 
        uiTextView.attributedText = mutableAString
        uiTextView.delegate = context.coordinator
        uiTextView.backgroundColor = .white
        
        let typingAttributes = [NSMutableAttributedString.Key.font: UIFont.systemFont(ofSize: 72.0)]
        uiTextView.typingAttributes = typingAttributes
        
//        var rangePts = NSRange(location: 0, length: mutableAString.length)
//        print("typing attribts in makeUIView before setting: \(uiTextView.typingAttributes)")
//        uiTextView.typingAttributes = mutableAString.attributes(at: 0, effectiveRange: &rangePts)
        print("typing attribts in makeUIView after setting: \(uiTextView.typingAttributes)")

        
        return uiTextView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        //        print("updateUIView called \(Date.now.timeIntervalSince1970)")
        let range = uiView.selectedRange
        let offset = uiView.contentOffset

        print("inside updateUIView")
        if uiView.attributedText != viewModel.mutableAString {
            uiView.attributedText = viewModel.mutableAString
            uiView.selectedRange = range
            uiView.setContentOffset(offset, animated: false) // Restore scroll position
        }
    }
}

class Coordinator: NSObject, UITextViewDelegate {
    var viewModel: ViewModel
    
    @State var originalRange = NSRange(location: 0, length: 0)
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }
    
    func textViewDidChange(_ textView: UITextView) {
        //        print("textViewDidChange before viewModel.updateString at \(Date.now.timeIntervalSince1970)")
//        viewModel.updateString(input: textView.text)
        print("inside textViewDidChange")
        viewModel.updateStringTest(input: textView.text)
        self.originalRange = textView.selectedRange
                //        print("textViewDidChange after viewModel.updateString at \(Date.now.timeIntervalSince1970)")
    }
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        //        print("textViewDidChangeSelection to -location:\(textView.selectedRange.location) -length:\(textView.selectedRange.length) at \(Date.now.timeIntervalSince1970)")
        viewModel.updateSelectedRange(inputRange: textView.selectedRange)
    }
}

struct ContentView: View {
    @ObservedObject var vm = ViewModel()
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    print("bolding")
                    vm.bold()
                }, label: {
                    Text("Booooold")
                })
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(20.0)
            
            VStack {
                AttributedStringView(viewModel: vm, mutableAString: $vm.mutableAString)
                    .frame(height: 400)
                    .border(.green)
                Text("This is the the backend of the text you typed above: ")
                    .bold()
                    .font(.largeTitle)
                    .padding(20.0)
                Text("\(vm.mutableAString.string)")
                    .font(.largeTitle)
                
                Text("This is the selected range in the ViewModel: ")
                    .bold()
                    .font(.largeTitle)
                    .padding(20.0)
                Text("location: \(vm.userSelectedRange.location), length: \(vm.userSelectedRange.length)")
                    .font(.largeTitle)
                
            }
            .onAppear(perform: {
                print("View redrawn")
            })
        }
    }
}

// MARK: HELPER FUNCTIONS

/*
 Extract the attributes of an NSAttributedString, together with the NSRange to which each attribute applies. Returns a list of tuples of (1) lists of attributes and (2) ranges to which these attributes/lists apply.
 */

func extractAttribsWithRanges(attributedString: NSAttributedString) -> [([NSAttributedString.Key:Any], NSRange)] {
    // Crete array to hold list of attributes and their rnages
    var attributesArray: [(attributes: [NSAttributedString.Key: Any], range: NSRange)] = []
    
    // Extract attributes and corresponding ranges from the input NSAttributedString
    attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: []) {attributes, range, _ in
        for (key, value) in attributes {
            attributesArray.append(([key:value], range))
        }
    }
    
    return attributesArray
}


// Helper function to find the new range of a substring after text modifications
func findNewRange(of substring: String, in newText: String, near oldLocation: Int) -> NSRange? {
    let nsNewText = newText as NSString
    
    // Ensure oldLocation is within valid bounds
    let safeOldLocation = min(max(0, oldLocation), newText.count)
    
    // Define a valid search range, ensuring we don't exceed newText bounds
    let searchStart = max(0, safeOldLocation - 5)
    let searchEnd = min(newText.count, safeOldLocation + substring.count + 5)
    
    let searchRange = NSRange(location: searchStart, length: searchEnd - searchStart)
    
    // Attempt to find the new location of the substring
    let newLocation = nsNewText.range(of: substring, options: [], range: searchRange).toOptional()
    
    // Ensure we return a valid range only if the substring was found
    guard let foundRange = newLocation else { return nil }
    
    return NSRange(location: foundRange.location, length: substring.count)
}

// Extension to safely convert NSRange to optional values
extension NSRange {
    func toOptional() -> NSRange? {
        return location != NSNotFound ? self : nil
    }
}

// Func that returns all the attributes applied at hte specified location
func fetchAttribsAtLocation(location: Int, attributedString: NSAttributedString) -> [NSAttributedString.Key: Any] {
//    print("inside fetchAttribsAtLocation for location: \(location), attributedString: \(attributedString)")
//    var rangePointer = NSRange(location: location, length: 1)
//    print("rangePointer: \(rangePointer.location), \(rangePointer.length)")   
//    
//    // retrieve attributes
//    let attributes = attributedString.attributes(at: 0, effectiveRange: nil)
//    print("attributes.count: \(attributes.count)")
//    
//    // iterate each attribute
//    for attr in attributes {
//        print("key: \(attr.key), val: \(attr.value))")
//    }
    return [:]
}

// MARK: helper funcs and structs
// Helper struct to describe what kind of edit happened
struct EditInfo {
    let editPosition: Int
    let insertedLength: Int
    let deletedLength: Int
    let editType: EditType
    
    enum EditType {
        case insertion
        case deletion
        case replacement
        case unknown
    }
}

// Find where the edit happened and what type it was
func findEditPosition(oldString: String, newString: String) -> EditInfo {
    let oldChars = Array(oldString)
    let newChars = Array(newString)
    
    // Find the first position where strings differ
    var diffStart = 0
    let minLength = min(oldChars.count, newChars.count)
    
    while diffStart < minLength && oldChars[diffStart] == newChars[diffStart] {
        diffStart += 1
    }
    
    // Find the last position where strings differ (working backwards)
    var oldEnd = oldChars.count - 1
    var newEnd = newChars.count - 1
    
    while oldEnd >= diffStart && newEnd >= diffStart && oldChars[oldEnd] == newChars[newEnd] {
        oldEnd -= 1
        newEnd -= 1
    }
    
    let deletedLength = oldEnd - diffStart + 1
    let insertedLength = newEnd - diffStart + 1
    
    let editType: EditInfo.EditType
    if deletedLength == 0 && insertedLength > 0 {
        editType = .insertion
    } else if deletedLength > 0 && insertedLength == 0 {
        editType = .deletion
    } else if deletedLength > 0 && insertedLength > 0 {
        editType = .replacement
    } else {
        editType = .unknown
    }
    
    return EditInfo(
        editPosition: diffStart,
        insertedLength: insertedLength,
        deletedLength: deletedLength,
        editType: editType
    )
}

// Apply attributes to the new string based on the edit that occurred
func applyAttributesToNewString(
    newAttributedString: NSMutableAttributedString,
    characterAttributes: [[NSAttributedString.Key: Any]],
    editInfo: EditInfo
) {
    let newLength = newAttributedString.length
    
    for i in 0..<newLength {
        var attributesToApply: [NSAttributedString.Key: Any] = [:]
        
        switch editInfo.editType {
        case .insertion:
            if i < editInfo.editPosition {
                // Before insertion: use original attributes
                attributesToApply = characterAttributes[i]
            } else if i < editInfo.editPosition + editInfo.insertedLength {
                // At insertion point: inherit attributes from the character just before
                let inheritIndex = max(0, editInfo.editPosition - 1)
                if inheritIndex < characterAttributes.count {
                    attributesToApply = characterAttributes[inheritIndex]
                }
            } else {
                // After insertion: use original attributes, shifted back
                let originalIndex = i - editInfo.insertedLength
                if originalIndex < characterAttributes.count {
                    attributesToApply = characterAttributes[originalIndex]
                }
            }
            
        case .deletion:
            if i < editInfo.editPosition {
                // Before deletion: use original attributes
                attributesToApply = characterAttributes[i]
            } else {
                // After deletion: use original attributes, shifted forward
                let originalIndex = i + editInfo.deletedLength
                if originalIndex < characterAttributes.count {
                    attributesToApply = characterAttributes[originalIndex]
                }
            }
            
        case .replacement:
            if i < editInfo.editPosition {
                // Before replacement: use original attributes
                attributesToApply = characterAttributes[i]
            } else if i < editInfo.editPosition + editInfo.insertedLength {
                // At replacement point: inherit from character before replacement
                let inheritIndex = max(0, editInfo.editPosition - 1)
                if inheritIndex < characterAttributes.count {
                    attributesToApply = characterAttributes[inheritIndex]
                }
            } else {
                // After replacement: use original attributes, accounting for length change
                let originalIndex = i - editInfo.insertedLength + editInfo.deletedLength
                if originalIndex < characterAttributes.count {
                    attributesToApply = characterAttributes[originalIndex]
                }
            }
            
        case .unknown:
            // Fallback: try to map as best we can
            if i < characterAttributes.count {
                attributesToApply = characterAttributes[i]
            }
        }
        
        // Apply the attributes if we found any
        if !attributesToApply.isEmpty {
            newAttributedString.addAttributes(attributesToApply, range: NSRange(location: i, length: 1))
        }
    }
}
