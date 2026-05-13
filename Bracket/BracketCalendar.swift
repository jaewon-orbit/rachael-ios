// BracketCalendar.swift
// Bracket — Subscription Calendar
// Aesthetic: Tyrell Corp / Esper Machine (Blade Runner 1982)
//
// Drop this file into your Xcode project.
// Requires iOS 16+, SwiftUI.

import SwiftUI

// MARK: - Color Palette

extension Color {
    static let tyrell = TyrellColors()
    struct TyrellColors {
        let background = Color(hex: "#121212")
        let gridBg = Color(hex: "#2A2F3A")
        let accent = Color(hex: "#D90404")
        let esper = Color(hex: "#00FF00")
        let primary = Color(hex: "#D9D9D9")
        let disabled = Color(hex: "#707070")
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Calendar Logic

struct CalendarMonth: Identifiable {
    let id = UUID()
    let date: Date

    var year: Int { Calendar.current.component(.year, from: date) }
    var month: Int { Calendar.current.component(.month, from: date) }
    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date).uppercased()
    }
    var monthNumber: String { String(month) }

    var days: [CalendarDay] {
        var cal = Calendar.current
        cal.firstWeekday = 1
        let comps = DateComponents(year: year, month: month, day: 1)
        guard let firstDay = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstDay) else { return [] }

        let weekdayOfFirst = cal.component(.weekday, from: firstDay)
        let leadingEmpties = weekdayOfFirst - 1

        var days: [CalendarDay] = []
        for _ in 0..<leadingEmpties {
            days.append(CalendarDay(date: nil, dayNum: 0, isCurrentMonth: false))
        }
        for day in range {
            let date = cal.date(byAdding: .day, value: day - 1, to: firstDay)!
            days.append(CalendarDay(date: date, dayNum: day, isCurrentMonth: true))
        }
        let trailingCount = 42 - days.count
        for _ in 0..<trailingCount {
            days.append(CalendarDay(date: nil, dayNum: 0, isCurrentMonth: false))
        }
        return days
    }
}

struct CalendarDay {
    let date: Date?
    let dayNum: Int
    let isCurrentMonth: Bool

    var isToday: Bool {
        guard let date else { return false }
        return Calendar.current.isDateInToday(date)
    }
}

// MARK: - Subscription Model

struct Subscription: Identifiable {
    let id: UUID
    var name: String
    var amount: Double
    var currency: String
    var color: Color
    var iconName: String?
    var cycleUnit: CycleUnit
    var cycleInterval: Int
    var startDate: Date
    var duration: DurationOption
    var reminderOption: ReminderOption
    var note: String

    enum CycleUnit {
        case daily, weekly, monthly, yearly
    }

    enum DurationOption {
        case forever, fixedMonths(Int)
    }

    enum ReminderOption {
        case never, dayBefore, weekBefore
    }

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        currency: String,
        color: Color,
        iconName: String? = nil,
        cycleUnit: CycleUnit = .monthly,
        cycleInterval: Int = 1,
        startDate: Date,
        duration: DurationOption = .forever,
        reminderOption: ReminderOption = .never,
        note: String = ""
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.currency = currency
        self.color = color
        self.iconName = iconName
        self.cycleUnit = cycleUnit
        self.cycleInterval = max(1, cycleInterval)
        self.startDate = startDate
        self.duration = duration
        self.reminderOption = reminderOption
        self.note = note
    }
}

// MARK: - Main Calendar View

struct BracketCalendarView: View {
    enum SliderDetent {
        case collapsed
        case expanded
    }

    private enum HeaderPicker {
        case year
        case month
    }

    private enum HeaderArrow {
        case left
        case right

        var rotation: Double {
            switch self {
            case .left: -90
            case .right: 90
            }
        }

        var exitOffset: CGFloat {
            switch self {
            case .left: -44
            case .right: 44
            }
        }
    }

    private struct YearPickerItem: Identifiable {
        let id: String
        let year: Int?
    }

