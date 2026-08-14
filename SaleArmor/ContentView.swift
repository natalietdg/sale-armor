import SwiftUI
import FamilyControls

/// Two things: the guard, and the wishlist. No dashboard, no goals, no streaks.
struct ContentView: View {
    @StateObject private var controller = ArmorController()
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = Tab.guardTab

    enum Tab: String, CaseIterable, Identifiable {
        case guardTab = "Guard"
        case wishlist = "Wishlist"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            Px.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                if controller.authorization == .approved {
                    tabBar
                    Divider().overlay(Px.line)
                }
                content
                    .padding(Px.unit * 5)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .task { controller.syncWithClock() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { controller.syncWithClock() }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { t in
                Button { tab = t } label: {
                    Text(t.rawValue)
                        .font(.px(12, .black)).tracking(1.4).textCase(.uppercase)
                        .foregroundStyle(tab == t ? Px.bg : Px.dim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Px.unit * 3)
                        .background(tab == t ? Px.goldMetal : Px.bg)
                }
                .accessibilityIdentifier("tab-\(t.rawValue)")
            }
        }
        .padding(.top, Px.unit * 2)
    }

    @ViewBuilder
    private var content: some View {
        switch controller.authorization {
        case .approved:
            switch tab {
            case .guardTab:
                if let window = controller.window {
                    ArmedView(window: window,
                              shielding: controller.isShielding,
                              saved: controller.wishlist.saved,
                              onDisarm: { controller.disarm() })
                } else {
                    ArmView(controller: controller)
                }
            case .wishlist:
                WishlistView(controller: controller)
            }
        default:
            PermissionView(controller: controller)
        }
    }
}

// MARK: - permission

private struct PermissionView: View {
    @ObservedObject var controller: ArmorController

    var body: some View {
        VStack(spacing: Px.unit * 6) {
            Spacer()
            SwordSprite(lit: false).frame(width: 350)
            Text("Sale Armor").font(.px(30, .black)).tracking(3).foregroundStyle(Px.ink)
            Text("Shut the shopping apps for the hours you'd regret.")
                .font(.px(13)).foregroundStyle(Px.dim).multilineTextAlignment(.center)

            Button("Protect my wallet") { Task { await controller.requestAuthorization() } }
                .buttonStyle(PxButtonStyle())

            if let problem = controller.problem {
                Text(problem).font(.px(11)).foregroundStyle(Px.alert)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
    }
}

// MARK: - arming

private struct ArmView: View {
    @ObservedObject var controller: ArmorController

    @State private var name = ""
    @State private var chosen: SaleKind?
    @State private var kind = 1                      // Every day, the commonest case
    @State private var start = Date()
    @State private var end = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var from = Clock.evening
    @State private var to = Clock.lateNight
    @State private var weekdays: Set<Int> = [6, 7]   // Friday, Saturday
    @State private var monthDays: Set<Int> = [25]    // payday
    @State private var selection = FamilyActivitySelection()
    @State private var picking = false

    private static let kinds = ["Once", "Every day", "Some days", "Dates"]
    private static let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]

    private var pattern: ArmorPattern {
        switch kind {
        case 0:  .dateRange(start: start, end: end)
        case 2:  .weekly(weekdays: weekdays, from: from, to: to)
        case 3:  .monthly(days: monthDays)
        default: .daily(from: from, to: to)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Px.unit * 5) {
                VStack(alignment: .leading, spacing: Px.unit * 2) {
                    HStack(spacing: Px.unit * 3) {
                        SwordSprite(lit: false, glow: false).frame(width: 40)
                        Text("Sale Armor").font(.px(20, .black)).tracking(2).foregroundStyle(Px.ink)
                    }
                    // The whole argument for categories in one line: you are not being asked to
                    // invent a schedule, you are being asked to recognise yourself.
                    Text("You know your patterns.")
                        .font(.px(13, .black)).foregroundStyle(Px.goldMetal)
                }

                field("What are you guarding against") {
                    // Categories rather than a blank field. Each one brings its own schedule, so
                    // arming is a tap and a check instead of naming a thing and then inventing a
                    // timetable for it. Everything below stays editable afterwards.
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: Px.unit),
                                        GridItem(.flexible(), spacing: Px.unit)],
                              spacing: Px.unit) {
                        ForEach(SaleKind.allCases) { sale in
                            Button { apply(sale) } label: {
                                Text(sale.short())
                                    .font(.px(11, .black))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(chosen == sale ? Px.bg : Px.ink)
                                    .frame(maxWidth: .infinity, minHeight: Px.unit * 8)
                                    .padding(.horizontal, Px.unit)
                                    .background(chosen == sale ? Px.goldMetal : Px.panel)
                            }
                            .accessibilityIdentifier("sale-\(sale.rawValue)")
                        }
                    }
                }

