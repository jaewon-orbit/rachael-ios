//
//  RachaelSubscriptionSlider.swift
//  Rachael
//

import SwiftUI

struct RachaelSubscriptionSlider: View {
    let selectedDate: Date?

    @Binding var name: String
    @Binding var amount: String
    @Binding var currency: String
    @Binding var note: String
    @Binding var cycle: String
    @Binding var duration: String
    @Binding var reminder: String
    @Binding var firstBill: String
    @Binding var showMoreOptions: Bool
    @Binding var bracketContentHeight: CGFloat

    @State private var measuredHeaderHeight: CGFloat = 0

    let onAdd: () -> Void
    let onDismiss: () -> Void
    let onHandleTap: () -> Void
    let onFoldOptions: () -> Void

    private struct CurrencyOption: Identifiable {
        let code: String
        let symbol: String
        let country: String

        var id: String { code }
        var displayValue: String { "\(symbol) \(code)" }
    }

    private let currencies = [
        CurrencyOption(code: "USD", symbol: "$", country: "United States"),
        CurrencyOption(code: "KRW", symbol: "₩", country: "South Korea"),
        CurrencyOption(code: "EUR", symbol: "€", country: "Eurozone"),
        CurrencyOption(code: "GBP", symbol: "£", country: "United Kingdom"),
        CurrencyOption(code: "JPY", symbol: "¥", country: "Japan"),
        CurrencyOption(code: "CNY", symbol: "¥", country: "China"),
        CurrencyOption(code: "CAD", symbol: "C$", country: "Canada"),
        CurrencyOption(code: "AUD", symbol: "A$", country: "Australia"),
        CurrencyOption(code: "NZD", symbol: "NZ$", country: "New Zealand"),
        CurrencyOption(code: "CHF", symbol: "CHF", country: "Switzerland"),
        CurrencyOption(code: "SEK", symbol: "kr", country: "Sweden"),
        CurrencyOption(code: "NOK", symbol: "kr", country: "Norway"),
        CurrencyOption(code: "DKK", symbol: "kr", country: "Denmark"),
        CurrencyOption(code: "SGD", symbol: "S$", country: "Singapore"),
        CurrencyOption(code: "HKD", symbol: "HK$", country: "Hong Kong"),
        CurrencyOption(code: "INR", symbol: "₹", country: "India"),
        CurrencyOption(code: "BRL", symbol: "R$", country: "Brazil"),
        CurrencyOption(code: "MXN", symbol: "MX$", country: "Mexico")
    ]