    @State private var currentMonthOffset = 0
    @State private var selectedDate: Date? = Date()
    @State private var selectedColumn = 0
    @State private var selectedRow = 0
    @State private var showEsperAnimation = false
    @State private var showSlider = false
    @State private var showMoreOptions = false
    @State private var newSubscriptionName = ""
    @State private var newSubscriptionAmount = ""
    @State private var newSubscriptionDescription = ""
    @State private var newSubscriptionCycle = "Every 1 Month(s)"
    @State private var newSubscriptionDuration = "Forever"
    @State private var newSubscriptionReminder = "Never"
    @State private var newSubscriptionFirstBill = ""
    @State private var newSubscriptionCurrency = "$ USD"
    @Binding var subscriptions: [Subscription]
    @State private var verticalLineProgress: CGFloat = 0
    @State private var horizontalLineProgress: CGFloat = 0
    @State private var borderBlink = false
    @State private var activeHeaderPicker: HeaderPicker?
    @State private var headerFrame: CGRect = .zero
    @State private var calendarFrame: CGRect = .zero
    @State private var calendarContentFrame: CGRect = .zero
    @State private var dayCellFrames: [Int: CGRect] = [:]
    @State private var pickerFrame: CGRect = .zero
    @State private var sliderFrame: CGRect = .zero
    @State private var sliderBracketContentHeight: CGFloat = 0
    @State private var foldedSliderBracketContentHeight: CGFloat = 0
    @State private var selectedCellFrame: CGRect = .zero
    @State private var pickerBracketVisible = true
    @State private var scanAnimationID = 0
    @State private var animatingHeaderArrow: HeaderArrow?
    @State private var headerArrowReplacementArrived = false
    @State private var headerArrowAnimationID = 0
    @State private var sliderDetent: SliderDetent = .collapsed
    @State private var sliderEntryOffset: CGFloat = 300
    @State private var sliderDragOffset: CGFloat = 0
    @GestureState private var sliderHandleDragOffset: CGFloat = 0
    @GestureState private var dragTranslation: CGFloat = 0

    private let weekSymbols = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    private let availableMonths = Array(1...12)

    private var currentYearValue: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var currentMonthValue: Int {
        Calendar.current.component(.month, from: Date())
    }

    private var isShowingCurrentMonth: Bool {
        currentMonthOffset == 0
    }

    private var availableYears: [Int] {
        Array((currentYearValue - 200)...(currentYearValue + 3))
    }

    private var yearPickerItems: [YearPickerItem] {
        var items = [
            YearPickerItem(id: "year-padding-top-0", year: nil),
            YearPickerItem(id: "year-padding-top-1", year: nil)
        ]

        items += availableYears.map { year in
            YearPickerItem(id: "year-\(year)", year: year)
        }

        items.append(YearPickerItem(id: "year-padding-bottom-0", year: nil))
        return items
    }

    private var animatedCornerFrame: CGRect {
        if showSlider, !sliderFrame.isEmpty {
            return sliderFrame.offsetBy(dx: 0, dy: sliderHandleDragOffset)
        }
        if activeHeaderPicker != nil, !pickerFrame.isEmpty {
            return pickerFrame
        }
        return calendarFrame
    }

    private var effectiveSliderBracketContentHeight: CGFloat {
        if sliderDetent == .collapsed, foldedSliderBracketContentHeight > 0 {
            return foldedSliderBracketContentHeight
        }
        return sliderBracketContentHeight
    }

    private var currentMonth: CalendarMonth {
        let date = Calendar.current.date(byAdding: .month, value: currentMonthOffset, to: Date()) ?? Date()
        return CalendarMonth(date: date)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.tyrell.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerView
                        .padding(.top, 16)
                        .padding(.horizontal, 20)
                        .background(
                            FrameReader(frame: $headerFrame, coordinateSpace: "calendarRoot")
                        )

                    weekdayLabels
                        .padding(.top, 16)
                        .padding(.horizontal, 12)

                    calendarGrid
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .offset(x: dragTranslation * 0.35)

                    Spacer()
                }

                if let activeHeaderPicker {
                    headerPickerOverlay(activeHeaderPicker)
                }

                if showEsperAnimation {
                    esperOverlay(containerSize: geo.size)
                }

                if showSlider {
                    bottomSheetOverlay(containerSize: geo.size)
                }

