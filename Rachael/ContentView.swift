import SwiftUI
import UIKit

struct ContentView: View {
    @State private var subscriptions = Subscription.sampleData
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case 0:
                    RachaelCalendarView(subscriptions: $subscriptions)
                case 1:
                    RachaelStackView(subscriptions: $subscriptions)
                case 2:
                    Text("SETTINGS")
                        .foregroundColor(Color.tyrell.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.tyrell.background.ignoresSafeArea())
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.all, edges: .bottom)

            EsperTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .background(Color.tyrell.background.ignoresSafeArea())
    }
}

// MARK: - Esper Tab Bar

struct EsperTabBar: View {
    @Binding var selectedTab: Int

    private let tabs: [(icon: String, label: String)] = [
        ("calendar", "CAL"),
        ("line.3.horizontal", "LOG"),
        ("gearshape", "CFG")
    ]

    @State private var tabCenters: [Int: CGFloat] = [:]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.tyrell.background
                    .ignoresSafeArea(edges: .bottom)

                Rectangle()
                    .fill(Color.tyrell.esper.opacity(0.15))
                    .frame(height: 1)

                scanlines

                GeometryReader { barProxy in
                    HStack(spacing: 0) {
                        ForEach(tabs.indices, id: \.self) { index in
                            tabButton(at: index)
                                .background(tabCenterReader(for: index))
                        }
                    }
                    .coordinateSpace(name: "esperTabBar")

                    if let centerX = tabCenters[selectedTab] {
                        ReticleBracket()
                            .frame(width: 44, height: 44)
                            .position(x: centerX, y: 22)
                            .animation(
                                .spring(response: 0.32, dampingFraction: 0.72),
                                value: selectedTab
                            )
                    }
                }
                .frame(height: 44)
                .padding(.top, 8)
            }
            .frame(height: tabBarHeight(bottomSafeArea: proxy.safeAreaInsets.bottom))
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 44 + 8)
    }

    private var scanlines: some View {
        GeometryReader { proxy in
            let lineHeight: CGFloat = 3
            let count = max(1, Int(proxy.size.height / lineHeight))

            VStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { index in
                    Rectangle()
                        .fill(Color.black.opacity(index.isMultiple(of: 2) ? 0.10 : 0))
                        .frame(height: lineHeight)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func tabButton(at index: Int) -> some View {
        Button {
            selectedTab = index
        } label: {
            Image(systemName: tabs[index].icon)
                .font(.system(size: 20, weight: .light))
                .foregroundColor(selectedTab == index ? Color.tyrell.esper : Color.tyrell.disabled)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tabs[index].label)
    }

    private func tabCenterReader(for index: Int) -> some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    updateCenter(for: index, frame: proxy.frame(in: .named("esperTabBar")))
                }
                .onChange(of: proxy.size) { _, _ in
                    updateCenter(for: index, frame: proxy.frame(in: .named("esperTabBar")))
                }
        }
    }

    private func updateCenter(for index: Int, frame: CGRect) {
        tabCenters[index] = frame.midX
    }

    private func tabBarHeight(bottomSafeArea: CGFloat) -> CGFloat {
        44 + 8 + bottomSafeArea
    }
}

// MARK: - Reticle Bracket Shape

struct ReticleBracket: View {
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            let arm: CGFloat = 10
            let thickness: CGFloat = 1.5
            let color = Color.tyrell.esper.opacity(0.85)

            draw(
                context: &context,
                color: color,
                thickness: thickness,
                from: CGPoint(x: 0, y: arm),
                to: CGPoint(x: 0, y: 0)
            )
            draw(
                context: &context,
                color: color,
                thickness: thickness,
                from: CGPoint(x: 0, y: 0),
                to: CGPoint(x: arm, y: 0)
            )
            draw(
                context: &context,
                color: color,
                thickness: thickness,
                from: CGPoint(x: width - arm, y: 0),
                to: CGPoint(x: width, y: 0)
            )
            draw(
                context: &context,
                color: color,
                thickness: thickness,
                from: CGPoint(x: width, y: 0),
                to: CGPoint(x: width, y: arm)
            )
            draw(
                context: &context,
                color: color,
                thickness: thickness,
                from: CGPoint(x: 0, y: height - arm),
                to: CGPoint(x: 0, y: height)
            )
            draw(
                context: &context,
                color: color,
                thickness: thickness,
                from: CGPoint(x: 0, y: height),
                to: CGPoint(x: arm, y: height)
            )
            draw(
                context: &context,
                color: color,
                thickness: thickness,
                from: CGPoint(x: width - arm, y: height),
                to: CGPoint(x: width, y: height)
            )
            draw(
                context: &context,
                color: color,
                thickness: thickness,
                from: CGPoint(x: width, y: height - arm),
                to: CGPoint(x: width, y: height)
            )
        }
        .allowsHitTesting(false)
    }

    private func draw(
        context: inout GraphicsContext,
        color: Color,
        thickness: CGFloat,
        from: CGPoint,
        to: CGPoint
    ) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path, with: .color(color), lineWidth: thickness)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
