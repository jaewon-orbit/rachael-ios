//
//  RachaelStackView.swift
//  Rachael
//

import SwiftUI

struct RachaelStackView: View {
    @Binding var subscriptions: [Subscription]

    @State private var draggingSubscriptionID: UUID?
    @State private var dragOriginIndex: Int?
    @State private var dragVisualOffset: CGFloat = 0

    private let bottomBarClearance: CGFloat = 110
    private let rowStride: CGFloat = 72

    private var totalAnnual: Double {
        subscriptions.reduce(0) { partial, subscription in
            partial + annualAmount(for: subscription)
        }
    }

    private var currentCurrency: String {
        subscriptions.first?.currency ?? "$ USD"
    }

    private var totalAnnualFormatted: String {
        format(amount: totalAnnual, currency: currentCurrency)
    }

    var body: some View {
        VStack(spacing: 0) {
            stackHeader

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(Array(subscriptions.enumerated()), id: \.element.id) { index, subscription in
                        SubscriptionCardRow(
                            subscription: subscription,
                            isDragging: draggingSubscriptionID == subscription.id,
                            dragOffset: draggingSubscriptionID == subscription.id ? dragVisualOffset : 0
                        )
                        .gesture(reorderGesture(for: subscription, startingAt: index))
                        .zIndex(draggingSubscriptionID == subscription.id ? 1 : 0)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
            .background(Color.tyrell.background)

            summaryBar

            averageRow

            Color.clear
                .frame(height: bottomBarClearance)
        }
        .background(Color.tyrell.background.ignoresSafeArea())
    }

    private var stackHeader: some View {
        HStack(spacing: 10) {
            Text("// SUBSCRIPTION STACK //")
                .font(.custom("Courier New", size: 11))
                .foregroundColor(Color.tyrell.esper.opacity(0.7))
                .tracking(2)

            Rectangle()
                .fill(Color.tyrell.esper.opacity(0.25))
                .frame(height: 1)
        }
        .padding(.horizontal, 16)
        .frame(height: 42)
        .overlay(
            Rectangle()
                .fill(Color.tyrell.esper.opacity(0.18))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var summaryBar: some View {
        HStack(spacing: 12) {
            Text(currentCurrency)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(subscriptions.count) UNITS")
                .frame(maxWidth: .infinity, alignment: .center)

            Text(totalAnnualFormatted)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.custom("Courier New", size: 11).weight(.bold))
        .foregroundColor(Color.tyrell.primary)
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color(hex: "#141820"))
        .overlay(
            Rectangle()
                .fill(Color.tyrell.esper.opacity(0.22))
                .frame(height: 1),
            alignment: .top
        )
    }

    private var averageRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("AVERAGE EXPENSES")
                    .font(.custom("Courier New", size: 12).weight(.bold))
                    .foregroundColor(Color.tyrell.primary)
                    .tracking(1.4)

                Text("PER YEAR")
                    .font(.custom("Courier New", size: 9))
                    .foregroundColor(Color.tyrell.esper.opacity(0.75))
                    .tracking(1.5)
            }

            Spacer()

            Text(totalAnnualFormatted)
                .font(.custom("Courier New", size: 18).weight(.bold))
                .foregroundColor(Color.tyrell.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .background(Color(hex: "#141820"))
        .overlay(
            Rectangle()
                .fill(Color.tyrell.esper.opacity(0.18))
                .frame(height: 1),
            alignment: .top
        )
    }

    private func reorderGesture(for subscription: Subscription, startingAt index: Int) -> some Gesture {
        LongPressGesture(minimumDuration: 0.24)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .first(true):
                    beginDragging(subscription: subscription, index: index)
                case .second(true, let drag?):
                    beginDragging(subscription: subscription, index: index)
                    dragVisualOffset = drag.translation.height
                    updateDragOrder(for: subscription, translation: drag.translation.height)
                default:
                    break
                }
            }
            .onEnded { _ in
                draggingSubscriptionID = nil
                dragOriginIndex = nil
                dragVisualOffset = 0
            }
    }

    private func beginDragging(subscription: Subscription, index: Int) {
        guard draggingSubscriptionID == nil else { return }
        draggingSubscriptionID = subscription.id
        dragOriginIndex = index
    }

    private func updateDragOrder(for subscription: Subscription, translation: CGFloat) {
        guard let origin = dragOriginIndex,
              let currentIndex = subscriptions.firstIndex(where: { $0.id == subscription.id }) else { return }

        let rowDelta = Int(translation / (rowStride * 1.18))
        let destination = min(max(origin + rowDelta, 0), subscriptions.count - 1)
        guard destination != currentIndex else { return }

        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            let item = subscriptions.remove(at: currentIndex)
            subscriptions.insert(item, at: destination)
        }
    }

    private func annualAmount(for subscription: Subscription) -> Double {
        let interval = Double(max(1, subscription.cycleInterval))
        switch subscription.cycleUnit {
        case .daily:
            return subscription.amount * (365 / interval)
        case .weekly:
            return subscription.amount * (52 / interval)
        case .monthly:
            return subscription.amount * (12 / interval)
        case .yearly:
            return subscription.amount / interval
        }
    }

    private func format(amount: Double, currency: String) -> String {
        let rounded = Int(amount.rounded())
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formatted = formatter.string(from: NSNumber(value: rounded)) ?? "\(rounded)"
        return "\(currency)  \(formatted)"
    }
}