                animatedCornerOverlay
            }
            .coordinateSpace(name: "calendarRoot")
            .gesture(monthPagingGesture(containerWidth: geo.size.width))
        }
    }

    // MARK: - Header

    private var headerView: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                leftArrowButton
                    .frame(width: 44, alignment: .leading)

                yearMenuLabel
                    .frame(maxWidth: .infinity, alignment: .center)

                monthMenuLabel
                    .fixedSize()
                    .frame(width: 80)

                dayHeaderLabel
                    .frame(maxWidth: .infinity, alignment: .center)

                rightArrowButton
                    .frame(width: 44, alignment: .trailing)
            }
            .frame(height: 52)

            GeometryReader { geo in
                todayButton
                    .position(x: (geo.size.width * 0.625) - 1, y: 26)
            }
        }
        .frame(height: 52)
    }

    private var leftArrowButton: some View {
        Button {
            handleHeaderArrowTap(.left)
        } label: {
            headerArrow(.left)
        }
        .buttonStyle(.plain)
        .frame(height: 52)
    }

    private var rightArrowButton: some View {
        Button {
            handleHeaderArrowTap(.right)
        } label: {
            headerArrow(.right)
        }
        .buttonStyle(.plain)
        .frame(height: 52)
    }

    private func headerArrow(_ arrow: HeaderArrow) -> some View {
        let isAnimating = animatingHeaderArrow == arrow

        return ZStack {
            headerArrowShape(arrow)
                .offset(x: isAnimating && headerArrowReplacementArrived ? arrow.exitOffset : 0)

            headerArrowShape(arrow)
                .offset(y: isAnimating && !headerArrowReplacementArrived ? 30 : 0)
                .opacity(isAnimating ? (headerArrowReplacementArrived ? 1 : 0) : 0)
        }
        .frame(width: 14, height: 52)
        .contentShape(Rectangle())
    }

    private func headerArrowShape(_ arrow: HeaderArrow) -> some View {
        Triangle()
            .fill(Color.tyrell.accent)
            .frame(width: 14, height: 16)
            .rotationEffect(.degrees(arrow.rotation))
    }

    private var yearMenuLabel: some View {
        Button {
            toggleHeaderPicker(.year)
        } label: {
            Text(String(currentMonth.year))
                .font(.custom("Courier New", size: 18))
                .foregroundColor(Color.tyrell.disabled)
                .frame(height: 52)
        }
        .buttonStyle(.plain)
    }

    private var monthMenuLabel: some View {
        Button {
            toggleHeaderPicker(.month)
        } label: {
            VStack(spacing: 2) {
                Text(currentMonth.monthNumber)
                    .font(.custom("Courier New", size: 28).weight(.bold))
                    .foregroundColor(Color.tyrell.primary)
                    .monospacedDigit()

                Text(currentMonth.monthName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.tyrell.disabled)
                    .tracking(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var dayHeaderLabel: some View {
        if let selectedDate {
            selectedDayLabel(for: selectedDate)
        } else {
            selectedDayPlaceholder
        }
    }

    @ViewBuilder
    private var todayButton: some View {
        if !isShowingCurrentMonth {
            Button {
                setMonthOffset(0)
            } label: {
                Image(systemName: "house")
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(Color.tyrell.esper.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Today")
        } else {
            Color.clear
                .frame(width: 28, height: 28)
                .allowsHitTesting(false)
        }
    }

    private func selectedDayLabel(for selected: Date) -> some View {
        let ordinal = ordinalDayComponents(from: selected)

        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(ordinal.number)
                .font(.custom("Courier New", size: 18))
                .monospacedDigit()

            Text(ordinal.suffix)
                .font(.custom("Courier New", size: 10))
                .baselineOffset(1)
        }
            .foregroundColor(Color.tyrell.esper)
            .opacity(0.8)
            .frame(height: 52)
    }

    private var selectedDayPlaceholder: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("88")
                .font(.custom("Courier New", size: 18))
                .monospacedDigit()

            Text("th")
                .font(.custom("Courier New", size: 10))
                .baselineOffset(1)
        }
        .hidden()
        .frame(height: 52)
    }

    // MARK: - Weekday Labels

    private var weekdayLabels: some View {
        HStack(spacing: 0) {
            ForEach(weekSymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color.tyrell.disabled)
                    .tracking(1.2)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let days = currentMonth.days
        let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

        return GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.tyrell.gridBg)

                ScanlineOverlay()
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                LazyVGrid(columns: cols, spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.offset) { idx, day in
                        DayCellView(
                            day: day,
                            isSelected: isSelected(day),
                            isBlinking: borderBlink && isSelected(day),
                            hasSubscription: hasSubscription(on: day.date)
                        )
                        .background(
                            FrameReader(
                                frame: Binding(
                                    get: { dayCellFrames[idx] ?? .zero },
                                    set: { newValue in
                                        dayCellFrames[idx] = newValue
                                    }
                                ),
                                coordinateSpace: "calendarRoot"
                            )
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard day.isCurrentMonth, let date = day.date else { return }
                            triggerEsperScan(date: date, index: idx, col: idx % 7, row: idx / 7, gridSize: geo.size)
                        }
                    }
                }
                .padding(6)
                .background(
                    FrameReader(frame: $calendarContentFrame, coordinateSpace: "calendarRoot")
                )
            }
            .allowsHitTesting(activeHeaderPicker == nil)
            .background(
                FrameReader(frame: $calendarFrame, coordinateSpace: "calendarRoot")
            )
        }
        .frame(height: 340)
    }

    // MARK: - Esper Crosshair Overlay

    private func esperOverlay(containerSize: CGSize) -> some View {
        let gridFrame = calendarContentFrame.isEmpty ? calendarFrame : calendarContentFrame

        return Group {
            if !gridFrame.isEmpty, !selectedCellFrame.isEmpty {
                let cellCenterX = selectedCellFrame.midX
                let horizontalTargetY = selectedCellFrame.maxY + selectedCellFrame.height - 17
                let horizontalStartY = max(gridFrame.minY, selectedCellFrame.maxY)
                let animatedHorizontalY = horizontalStartY + verticalLineProgress * (horizontalTargetY - horizontalStartY)
                let animatedVerticalX = gridFrame.minX + horizontalLineProgress * (cellCenterX - gridFrame.minX)
                let verticalLineHeight = containerSize.height + 160

                ZStack {
                    Rectangle()
                        .fill(Color.tyrell.esper.opacity(0.9))
                        .frame(width: gridFrame.width, height: 1)
                        .position(
                            x: gridFrame.midX,
                            y: animatedHorizontalY
                        )

                    Rectangle()
                        .fill(Color.tyrell.esper.opacity(0.9))
                        .frame(width: 1, height: verticalLineHeight)
                        .position(
                            x: animatedVerticalX,
                            y: containerSize.height / 2
                        )
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Detail Slider

    private func bottomSheetOverlay(containerSize: CGSize) -> some View {
        GeometryReader { proxy in
            let availableHeight = proxy.size.height
            let expandedTopOffset = max(proxy.safeAreaInsets.top + 8, headerFrame.maxY + 8)
            let collapsedHeight = min(availableHeight - expandedTopOffset, 446)
            let expandedHeight = max(collapsedHeight, availableHeight - expandedTopOffset)
            let sheetHeight = sliderDetent == .expanded ? expandedHeight : collapsedHeight
            let collapsedRestingOffset = max(0, availableHeight - collapsedHeight)
            let restingOffset = sliderDetent == .expanded ? expandedTopOffset : collapsedRestingOffset
            let stableOffset = restingOffset + sliderEntryOffset + sliderDragOffset
            let visualOffset = stableOffset + sliderHandleDragOffset
            let horizontalInset: CGFloat = 8
            let sliderWidth = proxy.size.width - (horizontalInset * 2)
            let bracketContentHeight = effectiveSliderBracketContentHeight
            let bracketHeight = bracketContentHeight > 0 ? min(sheetHeight, bracketContentHeight) : sheetHeight
            let targetFrame = CGRect(x: horizontalInset, y: stableOffset, width: sliderWidth, height: bracketHeight)
            let backgroundHeight = max(sheetHeight, availableHeight - visualOffset)
            let sliderHandleGesture = DragGesture()
                .updating($sliderHandleDragOffset) { value, state, transaction in
                    transaction.animation = nil
                    state = clampedSliderDragOffset(value.translation.height)
                }
                .onEnded { value in
                    handleSliderDrag(value.translation)
                }

            ZStack(alignment: .top) {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture(perform: dismissSlider)

                Color(hex: "#141820")
                    .frame(width: sliderWidth, height: backgroundHeight)
                    .position(x: proxy.size.width / 2, y: visualOffset + (backgroundHeight / 2))
                    .transaction { transaction in
                        if sliderHandleDragOffset != 0 {
                            transaction.animation = nil
                        }
                    }

                BracketSubscriptionSlider(
                    selectedDate: selectedDate,
                    name: $newSubscriptionName,
                    amount: $newSubscriptionAmount,
                    currency: $newSubscriptionCurrency,
                    note: $newSubscriptionDescription,
                    cycle: $newSubscriptionCycle,
                    duration: $newSubscriptionDuration,
                    reminder: $newSubscriptionReminder,
                    firstBill: $newSubscriptionFirstBill,
                    showMoreOptions: $showMoreOptions,
                    bracketContentHeight: $sliderBracketContentHeight,
                    onAdd: addSubscription,
                    onDismiss: dismissSlider,
                    onHandleTap: expandSlider,
                    onFoldOptions: collapseSlider
                )
                .frame(width: sliderWidth, height: sheetHeight)
                .offset(y: visualOffset)
                .transaction { transaction in
                    if sliderHandleDragOffset != 0 {
                        transaction.animation = nil
                    }
                }

                Color.clear
                    .frame(width: 112, height: 36)
                    .contentShape(Rectangle())
                    .position(x: proxy.size.width / 2, y: visualOffset + 18)
                    .onTapGesture(perform: expandSlider)
                    .gesture(sliderHandleGesture)
            }
            .onAppear {
                sliderFrame = targetFrame
                sliderDetent = .collapsed
                sliderDragOffset = 0
                sliderEntryOffset = 300
                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                    sliderEntryOffset = 0
                }
            }
            .onChange(of: targetFrame) { _, newValue in
                var transaction = Transaction()
                if sliderHandleDragOffset != 0 {
                    transaction.animation = nil
                }
                withTransaction(transaction) {
                    sliderFrame = newValue
                }
            }
            .onChange(of: sliderBracketContentHeight) { _, newValue in
                if !showMoreOptions, newValue > 0 {
                    foldedSliderBracketContentHeight = newValue
                }
            }
            .onChange(of: showMoreOptions) { _, newValue in
                if !newValue, sliderBracketContentHeight > 0 {
                    foldedSliderBracketContentHeight = sliderBracketContentHeight
                }
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    // MARK: - Actions

    // MARK: - Helpers for Header

    private func headerPickerOverlay(_ picker: HeaderPicker) -> some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissHeaderPicker()
                }

            pickerPanel(for: picker)
                .background(
                    FrameReader(frame: $pickerFrame, coordinateSpace: "calendarRoot")
                )
                .padding(.horizontal, 20)
                .padding(.top, headerFrame.maxY)
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private func pickerPanel(for picker: HeaderPicker) -> some View {
        switch picker {
        case .year:
            yearGridPanel
        case .month:
            monthGridPanel
        }
    }

    private var yearGridPanel: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

        return VStack(alignment: .leading, spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(yearPickerItems) { item in
                            if let year = item.year {
                                pickerCell(
                                    title: "\(year)",
                                    isSelected: year == currentMonth.year,
                                    isCurrentValue: year == currentYearValue
                                ) {
                                    dismissHeaderPicker()
                                    updateOffset(year: year, month: currentMonth.month)
                                }
                                .id(item.id)
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 42)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    .padding(.bottom, 1)
                }
                .onAppear {
                    DispatchQueue.main.async {
                        proxy.scrollTo("year-\(currentYearValue)", anchor: .center)
                    }
                }
            }
            .frame(height: (42 * 3) + (10 * 2))
        }
        .padding(14)
        .background(Color.tyrell.gridBg.opacity(0.96))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.tyrell.disabled.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var monthGridPanel: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
        let isCurrentYear = currentMonth.year == currentYearValue

        return VStack(alignment: .leading, spacing: 0) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(availableMonths, id: \.self) { month in
                    pickerCell(
                        title: String(format: "%02d", month),
                        isSelected: month == currentMonth.month,
                        isCurrentValue: isCurrentYear && month == currentMonthValue
                    ) {
                        dismissHeaderPicker()
                        updateOffset(year: currentMonth.year, month: month)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.tyrell.gridBg.opacity(0.96))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.tyrell.disabled.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func pickerCell(
        title: String,
        isSelected: Bool,
        isCurrentValue: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Courier New", size: 16))
                .foregroundColor(isSelected ? Color.tyrell.esper : Color.tyrell.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.tyrell.esper.opacity(0.14) : Color.black.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isSelected ? Color.tyrell.esper.opacity(0.85) : Color.tyrell.disabled.opacity(0.35),
                            lineWidth: 1
                        )
                )
                .overlay {
                    if isCurrentValue {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.tyrell.esper.opacity(0.75), lineWidth: 1)
                            .padding(3)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var animatedCornerOverlay: some View {
        Group {
            if !animatedCornerFrame.isEmpty {
                CornerOverlayFrame(frame: animatedCornerFrame)
                    .opacity(activeHeaderPicker == nil || pickerBracketVisible ? 1 : 0)
                    .animation(sliderHandleDragOffset != 0 ? nil : .easeInOut(duration: 0.4), value: animatedCornerFrame)
                    .animation(.linear(duration: 0.06), value: pickerBracketVisible)
                    .allowsHitTesting(false)
            }
        }
    }

    private func toggleHeaderPicker(_ picker: HeaderPicker) {
        let nextPicker: HeaderPicker? = activeHeaderPicker == picker ? nil : picker
        withAnimation(.linear(duration: 0.15)) {
            activeHeaderPicker = nextPicker
        }

        if nextPicker != nil {
            blinkPickerBracket(times: 2)
        } else {
            pickerBracketVisible = true
        }
    }

    private func dismissHeaderPicker() {
        withAnimation(.linear(duration: 0.15)) {
            activeHeaderPicker = nil
        }
        pickerBracketVisible = true
    }

    private func updateOffset(year: Int, month: Int) {
        let calendar = Calendar.current
        let targetComps = DateComponents(year: year, month: month, day: 1)
        guard let targetDate = calendar.date(from: targetComps) else { return }

        let currentComps = calendar.dateComponents([.year, .month], from: Date())
        guard let currentDate = calendar.date(from: currentComps) else { return }

        let diff = calendar.dateComponents([.month], from: currentDate, to: targetDate)
        setMonthOffset(diff.month ?? 0)
    }

    private func changeMonthOffset(by delta: Int) {
        setMonthOffset(currentMonthOffset + delta)
    }

    private func handleHeaderArrowTap(_ arrow: HeaderArrow) {
        animateHeaderArrow(arrow)
        changeMonthOffset(by: arrow == .left ? -1 : 1)
    }

    private func animateHeaderArrow(_ arrow: HeaderArrow) {
        headerArrowAnimationID += 1
        let animationID = headerArrowAnimationID

        animatingHeaderArrow = arrow
        headerArrowReplacementArrived = false

        DispatchQueue.main.async {
            guard animationID == headerArrowAnimationID else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                headerArrowReplacementArrived = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard animationID == headerArrowAnimationID else { return }
            animatingHeaderArrow = nil
            headerArrowReplacementArrived = false
        }
    }

    private func setMonthOffset(_ newOffset: Int) {
        dismissHeaderPicker()
        clearSelectedDayState()
        if newOffset == 0 {
            selectedDate = Date()
        }
        withAnimation(.linear(duration: 0.2)) {
            currentMonthOffset = newOffset
        }
    }

    private func clearSelectedDayState() {
        selectedDate = nil
        selectedColumn = 0
        selectedRow = 0
        selectedCellFrame = .zero
        showEsperAnimation = false
        showSlider = false
        verticalLineProgress = 0
        horizontalLineProgress = 0
        borderBlink = false
        newSubscriptionName = ""
    }

    private func ordinalDayComponents(from date: Date) -> (number: String, suffix: String) {
        let day = Calendar.current.component(.day, from: date)
        let suffix: String

        switch day % 100 {
        case 11, 12, 13:
            suffix = "th"
        default:
            switch day % 10 {
            case 1:
                suffix = "st"
            case 2:
                suffix = "nd"
            case 3:
                suffix = "rd"
            default:
                suffix = "th"
            }
        }

        return ("\(day)", suffix)
    }

    private func monthPagingGesture(containerWidth: CGFloat) -> some Gesture {
        DragGesture()
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                let threshold = containerWidth * 0.5
                if value.translation.width <= -threshold {
                    changeMonthOffset(by: 1)
                } else if value.translation.width >= threshold {
                    changeMonthOffset(by: -1)
                }
            }
    }

    private func triggerEsperScan(date: Date, index: Int, col: Int, row: Int, gridSize: CGSize) {
        scanAnimationID += 1
        let animationID = scanAnimationID

        selectedDate = date
        selectedColumn = col
        selectedRow = row
        selectedCellFrame = dayCellFrames[index] ?? .zero
        showEsperAnimation = true
        verticalLineProgress = 0
        horizontalLineProgress = 0
        borderBlink = false

        withAnimation(.linear(duration: 0.22)) {
            verticalLineProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            guard animationID == scanAnimationID else { return }
            withAnimation(.linear(duration: 0.2)) {
                horizontalLineProgress = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            guard animationID == scanAnimationID else { return }
            blinkBorder(times: 4, animationID: animationID)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard animationID == scanAnimationID else { return }
            withAnimation(.linear(duration: 0.05)) {
                showEsperAnimation = false
            }
            guard !showSlider else { return }
            withAnimation(.linear(duration: 0.2)) {
                showSlider = true
            }
        }
    }

    private func blinkBorder(times: Int, current: Int = 0, animationID: Int) {
        guard animationID == scanAnimationID else { return }
        guard current < times * 2 else {
            borderBlink = false
            return
        }

        withAnimation(.linear(duration: 0.06)) {
            borderBlink = current.isMultiple(of: 2)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            blinkBorder(times: times, current: current + 1, animationID: animationID)
        }
    }

    private func blinkPickerBracket(times: Int, current: Int = 0) {
        guard current < times * 2 else {
            pickerBracketVisible = true
            return
        }

        withAnimation(.linear(duration: 0.06)) {
            pickerBracketVisible = !current.isMultiple(of: 2)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            blinkPickerBracket(times: times, current: current + 1)
        }
    }

    private func addSubscription() {
        guard let date = selectedDate, !newSubscriptionName.isEmpty else { return }
        let parsedAmount = Double(newSubscriptionAmount.replacingOccurrences(of: ",", with: "")) ?? 0
        subscriptions.insert(
            Subscription(
                name: newSubscriptionName.uppercased(),
                amount: parsedAmount,
                currency: newSubscriptionCurrency,
                color: Color.black,
                iconName: nil,
                cycleUnit: .monthly,
                cycleInterval: 1,
                startDate: date,
                note: newSubscriptionDescription.uppercased()
            ),
            at: 0
        )
        resetSubscriptionForm()
        dismissSlider()
    }

    private func expandSlider() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            sliderDragOffset = 0
            sliderDetent = .expanded
        }
    }

    private func collapseSlider() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            sliderDragOffset = 0
            showMoreOptions = false
            sliderDetent = .collapsed
        }
    }

    private func clampedSliderDragOffset(_ dragHeight: CGFloat) -> CGFloat {
        if sliderDetent == .collapsed {
            return min(max(dragHeight, -360), 120)
        }
        return min(max(dragHeight, 0), 360)
    }

    private func handleSliderDrag(_ translation: CGSize) {
        let shouldExpand = translation.height < -60
        let shouldCollapse = sliderDetent == .expanded && translation.height > 80
        let shouldDismiss = sliderDetent == .collapsed && translation.height > 80
        let releaseOffset = clampedSliderDragOffset(translation.height)

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            sliderDragOffset = releaseOffset
        }

        if shouldDismiss {
            dismissSlider()
        } else {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                sliderDragOffset = 0
                if shouldExpand {
                    sliderDetent = .expanded
                } else if shouldCollapse {
                    sliderDetent = .collapsed
                    showMoreOptions = false
                }
            }
        }
    }

    private func dismissSlider() {
        scanAnimationID += 1
        showEsperAnimation = false
        borderBlink = false
        showMoreOptions = false
        withAnimation(.easeInOut(duration: 0.22)) {
            sliderDragOffset = 0
            sliderEntryOffset = 300
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            showSlider = false
            sliderDetent = .collapsed
        }
    }

    private func resetSubscriptionForm() {
        newSubscriptionName = ""
        newSubscriptionAmount = ""
        newSubscriptionDescription = ""
        newSubscriptionCycle = "Every 1 Month(s)"
        newSubscriptionDuration = "Forever"
        newSubscriptionReminder = "Never"
        newSubscriptionFirstBill = ""
        newSubscriptionCurrency = "$ USD"
        showMoreOptions = false
    }

    private func isSelected(_ day: CalendarDay) -> Bool {
        guard let selectedDate, let date = day.date else { return false }
        return Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }

    private func billingDates(for subscription: Subscription, in month: CalendarMonth) -> Set<Int> {
        var result = Set<Int>()
        let cal = Calendar.current

        guard let monthStart = cal.date(from: DateComponents(year: month.year, month: month.month, day: 1)),
              let monthEnd = cal.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)
        else { return result }

        guard subscription.startDate <= monthEnd else { return result }

        var billingDate = subscription.startDate
        while billingDate < monthStart {
            billingDate = nextBillingDate(after: billingDate, sub: subscription)
        }

        while billingDate <= monthEnd {
            result.insert(cal.component(.day, from: billingDate))
            billingDate = nextBillingDate(after: billingDate, sub: subscription)
        }

        return result
    }

    private func nextBillingDate(after date: Date, sub: Subscription) -> Date {
        let cal = Calendar.current
        let interval = max(1, sub.cycleInterval)
        switch sub.cycleUnit {
        case .daily:
            return cal.date(byAdding: .day, value: interval, to: date) ?? date
        case .weekly:
            return cal.date(byAdding: .weekOfYear, value: interval, to: date) ?? date
        case .monthly:
            return cal.date(byAdding: .month, value: interval, to: date) ?? date
        case .yearly:
            return cal.date(byAdding: .year, value: interval, to: date) ?? date
        }
    }

    private func hasSubscription(on date: Date?) -> Bool {
        guard let date else { return false }
        let cal = Calendar.current
        let day = cal.component(.day, from: date)
        return subscriptions.contains { sub in
            billingDates(for: sub, in: currentMonth).contains(day)
            && cal.component(.month, from: date) == currentMonth.month
            && cal.component(.year, from: date) == currentMonth.year
        }
    }
}

