import SwiftUI
import FamilyControls

/// Two things: the guard, and the wishlist. No dashboard, no goals, no streaks.
struct ContentView: View {
    @StateObject private var controller = ArmorController()
    @StateObject private var subscription = Subscription()
    @StateObject private var music = Music()
    /// Owned by the app delegate, not by this view — a payday offer can be tapped before any view
    /// exists. See `PaydayOfferInbox`.
    @ObservedObject private var offers = PaydayOfferInbox.shared
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
                    Spacer(minLength: 0)
                    policyFooter
                } else {
                    PaywallView(subscription: subscription)
                        .padding(.horizontal, Px.unit * 5)
                        .frame(maxWidth: 520)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            controller.syncWithClock()
            startOfferedSessionIfTapped()
        }
        // Checked in both places on purpose: a cold launch from the notification can set the flag
        // before this view exists, and a tap while the app is open sets it afterwards.
        .onChange(of: offers.wasAccepted) { _, _ in startOfferedSessionIfTapped() }
        .onChange(of: scenePhase) { _, phase in
            music.setActive(phase == .active)
            guard phase == .active else { return }
            controller.syncWithClock()
            // A subscription can lapse or be restored while the app is closed.
            Task { await subscription.refresh() }
        }
    }

    /// The offer said a tap would start a session, so it starts one.
    private func startOfferedSessionIfTapped() {
        guard offers.wasAccepted else { return }
        offers.wasAccepted = false
        controller.acceptPaydayOffer()
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

    /// A subscriber never sees the paywall again, so its Terms and Privacy links would be the only
    /// ones in the app and would be unreachable the moment they are needed.
    private var policyFooter: some View {
        HStack(spacing: Px.unit * 4) {
            Link(destination: Policy.terms) { Text("Terms").pxTapTarget() }
                .accessibilityIdentifier("policy-terms")
            Link(destination: Policy.privacy) { Text("Privacy").pxTapTarget() }
                .accessibilityIdentifier("policy-privacy")
        }
        .font(.px(10)).foregroundStyle(Px.dim)
        .padding(.bottom, Px.unit * 3)
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
            .pxTapTarget()
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
                              problem: controller.problem,
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
        // Centred while it fits, scrollable once it does not. See `PxCenteredScroll`.
        PxCenteredScroll {
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
}

// MARK: - arming

private struct ArmView: View {
    @ObservedObject var controller: ArmorController

    @State private var mode: GuardMode = .standard
    @State private var confirmingLock = false

    /// Standard or locked, decided while calm.
    ///
    /// This sits at the end of the form on purpose. The question only means anything once you have
    /// said which apps and which hours — "how serious is this one" is unanswerable before you know
    /// what "this one" is.
    private var modePicker: some View {
        VStack(alignment: .leading, spacing: Px.unit * 2) {
            modeOption(.standard, title: "Standard", line: "I just need friction.",
                       detail: "You can disarm it whenever you like.")
            modeOption(.locked, title: "Locked", line: "Don't let me negotiate with myself.",
                       detail: "Sale Armor won't end this one early. Up to 3 days at a time.")
        }
    }

    private func modeOption(_ value: GuardMode, title: String, line: String, detail: String) -> some View {
        Button {
            mode = value
        } label: {
            HStack(alignment: .top, spacing: Px.unit * 3) {
                // Drawn, not typed. Pixelify Sans has no box-drawing glyphs, so ◼/◻ came out as
                // the missing-character box — and a checkbox rendered as "?" reads as a bug in the
                // one control whose whole job is to look decided.
                Rectangle()
                    .fill(mode == value ? Px.gold : Color.clear)
                    .frame(width: Px.unit * 3, height: Px.unit * 3)
                    .pxBevel(light: Px.line, shade: Px.line, inset: true)
                    .padding(.top, Px.unit / 2)
                VStack(alignment: .leading, spacing: Px.unit) {
                    HStack(spacing: Px.unit) {
                        // Drawn for the same reason the checkbox above is: Pixelify Sans has no
                        // padlock either. See `PxGlyph`.
                        if value == .locked {
                            PxGlyph(.lock, height: 16, colour: mode == value ? Px.gold : Px.ink)
                        }
                        Text(title.uppercased()).font(.px(12, .black))
                            .foregroundStyle(mode == value ? Px.gold : Px.ink)
                    }
                    Text(line).font(.px(12)).foregroundStyle(Px.ink)
                    Text(detail).font(.px(10)).foregroundStyle(Px.dim)
                }
                Spacer(minLength: 0)
            }
            .padding(Px.unit * 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(mode == value ? Px.panel : Color.clear)
            .pxBevel(light: mode == value ? Px.panelLit : Px.line,
                     shade: mode == value ? Px.panelShade : Px.line, inset: mode != value)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mode-\(value.rawValue)")
    }

    private func armNow() {
        armed += 1
        controller.arm(name: chosen?.rawValue ?? "The guard",
                       pattern: plan.pattern(), selection: selection, mode: mode)
    }

    @State private var name = ""
    @State private var chosen: SaleKind?
    /// The whole "When" answer, in one value. See `SchedulePlan` for why it is not eight.
    @State private var plan = SchedulePlan()
    @State private var selection = FamilyActivitySelection()
    @State private var picking = false

    /// Bumped on arm, so `sensoryFeedback` has something to watch. Counters rather than booleans,
    /// because arming twice in a row must feel twice.
    @State private var armed = 0
    @State private var chose = 0

    /// Payday, mirrored out of `controller.payday` by `loadPayday()`.
    @State private var paydayShape = 0
    @State private var paydayDay = 25
    @State private var paydayAnchor = Date()

    private static let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
    private static let paydayShapes = ["Off", "Date", "Last day", "2 weeks"]

    /// How long "now" lasts, in hours. Three choices, not a slider: this is chosen in the ninety
    /// seconds before you would have opened a shopping app, and a slider is a decision.
    private static let nowOptions: [(String, Int)] = [("3 hours", 3), ("Tonight", 8), ("24 hours", 24)]

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
                            // Drawn, not typed — Pixelify Sans has no ▶ either. See `PxGlyph`.
                            PxGlyph(.play, height: 18, colour: Px.goldMetal)
                        }
                        .pxTapTarget()
                    }
                    .accessibilityIdentifier("chooseApps")
                }

                field("When") {
                    VStack(alignment: .leading, spacing: Px.unit * 3) {
                        segmented
                        scheduleControls
                    }
                }

                field("How serious is this one") { modePicker }

                Button(mode == .locked ? "Lock it" : "Arm it") {
                    // Locking is the one action in this app with no undo, so it is the one action
                    // that asks twice. Everything else is reversible and asks nothing.
                    if mode == .locked { confirmingLock = true } else { armNow() }
                }
                .buttonStyle(PxButtonStyle())
                .accessibilityIdentifier("armIt")
                .alert("Lock yourself out?", isPresented: $confirmingLock) {
                    Button("I know what I'm like") { armNow() }
                    Button("Not yet", role: .cancel) { }
                } message: {
                    Text("You won't be able to end this guard once it starts. It stands down on its own when the window is over.")
                }

                if let problem = controller.problem {
                    Text(problem).font(.px(11)).foregroundStyle(Px.alert)
                }

                Text("It arms itself and stands down on its own. You don't have to open this again.")
                    .font(.px(11)).foregroundStyle(Px.dim)

                Divider().overlay(Px.line)
                paydayCard
            }
        }
        .onAppear { loadPayday() }
        // The date field writes straight to the binding, so the setting is saved here rather than
        // in a button action like the other two shapes.
        .onChange(of: paydayAnchor) { _, _ in commitPayday() }
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
        plan.apply(sale)
    }

    private var segmented: some View {
        HStack(spacing: Px.unit / 2) {
            ForEach(SchedulePlan.Shape.allCases) { shape in
                Button { plan.shape = shape } label: {
                    Text(shape.title)
                        .font(.px(10, .black)).tracking(0.8).textCase(.uppercase)
                        .foregroundStyle(plan.shape == shape ? Px.bg : Px.dim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Px.unit * 2)
                        .background(plan.shape == shape ? Px.goldMetal : Px.panel)
                        .pxTapTarget()
                }
                .accessibilityIdentifier("kind\(shape.rawValue)")
            }
        }
    }

    @ViewBuilder
    private var scheduleControls: some View {
        switch plan.shape {
        case .now:
            VStack(alignment: .leading, spacing: Px.unit * 3) {
                Text("Shut them for").pxLabel(9).foregroundStyle(Px.dim)
                HStack(spacing: Px.unit) {
                    ForEach(Self.nowOptions, id: \.1) { label, hours in
                        Button { plan.nowHours = hours } label: {
                            Text(label.uppercased())
                                .font(.px(11, .black)).tracking(0.6)
                                .foregroundStyle(plan.nowHours == hours ? Px.bg : Px.dim)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Px.unit * 2)
                                .background(plan.nowHours == hours ? Px.goldMetal : Px.panel)
                                .pxTapTarget()
                        }
                        .accessibilityIdentifier("now\(hours)")
                    }
                }
                Text("Starts the second you arm it.")
                    .font(.px(10)).foregroundStyle(Px.dim)
            }
        case .once:
            VStack(alignment: .leading, spacing: Px.unit * 3) {
                Text("From").pxLabel(9).foregroundStyle(Px.dim)
                PxDateField(date: $plan.start)
                Text("Until").pxLabel(9).foregroundStyle(Px.dim)
                PxDateField(date: $plan.end, notBefore: plan.start)
            }
        case .weekly:
            HStack(spacing: Px.unit) {
                ForEach(1...7, id: \.self) { day in
                    Button {
                        if plan.weekdays.contains(day) { plan.weekdays.remove(day) }
                        else { plan.weekdays.insert(day) }
                    } label: {
                        Text(Self.dayLetters[day - 1])
                            .font(.px(12, .black))
                            .foregroundStyle(plan.weekdays.contains(day) ? Px.bg : Px.dim)
                            .frame(maxWidth: .infinity, minHeight: Px.unit * 9)
                            .background(plan.weekdays.contains(day) ? Px.goldMetal : Px.panel)
                            .pxTapTarget()
                    }
                    .accessibilityIdentifier("weekday\(day)")
                }
            }
            timeRow
        case .monthly:
            // A month grid. 31 always shown — a month without one simply never fires.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Px.unit), count: 7),
                      spacing: Px.unit) {
                ForEach(1...31, id: \.self) { day in
                    Button {
                        if plan.monthDays.contains(day) { plan.monthDays.remove(day) }
                        else { plan.monthDays.insert(day) }
                    } label: {
                        Text("\(day)")
                            .font(.px(11, .black))
                            .foregroundStyle(plan.monthDays.contains(day) ? Px.bg : Px.dim)
                            .frame(maxWidth: .infinity, minHeight: Px.unit * 8)
                            .background(plan.monthDays.contains(day) ? Px.goldMetal : Px.panel)
                            .pxTapTarget()
                    }
                    .accessibilityIdentifier("monthDay\(day)")
                }
            }
        case .doubleDates:
            Text("Every 1.1, 2.2, 3.3 … 11.11 and 12.12. Twelve sales a year, all day.")
                .font(.px(11)).foregroundStyle(Px.dim)
        case .daily:
            timeRow
        }
    }

    private var timeRow: some View {
        HStack(spacing: Px.unit * 3) {
            clockStepper("From", $plan.from)
            clockStepper("To", $plan.to)
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
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
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

    // MARK: - payday

    /// **A standing setting, below the form rather than inside it.**
    ///
    /// Payday is not part of the guard you are about to arm — it outlives every guard, and it shuts
    /// nothing by itself. It lives on this screen because this is the app's only setup surface, and
    /// because this is the screen you are on precisely when nothing is armed, which is the state
    /// the offer exists for. One setting does not earn a settings screen.
    private var paydayCard: some View {
        field("When your money lands") {
            VStack(alignment: .leading, spacing: Px.unit * 3) {
                paydayPicker
                paydayControls
                Text(paydayText).font(.px(10)).foregroundStyle(Px.dim)
            }
        }
    }

    private var paydayPicker: some View {
        HStack(spacing: Px.unit / 2) {
            ForEach(Array(Self.paydayShapes.enumerated()), id: \.offset) { i, title in
                Button { paydayShape = i; commitPayday() } label: {
                    Text(title)
                        .font(.px(10, .black)).tracking(0.8).textCase(.uppercase)
                        .foregroundStyle(paydayShape == i ? Px.bg : Px.dim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Px.unit * 2)
                        .background(paydayShape == i ? Px.goldMetal : Px.panel)
                        .pxTapTarget()
                }
                .accessibilityIdentifier("payday\(i)")
            }
        }
    }

    @ViewBuilder
    private var paydayControls: some View {
        switch paydayShape {
        case 1:
            // The same month grid as the Dates pattern above, single-select. A payday set to the
            // 31st still lands in February — see `Payday.upcoming`.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Px.unit), count: 7),
                      spacing: Px.unit) {
                ForEach(1...31, id: \.self) { day in
                    Button { paydayDay = day; commitPayday() } label: {
                        Text("\(day)")
                            .font(.px(11, .black))
                            .foregroundStyle(paydayDay == day ? Px.bg : Px.dim)
                            .frame(maxWidth: .infinity, minHeight: Px.unit * 8)
                            .background(paydayDay == day ? Px.goldMetal : Px.panel)
                            .pxTapTarget()
                    }
                    .accessibilityIdentifier("paydayDay\(day)")
                }
            }
        case 2:
            Text("The last Monday to Friday of the month. An end-of-month that falls on a weekend steps back to the Friday. Public holidays aren't known to this app.")
                .font(.px(10)).foregroundStyle(Px.dim)
        case 3:
            VStack(alignment: .leading, spacing: Px.unit * 2) {
                Text("Your last payday").pxLabel(9).foregroundStyle(Px.dim)
                PxDateField(date: $paydayAnchor)
            }
        default:
            Text("Nothing is scheduled and nothing is sent.")
                .font(.px(10)).foregroundStyle(Px.dim)
        }
    }

    /// Says exactly what will arrive and when, because that is the promise being made — including
    /// the case where nothing arrives at all.
    private var paydayText: String {
        guard let payday = controller.payday,
              let next = payday.nextNudge(after: Date()) else {
            return "Sale Armor sends nothing about payday until you set one here."
        }
        let when = next.formatted(.dateTime.day().month(.abbreviated))
        return "Next: \(when), \(Payday.nudgeHour):00. At most one notification: an offer to shut the apps if no guard is armed, or a silent \"blocked for payday\" if one already covers that evening. Never both, never a second."
    }

    private var paydaySetting: Payday? {
        switch paydayShape {
        case 1:  Payday(shape: .dayOfMonth(paydayDay))
        case 2:  Payday(shape: .lastWorkingDay)
        case 3:  Payday(shape: .fortnightly(anchor: paydayAnchor))
        default: nil
        }
    }

    private func commitPayday() { controller.setPayday(paydaySetting) }

    /// The stored setting drives the controls, never the other way round.
    private func loadPayday() {
        switch controller.payday?.shape {
        case let .dayOfMonth(day):     paydayShape = 1; paydayDay = day
        case .lastWorkingDay:          paydayShape = 2
        case let .fortnightly(anchor): paydayShape = 3; paydayAnchor = anchor
        case nil:                      paydayShape = 0
        }
    }
}

