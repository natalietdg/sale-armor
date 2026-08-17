import SwiftUI
import FamilyControls

/// Two things: the guard, and the wishlist. No dashboard, no goals, no streaks.
struct ContentView: View {
    @StateObject private var controller = ArmorController()
    @StateObject private var subscription = Subscription()
    @StateObject private var music = Music()
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = Demo.opensWishlist ? Tab.wishlist : Tab.guardTab

    enum Tab: String, CaseIterable, Identifiable {
        case guardTab = "Guard"
        case wishlist = "Wishlist"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            PxBricks()
            VStack(spacing: 0) {
                // The paywall sits above everything, including the Screen Time prompt: there is no
                // free tier, so an unsubscribed person never reaches the app picker at all.
                if subscription.isActive {
                    if controller.authorization == .approved {
                        HStack(spacing: 0) {
                            tabBar
                            musicButton
                        }
                        Divider().overlay(Px.line)
                    }
                    content
                        .padding(Px.unit * 5)
                        .frame(maxWidth: 520)
                        .frame(maxWidth: .infinity)
                } else {
                    PaywallView(subscription: subscription)
                        .padding(.horizontal, Px.unit * 5)
                        .frame(maxWidth: 520)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { controller.syncWithClock() }
        .onChange(of: scenePhase) { _, phase in
            music.setActive(phase == .active)
            guard phase == .active else { return }
            controller.syncWithClock()
            // A subscription can lapse or be restored while the app is closed.
            Task { await subscription.refresh() }
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

    /// Two pixel bars for on, one for off. A speaker glyph would be the obvious choice and the
    /// wrong one — every other mark in this app is drawn on the grid.
    private var musicButton: some View {
        Button { music.isOn.toggle() } label: {
            HStack(spacing: Px.unit / 2) {
                ForEach(0..<3, id: \.self) { i in
                    Rectangle()
                        .fill(music.isOn ? Px.goldMetal : Px.dim)
                        .frame(width: Px.unit, height: Px.unit * CGFloat(music.isOn ? [2, 4, 3][i] : 1))
                }
            }
            .frame(width: Px.unit * 11, height: Px.unit * 9)
            .background(Px.bg)
        }
        .accessibilityLabel(music.isOn ? "Turn the music off" : "Turn the music on")
        .accessibilityIdentifier("musicToggle")
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
                              paid: subscription.paidSoFar,
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

    /// Bumped on arm, so `sensoryFeedback` has something to watch. Counters rather than booleans,
    /// because arming twice in a row must feel twice.
    @State private var armed = 0
    @State private var chose = 0

    private static let kinds = ["Once", "Daily", "Days", "Dates", "N.N"]
    private static let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]

    private var pattern: ArmorPattern {
        switch kind {
        case 0:  .dateRange(start: start, end: end)
        case 2:  .weekly(weekdays: weekdays, from: from, to: to)
        case 3:  .monthly(days: monthDays)
        case 4:  .doubleDates
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
                                VStack(spacing: Px.unit) {
                                    Text(sale.short())
                                        .font(.px(11, .black))
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(chosen == sale ? Px.bg : Px.ink)
                                    HStack(spacing: Px.unit) {
                                        tag(sale.foe, colour: Px.ink, on: chosen == sale)
                                        tag(sale.tier, colour: Self.tierColour(sale.tierRank),
                                            on: chosen == sale)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: Px.unit * 12)
                                .padding(.horizontal, Px.unit)
                                .padding(.vertical, Px.unit * 2)
                                .background(chosen == sale ? Px.goldMetal : Px.panel)
                            }
                            .accessibilityIdentifier("sale-\(sale.rawValue)")
                            .simultaneousGesture(TapGesture().onEnded { chose += 1 })
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
                    armed += 1
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
        // Arming is the one act on this screen that changes what the phone does, so it lands like
        // one. Picking a foe is a lighter tick — enough to confirm the tap without competing.
        .sensoryFeedback(.success, trigger: armed)
        .sensoryFeedback(.selection, trigger: chose)
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
        case .doubleDates:
            kind = 4
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
        case 4:
            Text("Every 1.1, 2.2, 3.3 … 11.11 and 12.12. Twelve sales a year, all day.")
                .font(.px(11)).foregroundStyle(Px.dim)
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

    private static func tierColour(_ rank: Int) -> Color {
        switch rank {
        case 2:  Px.tierBoss
        case 1:  Px.tierElite
        default: Px.tierNormal
        }
    }

    /// A tag: the foe, and how hard it hits. Flavour only — nothing here levels up.
    private func tag(_ text: String, colour: Color, on selected: Bool) -> some View {
        Text(text.uppercased())
            .font(.px(9, .black)).tracking(0.6)
            .foregroundStyle(colour)
            .padding(.horizontal, Px.unit)
            .padding(.vertical, Px.unit / 2)
            .background(Px.bg.opacity(selected ? 0.55 : 0.75))
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
    /// Roughly what Sale Armor has cost so far. Nil while unknown, and the return stays hidden.
    let paid: Double?
    let onDisarm: () -> Void

    /// Standing down is a decision, not a mistake — a warning tone would scold. A soft impact
    /// just confirms the shield is gone.
    @State private var disarmed = 0

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
                    Text("Money that stayed yours").pxLabel(9).foregroundStyle(Px.dim)
                    Text(Self.money(saved))
                        .font(.px(26, .black)).foregroundStyle(Px.goldMetal)
                        .accessibilityIdentifier("armedSaved")
                    // Only once it has actually paid for itself. Showing "0.4x" to someone who has
                    // not turned anything down yet would be an argument against the app.
                    if let paid, paid > 0, saved > paid {
                        Text("\(Self.money(paid)) spent on Sale Armor · \(Self.multiple(saved / paid)) back")
                            .font(.px(10)).foregroundStyle(Px.dim)
                            .accessibilityIdentifier("armedReturn")
                    }
                }
            }

            Button("Disarm") { disarmed += 1; onDisarm() }
                .buttonStyle(PxButtonStyle(tint: Px.panel, text: Px.alert))
                .accessibilityIdentifier("disarm")

            Text(shielding ? "Nothing to do. Close this." : "Waiting for the next window.")
                .font(.px(11)).foregroundStyle(Px.dim)
            Spacer()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: disarmed)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).pxLabel(10).foregroundStyle(Px.dim)
            Spacer()
            Text(value).font(.px(13, .black)).foregroundStyle(Px.ink)
        }
    }

