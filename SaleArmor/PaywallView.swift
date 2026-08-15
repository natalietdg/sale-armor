import SwiftUI
import RevenueCat

/// The gate. Nothing in Sale Armor is reachable until something here is bought.
///
/// Everything App Review requires for an auto-renewing subscription is on this one screen, because
/// a missing piece is a rejection rather than a note: the price, the period, what renewal means,
/// a restore control, and links to the terms and the privacy policy.
struct PaywallView: View {
    @ObservedObject var subscription: Subscription
    @State private var chosen: Package?

    private static let terms = URL(string: "https://salearmor.pages.dev/terms")!
    private static let privacy = URL(string: "https://salearmor.pages.dev/privacy")!

    var body: some View {
        ScrollView {
            VStack(spacing: Px.unit * 5) {
                SwordSprite(lit: true).frame(width: 260)

                VStack(spacing: Px.unit * 2) {
                    Text("Sale Armor").font(.px(28, .black)).tracking(3).foregroundStyle(Px.ink)
                    Text("You know your patterns.")
                        .font(.px(13, .black)).foregroundStyle(Px.goldMetal)
                }

                PxPanel {
                    VStack(alignment: .leading, spacing: Px.unit * 3) {
                        promise("Shut the shopping apps on the days you overspend")
                        promise("Payday, late night, 11.11 — armed on a schedule")
                        promise("Park what you wanted and count what you didn't spend")
                    }
                }

                packages

                Button(buyTitle) { Task { await buy() } }
                    .buttonStyle(PxButtonStyle())
                    .disabled(chosen == nil || subscription.isWorking)
                    .opacity(chosen == nil ? 0.5 : 1)

                if let problem = subscription.problem {
                    Text(problem).font(.px(11)).foregroundStyle(Px.alert)
                        .multilineTextAlignment(.center)
                }

                Text(renewalTerms)
                    .font(.px(10)).foregroundStyle(Px.dim)
                    .multilineTextAlignment(.center)

                HStack(spacing: Px.unit * 4) {
                    Button("Restore") { Task { await subscription.restore() } }
                    Link("Terms", destination: Self.terms)
                    Link("Privacy", destination: Self.privacy)
                }
                .font(.px(11)).foregroundStyle(Px.dim)
            }
            .padding(.vertical, Px.unit * 6)
        }
        .task {
            await subscription.start()
            // Weekly is pre-selected on purpose — it is the plan meant to sell, and the option
            // already ticked is the single strongest lever on this screen.
            chosen = subscription.offering?.weekly ?? subscription.offering?.availablePackages.first
        }
    }

    // MARK: pieces

    private func promise(_ line: String) -> some View {
        HStack(alignment: .top, spacing: Px.unit * 2) {
            Text("+").font(.px(13, .black)).foregroundStyle(Px.goldMetal)
            Text(line).font(.px(12)).foregroundStyle(Px.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Explicit order, cheapest first, rather than whatever order the offering happens to arrive
    /// in. Position is doing work here — the monthly plan is the one meant to sell, so it sits at
    /// the top where the eye lands and where the pre-selection already is.
    private var ordered: [Package] {
        let rank: [PackageType: Int] = [.weekly: 0, .monthly: 1, .annual: 2, .lifetime: 3]
        return (subscription.offering?.availablePackages ?? [])
            .sorted { rank[$0.packageType, default: 9] < rank[$1.packageType, default: 9] }
    }

    @ViewBuilder
    private var packages: some View {
        if !ordered.isEmpty {
            let packages = ordered
            VStack(spacing: Px.unit * 2) {
                ForEach(packages, id: \.identifier) { package in
                    Button { chosen = package } label: {
                        HStack {
                            Text(period(package))
                                .font(.px(13, .black))
                                .foregroundStyle(chosen == package ? Px.bg : Px.ink)
                            Spacer()
                            Text(package.storeProduct.localizedPriceString)
                                .font(.px(15, .black))
                                .foregroundStyle(chosen == package ? Px.bg : Px.goldMetal)
                        }
                        .padding(Px.unit * 3)
                        .background(chosen == package ? Px.goldMetal : Px.panel)
                        .overlay(Rectangle().strokeBorder(
                            chosen == package ? Px.goldShine : Px.line, lineWidth: Px.unit / 2))
                    }
                    .accessibilityIdentifier("package-\(package.identifier)")
                }
            }
        } else {
            Text("Loading…").font(.px(12)).foregroundStyle(Px.dim)
        }
    }

    private var buyTitle: String { subscription.isWorking ? "Working…" : "Arm yourself" }

    private func period(_ package: Package) -> String {
        switch package.packageType {
        case .annual:   "Every year"
        case .monthly:  "Every month"
        case .weekly:   "Every week"
        case .lifetime: "Once, forever"
        default:        package.storeProduct.localizedTitle
        }
    }

    /// Apple requires the renewal mechanics in the binary, not only in the App Store metadata —
    /// and requires them to be *true*, which is why lifetime gets its own sentence rather than
    /// sitting under a blanket claim that everything renews.
    private var renewalTerms: String {
        if chosen?.packageType == .lifetime {
            return "One payment. Nothing renews, nothing to cancel."
        }
        return """
        Renews automatically until cancelled. Cancel any time in Settings, \
        at least a day before the period ends.
        """
    }

    private func buy() async {
        guard let chosen else { return }
        await subscription.buy(chosen)
    }
}