// MARK: - armed

private struct ArmedView: View {
    @State private var card: Image?

    /// What gets shared. Deliberately about the commitment rather than about the shopping — the
    /// version that names what you nearly bought is the version nobody sends.
    static func brag(_ window: ArmorWindow) -> String {
        let what = window.name.isEmpty ? "my shopping apps" : window.name.uppercased()
        return window.mode == .locked
            ? "I've locked \(what) with Sale Armor and I can't turn it off until it ends. ⚔️"
            : "\(what) is armed — my shopping apps are shut. ⚔️"
    }

    let window: ArmorWindow
    let shielding: Bool
    /// What the guard has been worth so far. Shown here rather than only on the wishlist, because
    /// this is the screen you open to check the shield is up — and the number is the reason to keep
    /// it up.
    let saved: Double
    /// Roughly what Sale Armor has cost so far. Nil while unknown, and the return stays hidden.
    let paid: Double?
    /// Shown because this screen can now be arrived at by tapping a payday offer, and an offer that
    /// could not be honoured — a locked guard is already running — must say so rather than do
    /// nothing.
    let problem: String?
    let onDisarm: () -> Void

    /// Standing down is a decision, not a mistake — a warning tone would scold. A soft impact
    /// just confirms the shield is gone.
    @State private var disarmed = 0

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// **True where the column has an iPhone's worth of room rather than an iPad's.**
    ///
    /// At full size this screen has to reach the saved figure and both buttons without a scroll:
    /// the number is the whole payoff, and the App Store screenshot only ever shows the launch
    /// position. On iPad it does; on a phone the column ran roughly 200pt past the fold and cut off
    /// mid-label. Compact in *either* axis catches all three tight cases — phone portrait, phone
    /// landscape, an iPad split-view column — where checking the device would catch none of them.
    private var tight: Bool { horizontalSizeClass == .compact || verticalSizeClass == .compact }