    private static func money(_ amount: Double) -> String {
        amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    /// Whole multiples above ten: "43x" reads instantly where "43.2x" reads like a spreadsheet.
    private static func multiple(_ ratio: Double) -> String {
        ratio >= 10 ? "\(Int(ratio))x" : String(format: "%.1fx", ratio)
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
        case .doubleDates:
            "1.1 · 2.2 · … · 12.12"
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
                defendedPanel
                parkForm

                // Cooled items first. Something parked long enough to decide on is the only thing
                // on this screen that wants an answer today; everything else is just waiting.
                let cooled = controller.wishlist.open.filter { $0.isCool() }
                let waiting = controller.wishlist.open.filter { !$0.isCool() }

                if !cooled.isEmpty {
                    Text("Still worth it?").pxLabel().foregroundStyle(Px.gold)
                    ForEach(cooled) { item in decisionCard(item) }
                }

                if !waiting.isEmpty {
                    Text("Cooling off").pxLabel().foregroundStyle(Px.dim)
                    ForEach(waiting) { item in waitingCard(item) }
                }

                if !controller.wishlist.skipped.isEmpty {
                    Text("Defended").pxLabel().foregroundStyle(Px.dim)
                    ForEach(controller.wishlist.skipped) { item in
                        HStack {
                            Text(item.name).font(.px(12)).foregroundStyle(Px.dim)
                            Spacer()
                            Text("+ " + Self.money(item.price))
                                .font(.px(12, .black)).foregroundStyle(Px.goldMetal)
                        }
                        .padding(.vertical, Px.unit)
                    }
                }
            }
        }
    }

