import SwiftUI

struct ReminderCard: View {
    let block: Block
    let animated: Bool
    let accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(accent.opacity(0.12)).frame(width: 46, height: 46)
                Circle().stroke(accent.opacity(appeared ? 0 : 0.3), lineWidth: 1)
                    .frame(width: 46, height: 46).scaleEffect(appeared && animated && !reduceMotion ? 1.7 : 1)
                    .animation(animated && !reduceMotion ? .easeOut(duration: 1.4) : nil, value: appeared)
                Image(systemName: block.symbol).font(.system(size: 23, weight: .light)).foregroundStyle(accent).symbolRenderingMode(.hierarchical)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("NOW").font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(.secondary)
                Text(block.displayTitle).font(.system(size: 19, weight: .medium, design: .rounded)).lineLimit(2)
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, 22).padding(.vertical, 16).frame(width: DaybarLayout.reminderCard.width, height: DaybarLayout.reminderCard.height).daybarGlass(radius: 24)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared || !animated || reduceMotion ? 1 : 0.86, anchor: .top)
            .offset(y: appeared || !animated || reduceMotion ? 0 : -22)
            .animation(animated && !reduceMotion ? .spring(response: 0.65, dampingFraction: 0.86) : .easeOut(duration: 0.15), value: appeared)
            .frame(width: DaybarLayout.reminderWindow.width, height: DaybarLayout.reminderWindow.height)
            .onAppear { appeared = true }
            .accessibilityElement(children: .combine)
    }
}
