import SwiftUI
import WidgetKit

/// A clockwise ring segment starting at `startFraction` (0 = 12 o'clock) and ending at `endFraction`.
/// Starts with a flat radial edge and optionally finishes with a semicircular rounded leading cap.
struct RingSegmentShape: Shape {
    let startFraction: CGFloat
    let endFraction: CGFloat
    let lineWidth: CGFloat
    let roundEnd: Bool

    func path(in rect: CGRect) -> Path {
        let clampedStart = max(0, min(1, startFraction))
        let clampedEnd = max(clampedStart, min(1, endFraction))
        let span = clampedEnd - clampedStart
        guard span > 0.0001 else { return Path() }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = max(0, outerRadius - lineWidth)
        let midRadius = (outerRadius + innerRadius) / 2

        // Full ring fast path.
        if span >= 0.9999 {
            var path = Path()
            path.addEllipse(in: CGRect(
                x: center.x - outerRadius,
                y: center.y - outerRadius,
                width: outerRadius * 2,
                height: outerRadius * 2
            ))
            path.addEllipse(in: CGRect(
                x: center.x - innerRadius,
                y: center.y - innerRadius,
                width: innerRadius * 2,
                height: innerRadius * 2
            ))
            return path
        }

        let startRadians = -CGFloat.pi / 2 + clampedStart * 2 * .pi
        let endRadians = -CGFloat.pi / 2 + clampedEnd * 2 * .pi

        let outerStart = CGPoint(
            x: center.x + outerRadius * cos(startRadians),
            y: center.y + outerRadius * sin(startRadians)
        )

        var path = Path()
        path.move(to: outerStart)

        // In SwiftUI's flipped coordinate system (+y downward), `clockwise: false` sweeps visually clockwise.
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: .radians(Double(startRadians)),
            endAngle: .radians(Double(endRadians)),
            clockwise: false
        )

        if roundEnd {
            let capCenter = CGPoint(
                x: center.x + midRadius * cos(endRadians),
                y: center.y + midRadius * sin(endRadians)
            )
            path.addArc(
                center: capCenter,
                radius: lineWidth / 2,
                startAngle: .radians(Double(endRadians)),
                endAngle: .radians(Double(endRadians + .pi)),
                clockwise: false
            )
        } else {
            let innerEnd = CGPoint(
                x: center.x + innerRadius * cos(endRadians),
                y: center.y + innerRadius * sin(endRadians)
            )
            path.addLine(to: innerEnd)
        }

        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: .radians(Double(endRadians)),
            endAngle: .radians(Double(startRadians)),
            clockwise: true
        )

        path.closeSubpath()
        return path
    }
}

/// Crisp 45-degree diagonal `/` stripes used to shade the over-budget portion of the ring.
struct DiagonalStripesShape: Shape {
    let stripeWidth: CGFloat
    let spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        let pitch = max(1, stripeWidth + spacing)
        let sqrt2 = CGFloat(2).squareRoot()
        let horizontalStep = pitch * sqrt2
        let horizontalBand = stripeWidth * sqrt2

        var path = Path()
        var x = -horizontalStep
        let maxX = rect.width + rect.height + horizontalStep

        while x <= maxX {
            path.move(to: CGPoint(x: rect.minX + x, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + x + horizontalBand, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + x + horizontalBand - rect.height, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + x - rect.height, y: rect.maxY))
            path.closeSubpath()
            x += horizontalStep
        }

        return path
    }
}