                field("Which apps") {
                    Button { picking = true } label: {
                        HStack {
                            Text(appCount == 0 ? "Choose apps" : "\(appCount) will be shut")
                                .font(.px(14, .black)).foregroundStyle(Px.ink)
                            Spacer()
                            Text("▶").font(.px(14)).foregroundStyle(Px.goldMetal)
                        }
                    }
                    .accessibilityIdentifier("chooseApps")
                }

                field("When") {
                    VStack(alignment: .leading, spacing: Px.unit * 3) {
                        segmented
                        scheduleControls
                    }
                }

                Button("Arm it") {
                    controller.arm(name: chosen?.rawValue ?? "The guard",
                                   pattern: pattern, selection: selection)
                }
                .buttonStyle(PxButtonStyle())
                .accessibilityIdentifier("armIt")

                if let problem = controller.problem {
                    Text(problem).font(.px(11)).foregroundStyle(Px.alert)
                }

                Text("It arms itself and stands down on its own. You don't have to open this again.")
                    .font(.px(11)).foregroundStyle(Px.dim)
            }
        }
        .familyActivityPicker(isPresented: $picking, selection: $selection)
    }

    private var appCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }

    /// Picking a category fills in the schedule it implies. The controls below stay live, so this
    /// is a starting point rather than a decision taken away.
    private func apply(_ sale: SaleKind) {
        chosen = sale
        name = sale.rawValue
        switch sale.pattern() {
        case let .dateRange(s, e):
            kind = 0; start = s; end = e
        case let .daily(f, t):
            kind = 1; from = f; to = t
        case let .weekly(days, f, t):
            kind = 2; weekdays = days; from = f; to = t
        case let .monthly(days):
            kind = 3; monthDays = days
        }
    }

    private var segmented: some View {
        HStack(spacing: Px.unit / 2) {
            ForEach(Array(Self.kinds.enumerated()), id: \.offset) { i, title in
                Button { kind = i } label: {
                    Text(title)
                        .font(.px(10, .black)).tracking(0.8).textCase(.uppercase)
                        .foregroundStyle(kind == i ? Px.bg : Px.dim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Px.unit * 2)
                        .background(kind == i ? Px.goldMetal : Px.panel)
                }
                .accessibilityIdentifier("kind\(i)")
            }
        }
    }

    @ViewBuilder
    private var scheduleControls: some View {
        switch kind {
        case 0:
            VStack(alignment: .leading, spacing: Px.unit * 3) {
                Text("From").pxLabel(9).foregroundStyle(Px.dim)
                PxDateField(date: $start)
                Text("Until").pxLabel(9).foregroundStyle(Px.dim)
                PxDateField(date: $end, notBefore: start)
            }
        case 2:
            HStack(spacing: Px.unit) {
                ForEach(1...7, id: \.self) { day in
                    Button {
                        if weekdays.contains(day) { weekdays.remove(day) } else { weekdays.insert(day) }
                    } label: {
                        Text(Self.dayLetters[day - 1])
                            .font(.px(12, .black))
                            .foregroundStyle(weekdays.contains(day) ? Px.bg : Px.dim)
                            .frame(maxWidth: .infinity, minHeight: Px.unit * 9)
                            .background(weekdays.contains(day) ? Px.goldMetal : Px.panel)
                    }
                    .accessibilityIdentifier("weekday\(day)")
                }
            }
            timeRow
        case 3:
            // A month grid. 31 always shown — a month without one simply never fires.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Px.unit), count: 7),
                      spacing: Px.unit) {
                ForEach(1...31, id: \.self) { day in
                    Button {
                        if monthDays.contains(day) { monthDays.remove(day) } else { monthDays.insert(day) }
                    } label: {
                        Text("\(day)")
                            .font(.px(11, .black))
                            .foregroundStyle(monthDays.contains(day) ? Px.bg : Px.dim)
                            .frame(maxWidth: .infinity, minHeight: Px.unit * 8)
                            .background(monthDays.contains(day) ? Px.goldMetal : Px.panel)
                    }
                }
            }
        default:
            timeRow
        }
    }

    private var timeRow: some View {
        HStack(spacing: Px.unit * 3) {
            clockStepper("From", $from)
            clockStepper("To", $to)
        }
    }

    /// A stepper rather than a wheel: an hour is the only precision this app needs, and a wheel
    /// picker inside a dark 8-bit panel looks like a different app.
    private func clockStepper(_ label: String, _ clock: Binding<Clock>) -> some View {
        VStack(alignment: .leading, spacing: Px.unit) {
            Text(label).pxLabel(9).foregroundStyle(Px.dim)
            HStack(spacing: Px.unit) {
                Button("−") { clock.wrappedValue.hour = (clock.wrappedValue.hour + 23) % 24 }
                    .buttonStyle(PxButtonStyle(tint: Px.panel, text: Px.ink))
                Text(clock.wrappedValue.text)
                    .font(.px(15, .black)).foregroundStyle(Px.ink)
                    .frame(minWidth: Px.unit * 14)
                Button("+") { clock.wrappedValue.hour = (clock.wrappedValue.hour + 1) % 24 }
                    .buttonStyle(PxButtonStyle(tint: Px.panel, text: Px.ink))
            }
        }
    }

    private func field<C: View>(_ label: String, @ViewBuilder _ control: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Px.unit * 2) {
            Text(label).pxLabel().foregroundStyle(Px.dim)
            PxPanel { control() }
        }
    }
}

