import SwiftUI

struct BlockEditor: View {
    @Binding var block: Block
    let accent: Color
    let preview: () -> Void
    let delete: () -> Void
    private let icons = [
        (symbol: "sun.max.fill", label: "Sun"),
        (symbol: "pills.fill", label: "Pills"),
        (symbol: "book.fill", label: "Book"),
        (symbol: "figure.walk", label: "Walking"),
        (symbol: "cup.and.saucer.fill", label: "Coffee"),
        (symbol: "hammer.fill", label: "Hammer"),
        (symbol: "moon.fill", label: "Moon"),
        (symbol: "sparkles", label: "Sparkles"),
        (symbol: "heart.fill", label: "Heart"),
        (symbol: "laptopcomputer", label: "Laptop"),
        (symbol: "leaf.fill", label: "Leaf"),
        (symbol: "fork.knife", label: "Meal"),
    ]
    @State private var draftTitle: String?
    @State private var originalTitle: String?
    @FocusState private var editingTitle: Bool
    @State private var confirmingDeletion = false

    // A recurring time needs a complete local day, including on a clock-change Sunday.
    private var pickerTime: Binding<Date> {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        while let interval = calendar.dateInterval(of: .day, for: day), interval.duration != 86400 {
            day = interval.end
        }
        let start = day
        return Binding(get: { start.addingTimeInterval(Double(block.minute * 60)) }, set: { value in
            block.minute = calendar.component(.hour, from: value) * 60 + calendar.component(.minute, from: value)
        })
    }

    private func finishTitleEdit() {
        draftTitle = nil
        originalTitle = nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Activity name", text: Binding(get: { draftTitle ?? block.displayTitle }, set: { value in
                if originalTitle == nil { originalTitle = block.title }
                draftTitle = value
                block.title = Block.usableTitle(value) ?? originalTitle ?? block.title
            }))
                .focused($editingTitle)
                .onChange(of: editingTitle) { _, focused in
                    if !focused { finishTitleEdit() }
                }
                .onSubmit { finishTitleEdit() }
                .textFieldStyle(.plain).font(.system(size: 15, weight: .medium))
            DatePicker("Time", selection: pickerTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.field).controlSize(.small)
            HStack(spacing: 5) {
                ForEach(1...7, id: \.self) { day in
                    let selected = block.weekdays.contains(day)
                    Button {
                        if selected { block.weekdays.removeAll { $0 == day } }
                        else { block.weekdays.append(day) }
                    } label: {
                        Text(String(Calendar.current.shortWeekdaySymbols[day - 1].prefix(1)))
                            .font(.system(size: 11, weight: .medium)).frame(width: 30, height: 28)
                            .foregroundStyle(selected ? Color.white : Color.secondary)
                            .background(selected ? accent : Color.primary.opacity(0.04), in: Capsule())
                    }.buttonStyle(.plain).help(Calendar.current.weekdaySymbols[day - 1]).accessibilityLabel(Calendar.current.weekdaySymbols[day - 1]).accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                ForEach(icons, id: \.symbol) { icon in
                    Button { block.symbol = icon.symbol } label: {
                        Image(systemName: icon.symbol).font(.system(size: 16)).frame(maxWidth: .infinity).frame(height: 30)
                            .foregroundStyle(block.symbol == icon.symbol ? accent : Color.secondary)
                            .background(block.symbol == icon.symbol ? accent.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain).accessibilityLabel(icon.label).accessibilityAddTraits(block.symbol == icon.symbol ? .isSelected : [])
                }
            }
            HStack {
                Button("Preview", systemImage: "play") { preview() }
                Spacer()
                Button("Delete activity", role: .destructive) { confirmingDeletion = true }
                    .alert("Delete “\(block.displayTitle)”?", isPresented: $confirmingDeletion) {
                        Button("Cancel", role: .cancel) {}
                        Button("Delete", role: .destructive, action: delete)
                    } message: {
                        Text("This removes the activity from every day it is scheduled.")
                    }
            }.font(.caption).buttonStyle(.plain).foregroundStyle(.secondary)
        }.padding(16).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
    }
}