    private var formattedDate: String {
        guard let selectedDate else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: selectedDate).uppercased()
    }

    private var selectedCurrency: CurrencyOption {
        currencies.first { $0.displayValue == currency }
        ?? currencies.first { $0.symbol == currency }
        ?? currencies[0]
    }

    private var bracketRowsHeight: CGFloat {
        let collapsedRowsHeight: CGFloat = 273
        let expandedRowsHeight: CGFloat = 181
        return collapsedRowsHeight + (showMoreOptions ? expandedRowsHeight : 0)
    }

    private func updateBracketContentHeight() {
        bracketContentHeight = measuredHeaderHeight + 1 + bracketRowsHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .background(SliderHeightReader(height: $measuredHeaderHeight))

            EsperDivider()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    amountRow

                    EsperDivider()

                    SliderFieldRow(label: "NAME") {
                        TextField(
                            text: $name,
                            prompt: Text("ENTER DESIGNATION_")
                                .foregroundColor(Color.tyrell.esper.opacity(0.3))
                        ) { EmptyView() }
                            .font(.custom("Courier New", size: 13))
                            .foregroundColor(Color.white)
                            .tint(Color.tyrell.esper)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.characters)
                    }

                    EsperDivider()

                    SliderFieldRow(label: "DESC") {
                        TextField(
                            text: $note,
                            prompt: Text("OPTIONAL_")
                                .foregroundColor(Color.tyrell.esper.opacity(0.3))
                        ) { EmptyView() }
                            .font(.custom("Courier New", size: 13))
                            .foregroundColor(Color.white)
                            .tint(Color.tyrell.esper)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.characters)
                    }

                    EsperDivider()

                    SliderNavRow(label: "CATEGORY", value: "NONE")

                    EsperDivider()

                    SliderNavRow(label: "COLOR") {
                        HStack(spacing: 6) {
                            ForEach(["#D90404", "#00FF00", "#D9D9D9", "#0066FF", "#FF9900"], id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 12, height: 12)
                            }
                        }
                    }

                    EsperDivider()

                    moreOptionsButton

                    if showMoreOptions {
                        expandedOptions
                    }
                }
                .padding(.bottom, 96)
            }
        }
        .onAppear(perform: updateBracketContentHeight)
        .onChange(of: measuredHeaderHeight) { _, _ in
            updateBracketContentHeight()
        }
        .onChange(of: showMoreOptions) { _, _ in
            updateBracketContentHeight()
        }
        .background(Color(hex: "#141820"))
        .overlay(
            Rectangle()
                .fill(Color.tyrell.esper.opacity(0.35))
                .frame(height: 1),
            alignment: .top
        )
    }

    private var header: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.tyrell.esper.opacity(0.35))
                .frame(width: 32, height: 4)
                .padding(.top, 10)
                .frame(width: 96, height: 28)
                .contentShape(Rectangle())
                .onTapGesture(perform: onHandleTap)

            HStack {
                Button(action: onDismiss) {
                    Text("CANCEL")
                        .font(.custom("Courier New", size: 11))
                        .foregroundColor(Color.tyrell.esper.opacity(0.65))
                        .tracking(2)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 2) {
                    Text("// NEW SUBSCRIPTION //")
                        .font(.custom("Courier New", size: 10))
                        .foregroundColor(Color.tyrell.esper.opacity(0.65))
                        .tracking(2)

                    Text(formattedDate)
                        .font(.custom("Courier New", size: 9))
                        .foregroundColor(Color.tyrell.esper.opacity(0.6))
                        .tracking(1.5)
                }

                Spacer()

                Button(action: onAdd) {
                    Text("ADD")
                        .font(.custom("Courier New", size: 11).weight(.bold))
                        .foregroundColor(name.isEmpty ? Color.tyrell.disabled : Color.tyrell.esper)
                        .tracking(2)
                }
                .buttonStyle(.plain)
                .disabled(name.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.top, 0)
            .padding(.bottom, 10)
        }
    }

    private var amountRow: some View {
        HStack(spacing: 0) {
            currencyPicker

            EsperVerticalDivider()
                .frame(height: 28)

            TextField(
                text: $amount,
                prompt: Text("0.00")
                    .foregroundColor(Color.tyrell.esper.opacity(0.3))
            ) { EmptyView() }
                .font(.custom("Courier New", size: 24).weight(.bold))
                .foregroundColor(Color.white)
                .tint(Color.tyrell.esper)
                .keyboardType(.decimalPad)
                .padding(.horizontal, 14)
        }
        .frame(height: 52)
    }

    private var currencyPicker: some View {
        Menu {
            ForEach(currencies) { option in
                Button {
                    currency = option.displayValue
                } label: {
                    Text("\(option.displayValue)  \(option.country)")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedCurrency.displayValue)
                    .font(.custom("Courier New", size: 16).weight(.bold))
                    .foregroundColor(Color.tyrell.esper)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.tyrell.esper.opacity(0.65))
            }
            .frame(width: 104, height: 36)
            .background(Color.tyrell.esper.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private var moreOptionsButton: some View {
        Button {
            let shouldExpand = !showMoreOptions
            withAnimation(.linear(duration: 0.18)) {
                showMoreOptions.toggle()
            }
            if shouldExpand {
                onHandleTap()
            } else {
                onFoldOptions()
            }
        } label: {
            HStack {
                Spacer()

                Text(showMoreOptions ? "FEWER OPTIONS" : "MORE OPTIONS")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.tyrell.esper.opacity(0.65))
                    .tracking(3)

                Image(systemName: showMoreOptions ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9))
                    .foregroundColor(Color.tyrell.esper.opacity(0.65))

                Spacer()
            }
            .frame(height: 40)
        }
        .buttonStyle(.plain)
    }

    private var expandedOptions: some View {
        VStack(spacing: 0) {
            EsperDivider()

            SliderFieldRow(label: "FIRST BILL") {
                TextField(
                    text: $firstBill,
                    prompt: Text("ENTER DATE_")
                        .foregroundColor(Color.tyrell.esper.opacity(0.3))
                ) { EmptyView() }
                    .font(.custom("Courier New", size: 13))
                    .foregroundColor(Color.white)
                    .tint(Color.tyrell.esper)
                    .multilineTextAlignment(.trailing)
            }

            EsperDivider()

            SliderNavRow(label: "CYCLE", value: cycle)

            EsperDivider()

            SliderNavRow(label: "DURATION", value: duration)

            EsperDivider()

            SliderNavRow(label: "REMIND ME", value: reminder)

            EsperDivider()
        }
    }
}

struct SliderHeightReader: View {
    @Binding var height: CGFloat

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    height = geo.size.height
                }
                .onChange(of: geo.size.height) { _, newValue in
                    height = newValue
                }
        }
    }
}

struct SliderFieldRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.tyrell.esper.opacity(0.65))
                .tracking(2)
                .frame(width: 80, alignment: .leading)

            Spacer()

            content
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
    }
}

struct SliderNavRow<Trailing: View>: View {
    let label: String
    let value: String?
    @ViewBuilder let trailing: Trailing

    init(label: String, @ViewBuilder trailing: () -> Trailing) {
        self.label = label
        self.value = nil
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.tyrell.esper.opacity(0.65))
                .tracking(2)
                .frame(width: 80, alignment: .leading)

            Spacer()

            if let value {
                Text(value)
                    .font(.custom("Courier New", size: 12))
                    .foregroundColor(Color.tyrell.primary)
            } else {
                trailing
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(Color.tyrell.disabled.opacity(0.6))
                .padding(.leading, 6)
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

extension SliderNavRow where Trailing == EmptyView {
    init(label: String, value: String) {
        self.label = label
        self.value = value
        self.trailing = EmptyView()
    }
}

struct EsperDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.tyrell.esper.opacity(0.18))
            .frame(height: 1)
    }
}

struct EsperVerticalDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.tyrell.esper.opacity(0.25))
            .frame(width: 1)
    }
}