    /// The whole point of the feature: money that stayed yours.
    ///
    /// This counts killed items only, never parked ones — see `Wishlist.saved`. A total that jumped
    /// the moment you typed a price would be a number nobody believes, least of all the person who
    /// typed it.
    private var defendedPanel: some View {
        PxPanel(stroke: Px.goldMetal) {
            VStack(alignment: .leading, spacing: Px.unit) {
                Text("Not spent").pxLabel().foregroundStyle(Px.goldMetal)
                Text(Self.money(controller.wishlist.saved))
                    .font(.px(34, .black)).foregroundStyle(Px.ink)
                    .accessibilityIdentifier("savedTotal")
                Text(controller.wishlist.killed == 0
                     ? "Money that stayed yours. Nothing counts until you turn it down."
                     : "Money that stayed yours. \(controller.wishlist.killed) seen off.")
                    .font(.px(11)).foregroundStyle(Px.dim)
            }
        }
    }

    /// "About to buy", not "want". One records an interrupted purchase; the other invites shopping.
    private var parkForm: some View {
        PxPanel {
            VStack(alignment: .leading, spacing: Px.unit * 3) {
                Text("Park an impulse").pxLabel().foregroundStyle(Px.gold)
                TextField("", text: $name,
                          prompt: Text("What were you about to buy?").foregroundColor(Px.dim))
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
                    controller.addWish(name: name, link: link, price: Double(price) ?? 0)
                    name = ""; link = ""; price = ""
                }
                .buttonStyle(PxButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("parkIt")

                Text("It waits \(WishItem.coolingOff) days. Then Sale Armor asks you once — one\nnotification per thing, and nothing else.")
                    .font(.px(10)).foregroundStyle(Px.dim)
            }
        }
    }

    /// Parked long enough that the impulse has passed, so the question is finally fair to ask.
    private func decisionCard(_ item: WishItem) -> some View {
        PxPanel(stroke: Px.gold) {
            VStack(alignment: .leading, spacing: Px.unit * 2) {
                itemHeading(item)
                Text("You parked this \(item.daysParked()) days ago. Still worth it?")
                    .font(.px(11)).foregroundStyle(Px.ink)
                HStack(spacing: Px.unit * 2) {
                    // "Nah" leads, because turning it down is the outcome worth making easy.
                    Button("Nah") { controller.skip(item.id) }
                        .buttonStyle(PxButtonStyle())
                        .accessibilityIdentifier("skip-\(item.name)")
                    Button("I still want it") { controller.bought(item.id) }
                        .buttonStyle(PxButtonStyle(tint: Px.panel, text: Px.dim))
                }
            }
        }
    }

    /// Still cooling. No buttons: offering the decision now is offering it while the want is loud.
    private func waitingCard(_ item: WishItem) -> some View {
        PxPanel {
            VStack(alignment: .leading, spacing: Px.unit) {
                itemHeading(item)
                Text(Self.survived(item))
                    .font(.px(10)).tracking(1).textCase(.uppercase)
                    .foregroundStyle(Px.armor)
            }
        }
    }

    private func itemHeading(_ item: WishItem) -> some View {
        VStack(alignment: .leading, spacing: Px.unit) {
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
        }
    }

    private static func survived(_ item: WishItem) -> String {
        let days = item.daysParked()
        let left = WishItem.coolingOff - days
        return days == 0
            ? "Parked today · \(left) to go"
            : "\(days) day\(days == 1 ? "" : "s") survived · \(left) to go"
    }

    private static func money(_ amount: Double) -> String {
        amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}