struct CalorieRingGraphic: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    let summary: CalorieSummary
    let isConfigured: Bool
    let lineWidth: CGFloat
    let gapWidth: CGFloat

    private var consumedBlue: Color {
        colorScheme == .dark
            ? Color(red: 0.11, green: 0.41, blue: 0.78)
            : Color(red: 0.13, green: 0.51, blue: 0.96)
    }

    private var activityOrange: Color {
        colorScheme == .dark
            ? Color(red: 0.78, green: 0.46, blue: 0.13)
            : Color(red: 0.96, green: 0.58, blue: 0.16)
    }

    private var goalAllowanceGray: Color {
        colorScheme == .dark
            ? Color(red: 0.20, green: 0.21, blue: 0.24)
            : Color(red: 0.89, green: 0.90, blue: 0.92)
    }

    private var overStripeDark: Color {
        colorScheme == .dark
            ? Color(red: 0.04, green: 0.19, blue: 0.45)
            : Color(red: 0.05, green: 0.25, blue: 0.59)
    }

    private var overStripeLight: Color {
        colorScheme == .dark
            ? Color(red: 0.46, green: 0.60, blue: 0.78)
            : Color(red: 0.65, green: 0.80, blue: 0.98)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = max(1, (size - lineWidth) / 2)
            let capClearance: CGFloat = lineWidth * 0.5 + gapWidth + 1.5
            let circumference: CGFloat = 2 * CGFloat.pi * radius
            let minSafeFraction = Double(capClearance / circumference)

            ZStack {
                if !isConfigured {
                    unconfiguredRing
                } else if summary.isOverBudget {
                    overBudgetRing(size: size, radius: radius, minSafeFraction: minSafeFraction)
                } else {
                    remainingRing(size: size, radius: radius, minSafeFraction: minSafeFraction)
                }
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var unconfiguredRing: some View {
        Circle()
            .stroke(
                renderingMode == .fullColor
                    ? (colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.10))
                    : Color.primary.opacity(0.28),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [lineWidth * 0.7, lineWidth * 0.9])
            )
            .padding(lineWidth / 2)
    }

    @ViewBuilder
    private func remainingRing(size: CGFloat, radius: CGFloat, minSafeFraction: Double) -> some View {
        let rawFraction = summary.consumedFraction
        let circumference = max(1, 2 * CGFloat.pi * radius)
        let minVisibleExerciseFraction = Double(max(1.5, lineWidth * 0.16) / circumference)
        let hasExerciseAllowance = summary.exerciseCalories >= 0.5 && summary.exerciseBudgetFraction > 0
        let activityFraction: CGFloat = hasExerciseAllowance
            ? CGFloat(max(minVisibleExerciseFraction, min(1, summary.exerciseBudgetFraction)))
            : 0
        let goalBoundary: CGFloat = max(0, min(1, 1 - activityFraction))
        let seamOverlap: CGFloat = renderingMode == .fullColor ? 0.002 : 0

        if rawFraction <= 0.001 {
            // 0 calories consumed: neutral goal-allowance ring with an orange activity segment ending at 12 o'clock.
            if activityFraction >= 0.9999 {
                Circle()
                    .stroke(activityRemainingFillColor, lineWidth: lineWidth)
                    .padding(lineWidth / 2)
            } else if activityFraction > 0.0001 {
                ZStack {
                    if goalBoundary > 0.0001 {
                        RingSegmentShape(
                            startFraction: 0,
                            endFraction: min(1, goalBoundary + seamOverlap),
                            lineWidth: lineWidth,
                            roundEnd: false
                        )
                        .fill(goalRemainingFillColor, style: FillStyle(eoFill: true))
                    }

                    RingSegmentShape(
                        startFraction: goalBoundary,
                        endFraction: 1,
                        lineWidth: lineWidth,
                        roundEnd: false
                    )
                    .fill(activityRemainingFillColor, style: FillStyle(eoFill: true))
                }
            } else {
                Circle()
                    .stroke(goalRemainingFillColor, lineWidth: lineWidth)
                    .padding(lineWidth / 2)
            }
        } else if rawFraction >= 0.985 {
            // Budget reached cleanly: unbroken consumed ring.
            Circle()
                .stroke(consumedFillColor, lineWidth: lineWidth)
                .padding(lineWidth / 2)
                .widgetAccentable()
        } else {
            let fraction = CGFloat(max(minSafeFraction, min(0.97, rawFraction)))
            let capPoint = pointOnMidline(fraction: fraction, size: size, radius: radius)
            let activityStart = max(fraction, goalBoundary)

            // Remaining portion distinguishes base goal allowance (neutral gray) from
            // calories added by activities (orange), with a transparent crescent cutout at the consumed tip.
            ZStack {
                if activityStart > fraction + 0.0001 {
                    let goalEnd = hasExerciseAllowance ? min(1, activityStart + seamOverlap) : 1
                    RingSegmentShape(
                        startFraction: fraction,
                        endFraction: goalEnd,
                        lineWidth: lineWidth,
                        roundEnd: false
                    )
                    .fill(goalRemainingFillColor, style: FillStyle(eoFill: true))
                }

                if hasExerciseAllowance && activityStart < 0.9999 {
                    RingSegmentShape(
                        startFraction: activityStart,
                        endFraction: 1,
                        lineWidth: lineWidth,
                        roundEnd: false
                    )
                    .fill(activityRemainingFillColor, style: FillStyle(eoFill: true))
                }

                Circle()
                    .frame(width: lineWidth + gapWidth * 2, height: lineWidth + gapWidth * 2)
                    .position(capPoint)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()

            // Consumed arc starting flat at 12 o'clock with a rounded leading tip.
            RingSegmentShape(
                startFraction: 0,
                endFraction: fraction,
                lineWidth: lineWidth,
                roundEnd: true
            )
            .fill(consumedFillColor)
            .widgetAccentable()
        }
    }

    @ViewBuilder
    private func overBudgetRing(size: CGFloat, radius: CGFloat, minSafeFraction: Double) -> some View {
        let rawOverFraction = summary.overBudgetFraction

        if rawOverFraction >= 0.985 {
            stripedArc(startFraction: 0, endFraction: 1, roundEnd: false, size: size)
                .widgetAccentable()
        } else {
            let fraction = CGFloat(max(minSafeFraction, min(0.97, rawOverFraction)))
            let capPoint = pointOnMidline(fraction: fraction, size: size, radius: radius)

            // Solid blue base ring with transparent crescent cutout ahead of the overage tip.
            ZStack {
                RingSegmentShape(
                    startFraction: fraction,
                    endFraction: 1,
                    lineWidth: lineWidth,
                    roundEnd: false
                )
                .fill(overBaseFillColor, style: FillStyle(eoFill: true))

                Circle()
                    .frame(width: lineWidth + gapWidth * 2, height: lineWidth + gapWidth * 2)
                    .position(capPoint)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()

            // Shaded diagonal-striped overage arc starting flat at 12 o'clock.
            stripedArc(startFraction: 0, endFraction: fraction, roundEnd: true, size: size)
                .widgetAccentable()
        }
    }

    @ViewBuilder
    private func stripedArc(
        startFraction: CGFloat,
        endFraction: CGFloat,
        roundEnd: Bool,
        size: CGFloat
    ) -> some View {
        let stripeWidth = max(1.6, lineWidth * 0.24)
        let stripeSpacing = max(2.2, lineWidth * 0.36)
        let segment = RingSegmentShape(
            startFraction: startFraction,
            endFraction: endFraction,
            lineWidth: lineWidth,
            roundEnd: roundEnd
        )

        if renderingMode == .fullColor {
            ZStack {
                segment
                    .fill(overStripeDark, style: FillStyle(eoFill: true))

                DiagonalStripesShape(stripeWidth: stripeWidth, spacing: stripeSpacing)
                    .fill(overStripeLight)
                    .mask {
                        segment.fill(Color.black, style: FillStyle(eoFill: true))
                    }
            }
        } else {
            // In Lock Screen vibrant and Tinted Home Screen modes, punch out subtle diagonal hatches
            // so the shaded over-budget segment stays unmistakable in monochrome.
            ZStack {
                segment
                    .fill(Color.primary, style: FillStyle(eoFill: true))

                DiagonalStripesShape(stripeWidth: stripeWidth, spacing: stripeSpacing)
                    .fill(Color.black.opacity(0.68))
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .mask {
                segment.fill(Color.black, style: FillStyle(eoFill: true))
            }
        }
    }

    private var consumedFillColor: Color {
        renderingMode == .fullColor ? consumedBlue : .primary
    }

    private var goalRemainingFillColor: Color {
        renderingMode == .fullColor ? goalAllowanceGray : .primary.opacity(0.20)
    }

    private var activityRemainingFillColor: Color {
        renderingMode == .fullColor ? activityOrange : .primary.opacity(0.50)
    }

    private var overBaseFillColor: Color {
        renderingMode == .fullColor ? consumedBlue : .primary.opacity(0.55)
    }

    private func pointOnMidline(fraction: CGFloat, size: CGFloat, radius: CGFloat) -> CGPoint {
        let angle = -CGFloat.pi / 2 + fraction * 2 * .pi
        return CGPoint(
            x: size / 2 + radius * cos(angle),
            y: size / 2 + radius * sin(angle)
        )
    }
}

struct CalorieWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: CalorieWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryRectangular:
            accessoryRectangularView
        case .systemMedium:
            systemMediumView
        default:
            systemSmallView
        }
    }

    // MARK: - Small Home Screen / StandBy / iPad Lock Screen

    private var systemSmallView: some View {
        ringColumn
            .padding(.top, entry.isConfigured ? 11 : 14)
            .padding(.bottom, entry.isConfigured ? 9 : 14)
            .padding(.horizontal, 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityDescription)
    }

    /// Calorie ring with the consumed / active breakdown footer, shared by the small and medium layouts.
    private var ringColumn: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            let availableHeight = proxy.size.height
            let footerHeight: CGFloat = entry.isConfigured ? max(18, availableHeight * 0.145) : 0
            let footerSpacing: CGFloat = entry.isConfigured ? max(4, availableHeight * 0.04) : 0
            let ringDiameter = min(
                availableWidth,
                max(48, availableHeight - footerHeight - footerSpacing)
            )
            let ringStroke = max(7.0, ringDiameter * 0.085)
            let gap = max(1.8, ringStroke * 0.25)

            VStack(spacing: footerSpacing) {
                ZStack {
                    CalorieRingGraphic(
                        summary: entry.summary,
                        isConfigured: entry.isConfigured,
                        lineWidth: ringStroke,
                        gapWidth: gap
                    )

                    VStack(spacing: 1) {
                        if entry.isConfigured {
                            Text(formattedNumber(entry.summary.displayValue))
                                .font(.system(size: ringDiameter * 0.215, weight: .bold, design: .default))
                                .monospacedDigit()
                                .foregroundStyle(primaryTextColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)

                            Text(entry.summary.statusLabel)
                                .font(.system(size: ringDiameter * 0.112, weight: .regular, design: .default))
                                .foregroundStyle(secondaryTextColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        } else {
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: ringDiameter * 0.18, weight: .semibold))
                                .foregroundStyle(Color(red: 0.13, green: 0.51, blue: 0.96))
                                .widgetAccentable()

                            Text("Set Up")
                                .font(.system(size: ringDiameter * 0.115, weight: .semibold))
                                .foregroundStyle(primaryTextColor)
                        }
                    }
                    .padding(.horizontal, ringStroke + 8)
                }
                .frame(width: ringDiameter, height: ringDiameter)

                if entry.isConfigured {
                    smallWidgetBreakdownFooter(
                        height: footerHeight,
                        availableHeight: availableHeight
                    )
                }
            }
            .frame(width: availableWidth, height: availableHeight, alignment: .center)
        }
    }

    // MARK: - Medium Home Screen

    private var systemMediumView: some View {
        GeometryReader { proxy in
            HStack(spacing: 16) {
                ringColumn
                    .frame(width: min(proxy.size.height, proxy.size.width * 0.45))

                if entry.isConfigured {
                    macroColumn
                } else {
                    mediumSetupPrompt
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(.top, entry.isConfigured ? 11 : 14)
        .padding(.bottom, entry.isConfigured ? 9 : 14)
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mediumAccessibilityDescription)
    }

    /// Protein / carbs / fat rows comparing today's intake to the recommended grams for the calorie goal.
    private var macroColumn: some View {
        VStack(alignment: .leading, spacing: 11) {
            ForEach(entry.summary.macroProgress) { progress in
                macroRow(progress)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func macroRow(_ progress: MacroProgress) -> some View {
        let isOver = progress.fraction > 1.005

        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(progress.kind.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)

                Spacer(minLength: 6)

                Text(formattedNumber(Int(progress.consumedGrams.rounded())))
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)

                Text(" / \(formattedNumber(Int(progress.recommendedGrams.rounded())))g")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
            }
            .minimumScaleFactor(0.8)

            HStack(spacing: 8) {
                MacroProgressBar(
                    fraction: progress.fraction,
                    fillColor: macroFillColor(for: progress.kind),
                    trackColor: macroTrackColor
                )
                .frame(height: 6)

                Text("\(progress.percentage)%")
                    .font(.system(size: 11, weight: isOver ? .bold : .semibold))
                    .monospacedDigit()
                    .foregroundStyle(isOver ? macroFillColor(for: progress.kind) : secondaryTextColor)
                    .lineLimit(1)
                    .frame(minWidth: 34, alignment: .trailing)
            }
        }
    }

    private var mediumSetupPrompt: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Calories & Macros")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(primaryTextColor)

            Text("Connect Apple Health in Tempo Settings to track protein, carbs, and fat.")
                .font(.system(size: 12))
                .foregroundStyle(secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func smallWidgetBreakdownFooter(height: CGFloat, availableHeight: CGFloat) -> some View {
        let iconSize = max(11, availableHeight * 0.10)
        let numberSize = max(12, availableHeight * 0.105)

        return HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(footerConsumedColor)
                    .widgetAccentable()

                Text(formattedNumber(Int(entry.summary.consumedCalories.rounded())))
                    .font(.system(size: numberSize, weight: .medium, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 10)

            Rectangle()
                .fill(footerDividerColor)
                .frame(width: 1, height: max(14, height * 0.85))

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(footerExerciseColor)
                    .widgetAccentable()

                Text(formattedNumber(Int(entry.summary.exerciseCalories.rounded())))
                    .font(.system(size: numberSize, weight: .medium, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10)
        }
        .frame(height: height)
    }

    // MARK: - iPhone Lock Screen Circular

    private var accessoryCircularView: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            let stroke = max(4.08, diameter * 0.08925)
            let gap = max(1.1, stroke * 0.25)

            ZStack {
                CalorieRingGraphic(
                    summary: entry.summary,
                    isConfigured: entry.isConfigured,
                    lineWidth: stroke,
                    gapWidth: gap
                )

                if entry.isConfigured {
                    VStack(spacing: -1) {
                        Text(compactCalorieNumber(entry.summary.displayValue))
                            .font(.system(size: diameter * 0.232, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        Text(entry.summary.isOverBudget ? "OVER" : "LEFT")
                            .font(.system(size: max(7, diameter * 0.135), weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, stroke + 3)
                } else {
                    Image(systemName: "flame.fill")
                        .font(.system(size: diameter * 0.32, weight: .semibold))
                }
            }
            .frame(width: diameter, height: diameter)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - iPhone Lock Screen Rectangular

    private var accessoryRectangularView: some View {
        HStack(spacing: 10) {
            CalorieRingGraphic(
                summary: entry.summary,
                isConfigured: entry.isConfigured,
                lineWidth: 4.675,
                gapWidth: 1.3
            )
            .frame(width: 44, height: 44)

            if entry.isConfigured {
                VStack(alignment: .leading, spacing: 1) {
                    Text(formattedNumber(entry.summary.displayValue))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(entry.summary.statusLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("\(formattedNumber(Int(entry.summary.consumedCalories.rounded()))) in · +\(formattedNumber(Int(entry.summary.exerciseCalories.rounded()))) act")
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Calories")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Connect Apple Health")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Formatting & Colors

    private var primaryTextColor: Color {
        guard renderingMode == .fullColor else { return .primary }
        return colorScheme == .dark ? .white : Color(red: 0.05, green: 0.06, blue: 0.08)
    }

    private var secondaryTextColor: Color {
        guard renderingMode == .fullColor else { return .secondary }
        return colorScheme == .dark ? .white.opacity(0.78) : Color(red: 0.16, green: 0.18, blue: 0.21)
    }

    private var footerConsumedColor: Color {
        guard renderingMode == .fullColor else { return .primary }
        return colorScheme == .dark
            ? Color(red: 0.18, green: 0.54, blue: 0.92)
            : Color(red: 0.13, green: 0.51, blue: 0.96)
    }

    private var footerExerciseColor: Color {
        guard renderingMode == .fullColor else { return .primary }
        return colorScheme == .dark
            ? Color(red: 0.90, green: 0.54, blue: 0.16)
            : Color(red: 0.96, green: 0.58, blue: 0.16)
    }

    private var footerDividerColor: Color {
        guard renderingMode == .fullColor else { return .primary.opacity(0.28) }
        return colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.18)
    }

    private func macroFillColor(for kind: MacroKind) -> Color {
        guard renderingMode == .fullColor else { return .primary }
        let isDark = colorScheme == .dark
        switch kind {
        case .protein:
            return isDark ? Color(red: 0.86, green: 0.29, blue: 0.40) : Color(red: 0.93, green: 0.31, blue: 0.43)
        case .carbs:
            return isDark ? Color(red: 0.22, green: 0.66, blue: 0.43) : Color(red: 0.20, green: 0.72, blue: 0.46)
        case .fat:
            return isDark ? Color(red: 0.57, green: 0.39, blue: 0.87) : Color(red: 0.62, green: 0.41, blue: 0.95)
        }
    }

    private var macroTrackColor: Color {
        guard renderingMode == .fullColor else { return .primary.opacity(0.20) }
        return colorScheme == .dark
            ? Color(red: 0.20, green: 0.21, blue: 0.24)
            : Color(red: 0.89, green: 0.90, blue: 0.92)
    }

    private func formattedNumber(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    private func compactCalorieNumber(_ value: Int) -> String {
        if value >= 10000 {
            let compact = Double(value) / 1000
            return "\(compact.formatted(.number.precision(.fractionLength(1))))k"
        }
        return "\(value)"
    }

    private var accessibilityDescription: String {
        guard entry.isConfigured else {
            return "Daily Calories widget. Open Tempo Settings to connect Apple Health."
        }
        return "\(entry.summary.displayValue) calories \(entry.summary.statusLabel.lowercased()). \(Int(entry.summary.consumedCalories.rounded())) consumed, \(Int(entry.summary.exerciseCalories.rounded())) active burned, daily goal \(Int(entry.summary.dailyGoal.rounded()))."
    }

    private var mediumAccessibilityDescription: String {
        guard entry.isConfigured else { return accessibilityDescription }
        let macros = entry.summary.macroProgress.map { progress in
            "\(progress.kind.title) \(Int(progress.consumedGrams.rounded())) of \(Int(progress.recommendedGrams.rounded())) grams, \(progress.percentage) percent"
        }
        return "\(accessibilityDescription) \(macros.joined(separator: ". "))."
    }
}

/// Horizontal capsule bar showing progress toward a recommended intake; fills completely at or above 100%.
private struct MacroProgressBar: View {
    let fraction: Double
    let fillColor: Color
    let trackColor: Color

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(1, max(0, fraction))
            // Keep any non-zero progress at least as wide as the bar is tall so the rounded cap stays visible.
            let fillWidth = clamped > 0 ? max(proxy.size.height, proxy.size.width * clamped) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)

                Capsule()
                    .fill(fillColor)
                    .frame(width: fillWidth)
                    .widgetAccentable()
            }
        }
    }
}