// MARK: - armed

private struct ArmedView: View {
    let window: ArmorWindow
    let shielding: Bool
    /// What the guard has been worth so far. Shown here rather than only on the wishlist, because
    /// this is the screen you open to check the shield is up — and the number is the reason to keep
    /// it up.
    let saved: Double
    let onDisarm: () -> Void

    var body: some View {
        VStack(spacing: Px.unit * 5) {
            Spacer()
            SwordSprite(lit: shielding).frame(width: 340)

            Text(shielding ? "On guard" : "Armed")
                .font(.px(28, .black)).tracking(3)
                .foregroundStyle(shielding ? Px.armor : Px.gold)

            Text(window.name.uppercased()).pxLabel(13).foregroundStyle(Px.ink)

            PxPanel {
                VStack(alignment: .leading, spacing: Px.unit * 3) {
                    row("Apps shut", "\(window.appCount)")
                    row("Pattern", window.pattern.label)
                    row("When", Self.whenText(window.pattern))
                }
            }

            if saved > 0 {
                VStack(spacing: Px.unit) {
                    Text("Not spent so far").pxLabel(9).foregroundStyle(Px.dim)
                    Text(saved.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                        .font(.px(26, .black)).foregroundStyle(Px.goldMetal)
                        .accessibilityIdentifier("armedSaved")
                }
            }

            Button("Disarm") { onDisarm() }
                .buttonStyle(PxButtonStyle(tint: Px.panel, text: Px.alert))
                .accessibilityIdentifier("disarm")

            Text(shielding ? "Nothing to do. Close this." : "Waiting for the next window.")
                .font(.px(11)).foregroundStyle(Px.dim)
            Spacer()
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).pxLabel(10).foregroundStyle(Px.dim)
            Spacer()
            Text(value).font(.px(13, .black)).foregroundStyle(Px.ink)
        }
    }

