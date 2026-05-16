import SwiftUI

public struct LanguagePickerView: View {
    @Binding var selectedLanguage: String
    @Binding var isPresented: Bool
    let includeAuto: Bool
    let accentColor: Color
    
    @State private var searchText = ""
    
    public init(selectedLanguage: Binding<String>, isPresented: Binding<Bool>, includeAuto: Bool, accentColor: Color) {
        self._selectedLanguage = selectedLanguage
        self._isPresented = isPresented
        self.includeAuto = includeAuto
        self.accentColor = accentColor
    }
    
    private var filteredLanguages: [String] {
        let base = LanguageManager.supportedLanguages.filter {
            searchText.isEmpty || $0.lowercased().contains(searchText.lowercased())
        }
        if includeAuto && (searchText.isEmpty || "auto".contains(searchText.lowercased())) {
            return ["Auto"] + base
        }
        return base
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search...", text: $searchText).textFieldStyle(.plain)
            }
            .padding(10).background(Color.black.opacity(0.05))
            
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(filteredLanguages, id: \.self) { lang in
                        LanguageRow(lang: lang, isSelected: selectedLanguage == lang, accentColor: accentColor) {
                            selectedLanguage = lang
                            isPresented = false
                        }
                    }
                }
                .padding(4)
            }
        }
        .frame(width: 200, height: 300)
    }
}

public struct LanguageRow: View {
    let lang: String
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void
    
    @State private var isHovering = false
    
    public init(lang: String, isSelected: Bool, accentColor: Color, action: @escaping () -> Void) {
        self.lang = lang
        self.isSelected = isSelected
        self.accentColor = accentColor
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            ZStack {
                Text(lang)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? accentColor : .primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                HStack {
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(accentColor)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? accentColor.opacity(0.12) : (isHovering ? Color.primary.opacity(0.05) : .clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
