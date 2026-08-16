import SwiftUI
import RevenueCat

/// One row on the paywall, already turned into the strings it will draw.
///
/// The view deliberately does not read `Package` directly. Pulling the formatting up here means the
/// layout can be seen and judged before RevenueCat is connected, and it keeps the price arithmetic —
/// which is the part that must not be wrong — in one place instead of scattered through the body.
struct Plan: Identifiable, Equatable {
    let id: String
    /// "Every week". What is actually being bought.
    let term: String
    /// "$3.99", straight from the store so the currency is always the customer's.
    let price: String
    /// "57¢ a day" — the same money at a scale a person can picture.
    let unit: String
    let badge: String?
    let renews: Bool
    let package: Package?

    /// The store's product id, so an active entitlement can be matched back to the plan it is on.
    let productID: String
    /// The price as a number. Kept alongside `price` because the displayed string is localised and
    /// cannot be done arithmetic on.
    let amount: Double?
    /// How long one period lasts. Nil for lifetime, which has no period.
    let periodDays: Double?

    static func == (a: Plan, b: Plan) -> Bool { a.id == b.id }
}

/// The gate. Nothing in Sale Armor is reachable until something here is bought.
///
/// Everything App Review requires for a subscription is on this one screen, because a missing piece
/// is a rejection rather than a note: price, period, what renewal means, a restore control, and
/// links to the terms and the privacy policy.
struct PaywallView: View {
    @ObservedObject var subscription: Subscription
    @State private var chosen: Plan?

    private static let terms = URL(string: "https://salearmor.pages.dev/terms")!
    private static let privacy = URL(string: "https://salearmor.pages.dev/privacy")!

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Px.unit * 4) {
                    header
                    promises
                    plans
                }
                .padding(.top, Px.unit * 2)
                .padding(.bottom, Px.unit * 4)
            }
            // The buy button never scrolls away. With four plans the page is taller than the
            // screen, and a call to action below the fold is a call to action nobody sees.
            buyBar
        }
        .task { await load() }
    }

    // MARK: the pitch

    private var header: some View {
        VStack(spacing: Px.unit * 2) {
            SwordSprite(lit: true).frame(width: 170)
            Text("Sale Armor").font(.px(26, .black)).tracking(3).foregroundStyle(Px.ink)
            Text("You know your patterns.")
                .font(.px(13, .black)).foregroundStyle(Px.goldMetal)
        }
    }

    private var promises: some View {
        VStack(alignment: .leading, spacing: Px.unit * 2) {
            promise("Shut the shopping apps before you can open them")
            promise("Payday, late night, 11.11 — armed on a schedule")
            promise("Track how much you saved, to the last cent")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func promise(_ line: String) -> some View {
        HStack(alignment: .top, spacing: Px.unit * 2) {
            Text("+").font(.px(13, .black)).foregroundStyle(Px.goldMetal)
            Text(line).font(.px(12)).foregroundStyle(Px.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: the plans

    @ViewBuilder
    private var plans: some View {
        if subscription.plans.isEmpty {
            Text(subscription.problem == nil ? "Loading…" : "")
                .font(.px(12)).foregroundStyle(Px.dim)
                .padding(.vertical, Px.unit * 6)
        } else {
            VStack(spacing: Px.unit * 2) {
                ForEach(subscription.plans) { plan in
                    Button { chosen = plan } label: { row(plan) }
                        .accessibilityIdentifier("plan-\(plan.id)")
                }
            }
        }
    }

    private func row(_ plan: Plan) -> some View {
        let on = chosen == plan
        return HStack(spacing: Px.unit * 3) {
            // A filled square rather than a tick: the selected state has to read at a glance on a
            // screen where every option looks alike, and a checkmark is not in this alphabet.
            ZStack {
                Rectangle().strokeBorder(on ? Px.bg : Px.line, lineWidth: Px.unit / 2)
                if on { Rectangle().fill(Px.bg).padding(Px.unit) }
            }
            .frame(width: Px.unit * 5, height: Px.unit * 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(plan.term).font(.px(13, .black))
                    .foregroundStyle(on ? Px.bg : Px.ink)
                Text(plan.unit).font(.px(10))
                    .foregroundStyle(on ? Px.bg.opacity(0.7) : Px.dim)
            }

            Spacer(minLength: Px.unit)

            if let badge = plan.badge {
                Text(badge)
                    .font(.px(9, .black)).tracking(0.8)
                    .foregroundStyle(on ? Px.goldMetal : Px.bg)
                    .padding(.horizontal, Px.unit * 1.5).padding(.vertical, Px.unit / 2)
                    .background(on ? Px.bg : Px.goldMetal)
            }

            Text(plan.price).font(.px(15, .black))
                .foregroundStyle(on ? Px.bg : Px.goldMetal)
        }
        .padding(Px.unit * 3)
        .background(on ? Px.goldMetal : Px.panel)
        .overlay(Rectangle().strokeBorder(on ? Px.goldShine : Px.line, lineWidth: Px.unit / 2))
    }

    // MARK: the ask

    private var buyBar: some View {
        VStack(spacing: Px.unit * 2) {
            Button(subscription.isWorking ? "Working…" : "Arm yourself") {
                Task { if let chosen { await subscription.buy(chosen) } }
            }
            .buttonStyle(PxButtonStyle())
            .disabled(chosen == nil || subscription.isWorking)
            .opacity(chosen == nil ? 0.5 : 1)

            if let problem = subscription.problem {
                Text(problem).font(.px(11)).foregroundStyle(Px.alert)
                    .multilineTextAlignment(.center)
            }

            Text(renewalTerms)
                .font(.px(9)).foregroundStyle(Px.dim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Px.unit * 4) {
                Button("Restore") { Task { await subscription.restore() } }
                Link("Terms", destination: Self.terms)
                Link("Privacy", destination: Self.privacy)
            }
            .font(.px(10)).foregroundStyle(Px.dim)
        }
        .padding(.top, Px.unit * 3)
        .padding(.bottom, Px.unit * 2)
        .background(Px.bg.opacity(0.92))
        .overlay(alignment: .top) { Rectangle().fill(Px.line).frame(height: Px.unit / 2) }
    }

    /// Apple requires the renewal mechanics in the binary, not only in the App Store metadata — and
    /// requires them to be *true*, which is why lifetime gets its own sentence rather than sitting
    /// under a blanket claim that everything renews.
    private var renewalTerms: String {
        guard chosen?.renews != false else { return "One payment. Nothing renews, nothing to cancel." }
        return "Renews automatically until cancelled. Cancel any time in Settings."
    }

    private func load() async {
        await subscription.start()
        // Weekly is pre-selected on purpose — it is the plan meant to sell, and the option already
        // ticked is the single strongest lever on this screen.
        chosen = subscription.plans.first
    }
}