// MARK: - Day Cell

struct DayCellView: View {
    let day: CalendarDay
    let isSelected: Bool
    let isBlinking: Bool
    let hasSubscription: Bool

    var body: some View {
        ZStack {
            if isSelected {
                Rectangle()
                    .fill(Color.tyrell.esper.opacity(0.10))
            }

            if day.dayNum > 0 {
                VStack(spacing: 2) {
                    Text("\(day.dayNum)")
                        .font(.custom("Courier New", size: 14))
                        .foregroundColor(textColor)
                        .monospacedDigit()

                    if hasSubscription {
                        Circle()
                            .fill(Color.tyrell.accent)
                            .frame(width: 4, height: 4)
                    }
                }
            }

            if day.isToday {
                Rectangle()
                    .stroke(Color.tyrell.esper, lineWidth: 1)
                    .opacity(0.8)
            }

            if isBlinking {
                Rectangle()
                    .stroke(Color.tyrell.esper, lineWidth: 2)
                    .padding(2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
    }

    private var textColor: Color {
        if day.isToday || isSelected { return Color.tyrell.esper }
        if !day.isCurrentMonth { return Color.tyrell.disabled.opacity(0.4) }
        return Color.tyrell.primary
    }
}

// MARK: - CRT Scanlines

struct ScanlineOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let lineHeight: CGFloat = 3
            let count = Int(geo.size.height / lineHeight)
            VStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    Rectangle()
                        .fill(Color.black.opacity(i % 2 == 0 ? 0.12 : 0))
                        .frame(height: lineHeight)
                }
            }
        }
    }
}