struct SubscriptionCardRow: View {
    let subscription: Subscription
    let isDragging: Bool
    let dragOffset: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            iconView

            HStack(spacing: 8) {
                Text(subscription.name)
                    .font(.custom("Courier New", size: 16).weight(.bold))
                    .foregroundColor(Color.tyrell.primary)
                    .tracking(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                Spacer(minLength: 6)

                HStack(spacing: 7) {
                    Text(currencyText)
                        .font(.custom("Courier New", size: 10).weight(.bold))
                        .foregroundColor(Color.tyrell.esper.opacity(0.7))
                        .tracking(0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(amountValueText)
                        .font(.custom("Courier New", size: 16).weight(.bold))
                        .foregroundColor(Color.tyrell.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }

            if let cycleText {
                Text(cycleText)
                    .font(.custom("Courier New", size: 8).weight(.bold))
                    .foregroundColor(Color.tyrell.esper.opacity(0.7))
                    .tracking(1.1)
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 64)
        .background(
            ZStack {
                Color(hex: "#141820")
                ScanlineOverlay()
                    .opacity(0.45)
            }
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.tyrell.esper.opacity(0.65))
                .frame(width: 3)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.tyrell.esper.opacity(isDragging ? 0.75 : 0.28), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .offset(y: dragOffset)
        .scaleEffect(isDragging ? 1.015 : 1)
        .shadow(color: Color.tyrell.esper.opacity(isDragging ? 0.22 : 0), radius: 8)
        .contentShape(Rectangle())
    }

    private var iconView: some View {
        ZStack {
            Rectangle()
                .stroke(Color.tyrell.esper.opacity(0.5), lineWidth: 1)

            if let iconName = subscription.iconName {
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.tyrell.esper.opacity(0.85))
            } else {
                Text(String(subscription.name.prefix(1)))
                    .font(.custom("Courier New", size: 16).weight(.bold))
                    .foregroundColor(Color.tyrell.esper.opacity(0.85))
            }
        }
        .frame(width: 34, height: 34)
    }

    private var currencyText: String {
        subscription.currency
    }

    private var amountValueText: String {
        let rounded = Int(subscription.amount.rounded())
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: rounded)) ?? "\(rounded)"
    }

    private var cycleText: String? {
        guard subscription.cycleUnit != .monthly || subscription.cycleInterval != 1 else { return nil }
        let unit: String
        switch subscription.cycleUnit {
        case .daily:
            unit = subscription.cycleInterval == 1 ? "DAY" : "DAYS"
        case .weekly:
            unit = subscription.cycleInterval == 1 ? "WEEK" : "WEEKS"
        case .monthly:
            unit = subscription.cycleInterval == 1 ? "MONTH" : "MONTHS"
        case .yearly:
            unit = subscription.cycleInterval == 1 ? "YEAR" : "YEARS"
        }
        return "\(subscription.cycleInterval) \(unit)"
    }
}

#Preview {
    RachaelStackView(subscriptions: .constant(Subscription.sampleData))
        .preferredColorScheme(.dark)
}
