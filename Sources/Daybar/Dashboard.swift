import SwiftUI
import AppKit

struct Dashboard: View {
    @ObservedObject var store: Store
    @State private var editing: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var dashboardAnimation: Animation? {
        store.animated && !reduceMotion ? .easeInOut(duration: 0.2) : nil
    }
    @State private var settings = false
    private var current: Block? { store.timeline.current }
    private var upcoming: Block? { store.timeline.next }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daybar").font(.system(size: 21, weight: .semibold, design: .rounded))
                    Text(store.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button { withAnimation(dashboardAnimation) { settings.toggle(); editing = nil } } label: {
                    Image(systemName: settings ? "xmark" : "slider.horizontal.3").frame(width: 30, height: 30).contentShape(Circle())
                }.buttonStyle(.plain).help(settings ? "Back to today" : "Settings")
            }.padding(22)
            if settings {
                settingsView
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: current?.symbol ?? "sun.horizon.fill")
                            .font(.system(size: 27, weight: .light)).symbolRenderingMode(.hierarchical)
                            .foregroundStyle(store.appearance.accent).frame(width: 46, height: 46)
                            .background(store.appearance.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 15))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(current == nil ? "YOUR DAY AWAITS" : "RIGHT NOW").font(.system(size: 9, weight: .semibold)).tracking(1.8).foregroundStyle(.secondary)
                            Text(current?.displayTitle ?? "A little room to breathe").font(.system(size: 20, weight: .medium)).lineLimit(2)
                        }
                    }
                    if let next = upcoming {
                        HStack(spacing: 5) {
                            Text("Up next").foregroundStyle(.tertiary)
                            Text(next.displayTitle).lineLimit(1)
                            Spacer(minLength: 0)
                            Text(Schedule.time(next.minute)).monospacedDigit()
                        }.font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading).daybarGlass(radius: 22).padding(.horizontal, 18).padding(.bottom, 18)
                HStack {
                    Text("YOUR ROUTINE").font(.system(size: 10, weight: .semibold)).tracking(1.6).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        let block = Block(title: "New activity", minute: 1080, symbol: "sparkles")
                        store.blocks.append(block)
                        editing = block.id
                    } label: { Image(systemName: "plus").frame(width: 26, height: 24) }.buttonStyle(.plain).help("Add activity")
                }.padding(.horizontal, 24).padding(.bottom, 6)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Schedule.ordered(store.blocks)) { block in
                                VStack(spacing: 0) {
                                    Button {
                                        withAnimation(dashboardAnimation) { editing = editing == block.id ? nil : block.id }
                                    } label: { routineRow(block) }.buttonStyle(.plain)
                                    if editing == block.id {
                                        BlockEditor(block: binding(for: block), accent: store.appearance.accent, preview: { store.showReminder?(block) }, delete: {
                                            editing = nil
                                            store.blocks.removeAll { $0.id == block.id }
                                        }).padding(.horizontal, 16).padding(.bottom, 12)
                                    }
                                }.id(block.id)
                            }
                        }.padding(.horizontal, 14).padding(.bottom, 12)
                    }.onChange(of: editing) { _, id in
                        if let id { withAnimation(dashboardAnimation) { proxy.scrollTo(id, anchor: .top) } }
                    }
                }
                HStack {
                    Image(systemName: "checkmark.circle").foregroundStyle(.tertiary)
                    Text(store.storageMessage == nil ? "Saved automatically" : "Check saved settings").foregroundStyle(.tertiary)
                    Spacer()
                    if store.quiet { Image(systemName: "bell.slash").foregroundStyle(.secondary) }
                }.font(.system(size: 10)).padding(.horizontal, 24).padding(.vertical, 12)
            }
        }.frame(width: DaybarLayout.dashboard.width, height: DaybarLayout.dashboard.height).tint(store.appearance.accent).background(.ultraThinMaterial)
    }
    private func binding(for block: Block) -> Binding<Block> {
        Binding(get: { store.blocks.first { $0.id == block.id } ?? block }, set: { updated in
            guard let index = store.blocks.firstIndex(where: { $0.id == block.id }),
                  store.blocks[index] != updated else { return }
            store.blocks[index] = updated
        })
    }
    private func routineRow(_ block: Block) -> some View {
        let active = block.id == current?.id
        return HStack(spacing: 12) {
            Text(Schedule.time(block.minute)).font(.system(size: 11, weight: active ? .semibold : .regular)).monospacedDigit().foregroundStyle(active ? .primary : .secondary).frame(width: 68, alignment: .trailing)
            Image(systemName: block.symbol).font(.system(size: 15, weight: .regular)).foregroundStyle(active ? store.appearance.accent : Color.secondary).frame(width: 28, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(block.displayTitle).font(.system(size: 13, weight: active ? .semibold : .regular)).lineLimit(2)
                if block.weekdays.count != 7 {
                    Text(block.weekdays.isEmpty ? "Not scheduled" : block.weekdays.sorted().map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: " · ")).font(.system(size: 9)).foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            if active { Circle().fill(store.appearance.accent).frame(width: 5, height: 5) }
            Image(systemName: editing == block.id ? "chevron.up" : "chevron.right").font(.system(size: 9, weight: .medium)).foregroundStyle(.tertiary)
        }.padding(.horizontal, 10).padding(.vertical, 7).frame(maxWidth: .infinity, alignment: .leading)
            .background(active ? store.appearance.accent.opacity(0.07) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
    }
    private var settingsView: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 22) {
            Text("Make it yours").font(.title2.weight(.medium))
            VStack(spacing: 20) {
                Toggle("Launch at login", isOn: Binding(get: { store.loginEnabled }, set: { store.setLogin($0) }))
                Toggle("Quiet mode", isOn: $store.quiet)
                Toggle("Animate transitions", isOn: $store.animated)
            }.toggleStyle(.switch).controlSize(.small)
            if let message = store.storageMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
            if let message = store.loginMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
            accentOptions
            Text("A quiet nudge when your day changes. Reminders disappear automatically after six seconds.").font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("Preview transition") {
                if let block = current ?? store.blocks.first { store.showReminder?(block) }
            }.buttonStyle(.bordered).controlSize(.small)
            Spacer()
            Button("Quit Daybar") { NSApp.terminate(nil) }.buttonStyle(.plain).foregroundStyle(.secondary)
        }.padding(24).frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
    private var accentOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COLOR").font(.system(size: 10, weight: .semibold)).tracking(1.6).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), spacing: 10) {
                ForEach(AccentPreset.allCases) { preset in
                    Button { store.appearance.preset = preset } label: {
                        HStack(spacing: 7) {
                            Circle().fill(preset.color).frame(width: 18, height: 18)
                                .overlay { if store.appearance.preset == preset { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white) } }
                            Text(preset.name).font(.system(size: 11))
                        }.padding(.vertical, 5).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityAddTraits(store.appearance.preset == preset ? .isSelected : [])
                }
            }
            HStack {
                Button { store.appearance.preset = nil } label: {
                    HStack(spacing: 7) {
                        Image(systemName: store.appearance.preset == nil ? "checkmark.circle.fill" : "circle").foregroundStyle(store.appearance.custom.color)
                        Text("Custom color").foregroundStyle(.primary)
                    }.font(.system(size: 12))
                }.buttonStyle(.plain)
                Spacer()
                ColorPicker("Custom accent", selection: Binding(get: { store.appearance.custom.color }, set: { color in
                    if let rgb = RGBColor(color: color) { store.appearance.custom = rgb; store.appearance.preset = nil }
                }), supportsOpacity: false).labelsHidden().help("Choose your own accent color")
            }
        }
    }
}