// MARK: - Frame Tracking

struct FrameReader: View {
    @Binding var frame: CGRect
    let coordinateSpace: String

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    frame = geo.frame(in: .named(coordinateSpace))
                }
                .onChange(of: geo.frame(in: .named(coordinateSpace))) { _, newValue in
                    frame = newValue
                }
        }
    }
}

// MARK: - L-Bracket Corners

struct LBracketCorners: View {
    let size: CGFloat = 14
    let thickness: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LBracket()
                    .stroke(Color.tyrell.esper.opacity(0.7), lineWidth: thickness)
                    .frame(width: size, height: size)
                    .position(x: size / 2 + 4, y: size / 2 + 4)

                LBracket()
                    .stroke(Color.tyrell.esper.opacity(0.7), lineWidth: thickness)
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(90))
                    .position(x: geo.size.width - size / 2 - 4, y: size / 2 + 4)

                LBracket()
                    .stroke(Color.tyrell.esper.opacity(0.7), lineWidth: thickness)
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                    .position(x: size / 2 + 4, y: geo.size.height - size / 2 - 4)

                LBracket()
                    .stroke(Color.tyrell.esper.opacity(0.7), lineWidth: thickness)
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(180))
                    .position(x: geo.size.width - size / 2 - 4, y: geo.size.height - size / 2 - 4)
            }
        }
    }
}