    private static func whenText(_ pattern: ArmorPattern) -> String {
        switch pattern {
        case let .dateRange(start, end):
            "\(start.formatted(.dateTime.day().month(.abbreviated))) – \(end.formatted(.dateTime.day().month(.abbreviated)))"
        case let .daily(from, to):
            "\(from.text) – \(to.text)"
        case let .weekly(days, from, to):
            "\(days.count) day\(days.count == 1 ? "" : "s") · \(from.text) – \(to.text)"
        case let .monthly(days):
            days.sorted().map(String.init).joined(separator: ", ")
        }
    }
}

// MARK: - wishlist

private struct WishlistView: View {
    @ObservedObject var controller: ArmorController
    @State private var name = ""
    @State private var link = ""
    @State private var price = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Px.unit * 5) {
                savedPanel

                PxPanel {
                    VStack(alignment: .leading, spacing: Px.unit * 3) {
                        Text("What did you want to buy?").pxLabel().foregroundStyle(Px.gold)
                        TextField("", text: $name, prompt: Text("Those trainers").foregroundColor(Px.dim))
                            .font(.px(14, .black)).foregroundStyle(Px.ink).textFieldStyle(.plain)
                            .accessibilityIdentifier("wishName")
                        TextField("", text: $link, prompt: Text("Link (optional)").foregroundColor(Px.dim))
                            .font(.px(12)).foregroundStyle(Px.dim).textFieldStyle(.plain)
                            .textInputAutocapitalization(.never)
                            .accessibilityIdentifier("wishLink")
                        TextField("", text: $price, prompt: Text("Price").foregroundColor(Px.dim))
                            .font(.px(14, .black)).foregroundStyle(Px.ink).textFieldStyle(.plain)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("wishPrice")
                        Button("Park it") {
                            controller.addWish(name: name, link: link,
                                               price: Double(price) ?? 0)
                            name = ""; link = ""; price = ""
                        }
                        .buttonStyle(PxButtonStyle())
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("parkIt")
                    }
                }

                if !controller.wishlist.open.isEmpty {
                    Text("Parked").pxLabel().foregroundStyle(Px.dim)
                    ForEach(controller.wishlist.open) { item in
                        openRow(item)
                    }
                }

                if !controller.wishlist.skipped.isEmpty {
                    Text("Didn't buy").pxLabel().foregroundStyle(Px.dim)
                    ForEach(controller.wishlist.skipped) { item in
                        HStack {
                            Text(item.name).font(.px(12)).foregroundStyle(Px.dim)
                            Spacer()
                            Text(Self.money(item.price)).font(.px(12, .black)).foregroundStyle(Px.goldMetal)
                        }
                        .padding(.vertical, Px.unit)
                    }
                }
            }
        }
    }

    /// The whole point of the feature: what the shield has been worth.
    private var savedPanel: some View {
        PxPanel(stroke: Px.goldMetal) {
            VStack(alignment: .leading, spacing: Px.unit) {
                Text("Not spent").pxLabel().foregroundStyle(Px.goldMetal)
                Text(Self.money(controller.wishlist.saved))
                    .font(.px(34, .black)).foregroundStyle(Px.ink)
                    .accessibilityIdentifier("savedTotal")
                Text("Nothing to hit, nothing to keep up. Just what you didn't spend.")
                    .font(.px(11)).foregroundStyle(Px.dim)
            }
        }
    }

    private func openRow(_ item: WishItem) -> some View {
        PxPanel {
            VStack(alignment: .leading, spacing: Px.unit * 2) {
                HStack {
                    Text(item.name).font(.px(14, .black)).foregroundStyle(Px.ink)
                    Spacer()
                    Text(Self.money(item.price)).font(.px(14, .black)).foregroundStyle(Px.gold)
                }
                if let link = item.link, let url = URL(string: link) {
                    Link(destination: url) {
                        Text(link).font(.px(10)).foregroundStyle(Px.dim).lineLimit(1)
                    }
                }
                HStack(spacing: Px.unit * 2) {
                    Button("Didn't buy") { controller.skip(item.id) }
                        .buttonStyle(PxButtonStyle())
                        .accessibilityIdentifier("skip-\(item.name)")
                    Button("Bought it") { controller.bought(item.id) }
                        .buttonStyle(PxButtonStyle(tint: Px.panel, text: Px.dim))
                }
            }
        }
    }

    private static func money(_ amount: Double) -> String {
        amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}
