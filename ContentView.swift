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
    }
    
    func updateSelectedRange(inputRange: NSRange) -> Void {
        self.userSelectedRange = inputRange
    }
    
    func bold() -> Void {
        // Validate the selected range
        guard userSelectedRange.location != NSNotFound,
              userSelectedRange.location >= 0,
              userSelectedRange.location + userSelectedRange.length <= mutableAString.length else {
            print("Invalid selection range")
            return
        }
        
        // Handle empty selection (cursor position)
        if userSelectedRange.length == 0 {
            print("No text selected - bold formatting will apply to future typing")
            return
        }
        
        // Create a new attributed string to trigger view update
        let newAttributedString = NSMutableAttributedString(attributedString: mutableAString)
        
        // Check if the selected range is currently bold
        let isBoldRange = isRangeBold(in: newAttributedString, range: userSelectedRange)
        
        if isBoldRange {
            // Remove bold formatting from the selected range
            removeBoldFromRange(in: newAttributedString, range: userSelectedRange)
        } else {
            // Add bold formatting to the selected range
            addBoldToRange(in: newAttributedString, range: userSelectedRange)
        }
        
        // Update the published property to trigger view refresh
        self.mutableAString = newAttributedString
    }
    
    private func isRangeBold(in attributedString: NSAttributedString, range: NSRange) -> Bool {
        var isBold = true
        
        // Check each character in the range
        attributedString.enumerateAttribute(.font, in: range, options: []) { (value, range, stop) in
            if let font = value as? UIFont {
                // Check if this font is bold - if any characters are not bold, return false
                if !font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    isBold = false
                    stop.pointee = true
                }
            } else {
                // No font attribute means it's not bold
                isBold = false
                stop.pointee = true
            }
        }
        
        return isBold
    }
    
    private func addBoldToRange(in attributedString: NSMutableAttributedString, range: NSRange) {
        // Apply bold font to the entire range
        attributedString.enumerateAttribute(.font, in: range, options: []) { (value, subRange, _) in
            let currentFont = value as? UIFont ?? UIFont.systemFont(ofSize: 72.0)
            let boldFont = UIFont.boldSystemFont(ofSize: currentFont.pointSize)
            attributedString.addAttribute(.font, value: boldFont, range: subRange)
        }
    }
    
    private func removeBoldFromRange(in attributedString: NSMutableAttributedString, range: NSRange) {
        // Remove bold formatting from the entire range
        attributedString.enumerateAttribute(.font, in: range, options: []) { (value, subRange, _) in
            let currentFont = value as? UIFont ?? UIFont.systemFont(ofSize: 72.0)
            let regularFont = UIFont.systemFont(ofSize: currentFont.pointSize)
            attributedString.addAttribute(.font, value: regularFont, range: subRange)
        }
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
        
//        print("inside updateUIView")
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

//        print("inside textViewDidChange")
        viewModel.updateStringTest(input: textView.text)
        self.originalRange = textView.selectedRange

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
