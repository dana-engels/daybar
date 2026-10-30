import SwiftUI

struct BlockEditor: View {
    @Binding var block: Block
    let accent: Color
    let preview: () -> Void
    let delete: () -> Void
    private let icons = ["sun.max.fill", "pills.fill", "book.fill", "figure.walk", "cup.and.saucer.fill", "hammer.fill", "moon.fill", "sparkles", "heart.fill", "laptopcomputer", "leaf.fill", "fork.knife"]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Activity name", text: $block.title).textFieldStyle(.plain).font(.system(size: 15, weight: .medium))
            DatePicker("Time", selection: Binding(get: {
                Calendar.current.date(bySettingHour: block.minute / 60, minute: block.minute % 60, second: 0, of: Date()) ?? Date()
            }, set: { block.minute = Calendar.current.component(.hour, from: $0) * 60 + Calendar.current.component(.minute, from: $0) }), displayedComponents: .hourAndMinute).datePickerStyle(.field).controlSize(.small)
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
                ForEach(icons, id: \.self) { icon in
                    Button { block.symbol = icon } label: {
                        Image(systemName: icon).font(.system(size: 16)).frame(maxWidth: .infinity).frame(height: 30)
                            .foregroundStyle(block.symbol == icon ? accent : Color.secondary)
                            .background(block.symbol == icon ? accent.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain).accessibilityLabel(icon)
                }
            }
            HStack {
                Button("Preview", systemImage: "play") { preview() }
                Spacer()
                Button("Delete activity", role: .destructive, action: delete)
            }.font(.caption).buttonStyle(.plain).foregroundStyle(.secondary)
        }.padding(16).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
    }
}