    var body: some View {
        // Centred while it fits, scrollable once it does not. See `PxCenteredScroll`.
        PxCenteredScroll {
            VStack(spacing: Px.unit * (tight ? 3 : 5)) {
                Spacer()
                SwordSprite(lit: shielding).frame(width: tight ? 180 : 340)

                // "Armed" and "On guard" are one word apart and the difference is the entire
                // product: one means the apps are shut right now, the other means they will be,
                // later. Read quickly, "Armed / waiting for the next window" looks exactly like
                // protection, and the apps opening then reads as the app being broken. So the
                // inactive state now says so outright, and says when it changes.
                Text(shielding ? "On guard" : "Not yet")
                    .font(.px(28, .black)).tracking(3)
                    .foregroundStyle(shielding ? Px.armor : Px.gold)

                HStack(spacing: Px.unit * 2) {
                    Text(window.name.uppercased()).pxLabel(13).foregroundStyle(Px.ink)
                    if window.mode == .locked {
                        HStack(spacing: Px.unit) {
                            PxGlyph(.lock, height: 12, colour: Px.gold)
                            Text("LOCKED").font(.px(9, .black)).tracking(0.6)
                                .foregroundStyle(Px.gold)
                        }
                        .padding(.horizontal, Px.unit).padding(.vertical, Px.unit / 2)
                        .background(Px.bg.opacity(0.75))
                    }
                }

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
                        // Only once it has actually paid for itself. Showing "0.4x" to someone who
                        // has not turned anything down yet would be an argument against the app.
                        if let paid, paid > 0, saved > paid {
                            Text("\(Self.money(paid)) spent on Sale Armor · \(Self.multiple(saved / paid)) back")
                                .font(.px(10)).foregroundStyle(Px.dim)
                                .accessibilityIdentifier("armedReturn")
                        }
                    }
                }

                // Sharing is the one social mechanism that survives this app's architecture, and it
                // is offered here rather than at the moment of folding — you press this while calm
                // and rather pleased with yourself, never at 1:47am. iOS owns the sheet, so Sale
                // Armor never learns who it went to and no contact ever touches the app.
                // An image, not a line of text. A picture is what actually gets posted, and the card
                // carries the same sword the shield does so the two read as one object.
                ShareLink(item: card ?? Image(systemName: "shield"),
                          message: Text(Self.brag(window)),
                          preview: SharePreview("Sale Armor", image: card ?? Image(systemName: "shield"))) {
                    Text(window.mode == .locked ? "Tell someone I'm locked out" : "Tell someone")
                        .font(.px(12, .black)).foregroundStyle(Px.gold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Px.unit * 3)
                        .pxBevel(light: Px.line, shade: Px.line, inset: true)
                }
                .accessibilityIdentifier("tellSomeone")
                .disabled(card == nil)
                .task(id: window) {
                    card = Image(uiImage: ShareCard.image(window: window, saved: saved,
                                                          currency: Self.currencySymbol))
                }

                if window.mode == .locked, !window.canDisarm() {
                    // No disabled button. A greyed-out control invites tapping it repeatedly to find
                    // out why; this states the decision instead, in the words it was made in.
                    VStack(spacing: Px.unit) {
                        HStack(spacing: Px.unit) {
                            PxGlyph(.lock, height: 16, colour: Px.gold)
                            Text("LOCKED").font(.px(12, .black)).foregroundStyle(Px.gold)
                        }
                        Text("You asked not to be able to end this one early.")
                            .font(.px(10)).foregroundStyle(Px.dim)
                            .multilineTextAlignment(.center)
                        // The release moment, because "locked" with no end reads as a trap. It is
                        // read from the window rather than recomputed, so this line and `canDisarm`
                        // can never disagree about when it lifts.
                        if let until = window.lockedUntil {
                            Text("Lifts at \(ArmorController.lockText(until))")
                                .font(.px(10)).foregroundStyle(Px.gold)
                                .multilineTextAlignment(.center)
                                .accessibilityIdentifier("lockedUntil")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Px.unit * 3)
                    .accessibilityIdentifier("lockedNotice")
                } else {
                    Button("Disarm") { disarmed += 1; onDisarm() }
                    .buttonStyle(PxButtonStyle(tint: Px.panel, text: Px.alert))
                    .accessibilityIdentifier("disarm")
                }

                if let problem {
                    Text(problem).font(.px(11)).foregroundStyle(Px.alert)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("armedProblem")
                }

                Text(shielding ? "Nothing to do. Close this."
                               : "Your apps are open right now. \(Self.startsText(window.pattern))")
                    .font(.px(11)).foregroundStyle(Px.dim)
                Spacer()
            }
            .sensoryFeedback(.impact(weight: .light), trigger: disarmed)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).pxLabel(10).foregroundStyle(Px.dim)
            Spacer()
            Text(value).font(.px(13, .black)).foregroundStyle(Px.ink)
        }
    }

    /// When the shield next goes up, in the words the user set it in.
    static func startsText(_ pattern: ArmorPattern) -> String {
        switch pattern {
        case let .daily(from, _):     return "This guard shuts them at \(from.text)."
        case let .weekly(_, from, _): return "This guard shuts them at \(from.text) on the days you picked."
        case .monthly:                return "This guard shuts them on the dates you picked."
        case .doubleDates:            return "This guard shuts them on the next double-date sale."
        case .dateRange:              return "This guard shuts them when the dates you picked begin."
        }
    }

    private static func money(_ amount: Double) -> String {
        amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    /// Just the symbol, for the share card — which draws its own number in the pixel font and only
    /// needs to know what to put in front of it.
    static var currencySymbol: String {
        (Locale.current.currencySymbol ?? "$") + " "
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
    /// Which park-form field holds the caret, so the form can be scrolled clear of the keyboard.
    @FocusState private var focused: Field?

    private enum Field { case name, link, price }

    /// The scroll target for `focused`. The button, not the form: the button is what the keyboard
    /// covers, and scrolling to the form would leave it exactly where it was.
    private static let parkButtonID = "park-it-button"

    var body: some View {
        // The price field opens a decimal pad, which has no return key — so the keyboard stays up
        // and sits over the Park It button directly beneath it. Dragging the list now puts it away,
        // which is the gesture people already try when a keyboard is in the way.
        //
        // Dragging is not enough on its own. In landscape the keyboard takes over half the screen:
        // the scroll viewport ends at y 450 while the button runs to y 502, so the one control the
        // form exists for is off the bottom the moment you start typing, and nothing on screen says
        // it is there. So focusing any field scrolls it into view — see `focused` below.
        ScrollViewReader { scroll in
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
        .scrollDismissesKeyboard(.interactively)
        // After the keyboard, not before it: the scroll offset is clamped to the viewport as it is
        // at the moment this runs, and on focus the viewport has not shrunk yet. One runloop turn
        // later it has, and the button can actually be brought up.
        .onChange(of: focused) { _, field in
            guard field != nil else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation { scroll.scrollTo(Self.parkButtonID, anchor: .bottom) }
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
                // `pxTapTarget` on the field itself, not on a label: a text field is its own
                // control, and 22pt of it is a third of what a fingertip needs.
                TextField("", text: $name,
                          prompt: Text("What were you about to buy?").foregroundColor(Px.dim))
                    .font(.px(14, .black)).foregroundStyle(Px.ink).textFieldStyle(.plain)
                    .pxTapTarget()
                    .focused($focused, equals: .name)
                    .accessibilityIdentifier("wishName")
                TextField("", text: $link, prompt: Text("Link (optional)").foregroundColor(Px.dim))
                    .font(.px(12)).foregroundStyle(Px.dim).textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .pxTapTarget()
                    .focused($focused, equals: .link)
                    .accessibilityIdentifier("wishLink")
                TextField("", text: $price, prompt: Text("Price").foregroundColor(Px.dim))
                    .font(.px(14, .black)).foregroundStyle(Px.ink).textFieldStyle(.plain)
                    .keyboardType(.decimalPad)
                    .pxTapTarget()
                    .focused($focused, equals: .price)
                    .accessibilityIdentifier("wishPrice")
                Button("Park it") {
                    controller.addWish(name: name, link: link, price: Double(price) ?? 0)
                    name = ""; link = ""; price = ""
                    focused = nil
                }
                .buttonStyle(PxButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("parkIt")
                .id(Self.parkButtonID)

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
            if let link = item.link {
                let text = Text(link).font(.px(10)).foregroundStyle(Px.dim)
                // Only what a browser can open becomes a link. The rest stays readable text.
                if let url = item.linkURL {
                    Link(destination: url) { text.lineLimit(1).pxTapTarget() }
                        .accessibilityIdentifier("wish-link")
                } else {
                    text.lineLimit(1)
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