struct CornerOverlayFrame: View {
    let frame: CGRect
    private let size: CGFloat = 14
    private let thickness: CGFloat = 1.5

    var body: some View {
        ZStack {
            bracket(rotation: .degrees(0))
                .position(x: frame.minX + size / 2, y: frame.minY + size / 2)

            bracket(rotation: .degrees(90))
                .position(x: frame.maxX - size / 2, y: frame.minY + size / 2)

            bracket(rotation: .degrees(-90))
                .position(x: frame.minX + size / 2, y: frame.maxY - size / 2)

            bracket(rotation: .degrees(180))
                .position(x: frame.maxX - size / 2, y: frame.maxY - size / 2)
        }
    }

    private func bracket(rotation: Angle) -> some View {
        LBracket()
            .stroke(Color.tyrell.esper.opacity(0.7), lineWidth: thickness)
            .frame(width: size, height: size)
            .rotationEffect(rotation)
    }
}

struct LBracket: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Corner Radius Helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        Path(
            UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: corners,
                cornerRadii: CGSize(width: radius, height: radius)
            ).cgPath
        )
    }
}

extension Subscription {
    static var sampleData: [Subscription] {
        let cal = Calendar.current
        let today = Date()
        return [
            Subscription(
                name: "APPLE MUSIC",
                amount: 8900,
                currency: "₩ KRW",
                color: Color.black,
                iconName: "music.note",
                cycleUnit: .weekly,
                cycleInterval: 2,
                startDate: cal.date(byAdding: .day, value: -28, to: today) ?? today
            ),
            Subscription(
                name: "GOOGLE DRIVE",
                amount: 2400,
                currency: "₩ KRW",
                color: Color(hex: "#34A853"),
                iconName: "externaldrive.fill",
                startDate: cal.date(byAdding: .day, value: -45, to: today) ?? today
            ),
            Subscription(
                name: "NETFLIX",
                amount: 17000,
                currency: "₩ KRW",
                color: Color(hex: "#E50914"),
                iconName: "play.rectangle.fill",
                startDate: cal.date(byAdding: .day, value: -12, to: today) ?? today
            ),
            Subscription(
                name: "YOUTUBE",
                amount: 14900,
                currency: "₩ KRW",
                color: Color(hex: "#FF0000"),
                iconName: "play.fill",
                startDate: cal.date(byAdding: .day, value: -20, to: today) ?? today
            )
        ]
    }
}

// MARK: - Preview

#Preview {
    BracketCalendarView(subscriptions: .constant(Subscription.sampleData))
        .preferredColorScheme(.dark)
}
