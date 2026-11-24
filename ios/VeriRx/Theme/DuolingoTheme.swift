import SwiftUI
import AudioToolbox

// MARK: - Duolingo-Inspired Color Palette
enum DuoColor {
    static let featherGreen = Color(red: 0.345, green: 0.800, blue: 0.008)      // #58CC02
    static let featherGreenShadow = Color(red: 0.345, green: 0.655, blue: 0.000) // #58A700
    static let featherGreenLight = Color(red: 0.843, green: 1.000, blue: 0.722)  // #D7FFB8

    static let macawBlue = Color(red: 0.110, green: 0.690, blue: 0.965)         // #1CB0F6
    static let macawBlueShadow = Color(red: 0.094, green: 0.600, blue: 0.839)   // #1899D6
    static let macawBlueLight = Color(red: 0.867, green: 0.957, blue: 1.000)    // #DDF4FF

    static let cardinalRed = Color(red: 1.000, green: 0.294, blue: 0.294)       // #FF4B4B
    static let cardinalRedShadow = Color(red: 0.918, green: 0.169, blue: 0.169) // #EA2B2B
    static let cardinalRedLight = Color(red: 1.000, green: 0.875, blue: 0.878)  // #FFDFE0

    static let beeYellow = Color(red: 1.000, green: 0.784, blue: 0.000)         // #FFC800
    static let beeYellowShadow = Color(red: 0.898, green: 0.631, blue: 0.000)   // #E5A100

    static let foxOrange = Color(red: 1.000, green: 0.588, blue: 0.000)         // #FF9600
    static let foxOrangeShadow = Color(red: 0.878, green: 0.471, blue: 0.000)   // #E07800

    static let beetlePurple = Color(red: 0.808, green: 0.510, blue: 1.000)      // #CE82FF
    static let beetlePurpleShadow = Color(red: 0.647, green: 0.408, blue: 0.800)// #A568CC

    static let tealPrimary = Color(red: 0.000, green: 0.761, blue: 0.659)       // #00C2A8
    static let tealShadow = Color(red: 0.000, green: 0.580, blue: 0.502)        // #009480

    static let indigoPrimary = Color(red: 0.345, green: 0.400, blue: 0.961)     // #5866F5
    static let indigoShadow = Color(red: 0.247, green: 0.294, blue: 0.788)      // #3F4BC9

    static let rosePrimary = Color(red: 1.000, green: 0.341, blue: 0.502)       // #FF5780
    static let roseShadow = Color(red: 0.831, green: 0.204, blue: 0.369)        // #D4345E

    static let swanGray = Color(red: 0.898, green: 0.898, blue: 0.898)          // #E5E5E5
    static let swanShadow = Color(red: 0.780, green: 0.780, blue: 0.780)        // #C7C7C7
    static let hareGray = Color(red: 0.686, green: 0.686, blue: 0.686)          // #AFAFAF
    static let surfaceBorder = Color(UIColor.separator).opacity(0.45)
}

struct DuoUnitPalette {
    let primary: Color
    let shadow: Color
    let lightTint: Color

    static func forTheme(_ name: String) -> DuoUnitPalette {
        switch name {
        case "emerald":
            return DuoUnitPalette(primary: DuoColor.featherGreen, shadow: DuoColor.featherGreenShadow, lightTint: DuoColor.featherGreenLight)
        case "indigo":
            return DuoUnitPalette(primary: DuoColor.indigoPrimary, shadow: DuoColor.indigoShadow, lightTint: DuoColor.indigoPrimary.opacity(0.14))
        case "rose":
            return DuoUnitPalette(primary: DuoColor.rosePrimary, shadow: DuoColor.roseShadow, lightTint: DuoColor.rosePrimary.opacity(0.14))
        case "purple":
            return DuoUnitPalette(primary: DuoColor.beetlePurple, shadow: DuoColor.beetlePurpleShadow, lightTint: DuoColor.beetlePurple.opacity(0.16))
        case "orange":
            return DuoUnitPalette(primary: DuoColor.foxOrange, shadow: DuoColor.foxOrangeShadow, lightTint: DuoColor.foxOrange.opacity(0.15))
        default:
            return DuoUnitPalette(primary: DuoColor.tealPrimary, shadow: DuoColor.tealShadow, lightTint: DuoColor.tealPrimary.opacity(0.14))
        }
    }
}

// MARK: - Subtle Sound Cues
enum DuoSound {
    static func playTap() {
        AudioServicesPlaySystemSound(1104)
    }

    static func playCorrect() {
        AudioServicesPlaySystemSound(1057)
    }

    static func playWrong() {
        AudioServicesPlaySystemSound(1053)
    }

    static func playCelebration() {
        AudioServicesPlaySystemSound(1025)
    }
}

// MARK: - Chunky 3D Pressable Button Styles
struct Duo3DButtonStyle: ButtonStyle {
    var fill: Color = DuoColor.featherGreen
    var shadow: Color = DuoColor.featherGreenShadow
    var foreground: Color = .white
    var cornerRadius: CGFloat = 16
    var depth: CGFloat = 4
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let activeFill = isDisabled ? DuoColor.swanGray : fill
        let activeShadow = isDisabled ? DuoColor.swanShadow : shadow
        let activeForeground = isDisabled ? DuoColor.hareGray : foreground
        let pressed = configuration.isPressed && !isDisabled

        configuration.label
            .foregroundStyle(activeForeground)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(activeShadow)
                        .offset(y: depth)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(activeFill)
                        .offset(y: pressed ? depth : 0)
                }
            )
            .offset(y: pressed ? depth : 0)
            .padding(.bottom, depth)
            .animation(.spring(response: 0.16, dampingFraction: 0.72), value: pressed)
    }
}

struct DuoTileButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    var isCorrect: Bool = false
    var isWrong: Bool = false
    var isMuted: Bool = false
    var cornerRadius: CGFloat = 14
    var depth: CGFloat = 3

    private var fillColor: Color {
        if isCorrect { return DuoColor.featherGreenLight }
        if isWrong { return DuoColor.cardinalRedLight }
        if isSelected { return DuoColor.macawBlueLight }
        return Color(UIColor.systemBackground)
    }

    private var borderColor: Color {
        if isCorrect { return DuoColor.featherGreen }
        if isWrong { return DuoColor.cardinalRed }
        if isSelected { return DuoColor.macawBlue }
        return DuoColor.swanGray
    }

    private var shadowColor: Color {
        if isCorrect { return DuoColor.featherGreenShadow }
        if isWrong { return DuoColor.cardinalRedShadow }
        if isSelected { return DuoColor.macawBlueShadow }
        return DuoColor.swanShadow
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && !isMuted

        configuration.label
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(shadowColor)
                        .offset(y: depth)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(fillColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(borderColor, lineWidth: 2)
                        )
                        .offset(y: pressed ? depth : 0)
                }
            )
            .offset(y: pressed ? depth : 0)
            .padding(.bottom, depth)
            .opacity(isMuted ? 0.38 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.75), value: pressed)
    }
}

struct DuoNodeButtonStyle: ButtonStyle {
    var fill: Color
    var shadow: Color
    var diameter: CGFloat = 72
    var depth: CGFloat = 7

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        ZStack {
            Circle()
                .fill(shadow)
                .frame(width: diameter, height: diameter)
                .offset(y: depth)

            Circle()
                .fill(fill)
                .frame(width: diameter, height: diameter)
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.28), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .padding(4)
                )
                .offset(y: pressed ? depth : 0)

            configuration.label
                .offset(y: pressed ? depth : 0)
        }
        .padding(.bottom, depth)
        .animation(.spring(response: 0.16, dampingFraction: 0.65), value: pressed)
    }
}

// MARK: - Glossy Duolingo Progress Bar
struct DuoProgressBar: View {
    let progress: Double
    var tint: Color = DuoColor.featherGreen
    var height: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let clamped = max(0, min(1, progress))
            let fillWidth = max(clamped > 0 ? height : 0, geo.size.width * clamped)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DuoColor.swanGray)

                if fillWidth > 0 {
                    Capsule()
                        .fill(tint)
                        .frame(width: fillWidth)
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(Color.white.opacity(0.32))
                                .frame(height: max(3, height * 0.28))
                                .padding(.horizontal, 8)
                                .padding(.top, 3)
                        }
                        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: clamped)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Horizontal Shake Animation
struct DuoShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * shakesPerUnit),
                y: 0
            )
        )
    }
}

// MARK: - True Adaptive FlowLayout for Word-Bank Chips
struct DuoFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return CGSize(
            width: min(maxWidth, totalWidth),
            height: currentY + lineHeight
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }
            view.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
    }
}

// MARK: - Pip the Rx Mascot (Pure SwiftUI Vector Character)
enum RxMascotMood {
    case idle
    case happy
    case excited
    case encouraging
    case celebrating
}

struct RxMascotView: View {
    var mood: RxMascotMood = .idle
    var accentColor: Color = DuoColor.featherGreen
    var size: CGFloat = 68

    @State private var bobbing = false

    var body: some View {
        ZStack {
            // Soft ground shadow
            Ellipse()
                .fill(Color.black.opacity(0.08))
                .frame(width: size * 0.72, height: size * 0.16)
                .offset(y: size * 0.46)

            // Mascot body (friendly rounded pill-owl)
            ZStack {
                // Little ear tufts
                HStack(spacing: size * 0.34) {
                    Circle().fill(accentColor).frame(width: size * 0.24, height: size * 0.24)
                    Circle().fill(accentColor).frame(width: size * 0.24, height: size * 0.24)
                }
                .offset(y: -size * 0.34)

                // Capsule-owl body
                RoundedRectangle(cornerRadius: size * 0.40, style: .continuous)
                    .fill(accentColor)
                    .frame(width: size * 0.84, height: size * 0.86)
                    .overlay(alignment: .bottom) {
                        // White belly patch with subtle Rx emblem
                        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                            .fill(Color.white.opacity(0.92))
                            .frame(width: size * 0.56, height: size * 0.34)
                            .overlay {
                                Text("Rx")
                                    .font(.system(size: size * 0.17, weight: .black, design: .rounded))
                                    .foregroundStyle(accentColor)
                            }
                            .padding(.bottom, size * 0.08)
                    }

                // Expressive eyes
                HStack(spacing: size * 0.14) {
                    eyeView
                    eyeView
                }
                .offset(y: -size * 0.11)

                // Cute beak / mouth
                beakView
                    .offset(y: size * 0.03)

                // Celebration sparkle
                if mood == .celebrating || mood == .excited {
                    Image(systemName: "sparkle")
                        .font(.system(size: size * 0.22, weight: .bold))
                        .foregroundStyle(DuoColor.beeYellow)
                        .offset(x: size * 0.42, y: -size * 0.36)
                }
            }
            .offset(y: bobbing ? -3 : 1)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                bobbing = true
            }
        }
    }

    @ViewBuilder
    private var eyeView: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: size * 0.24, height: size * 0.24)

            if mood == .happy || mood == .celebrating {
                // Cheerful squinting arc
                Circle()
                    .trim(from: 0.55, to: 0.95)
                    .stroke(Color.black.opacity(0.85), style: StrokeStyle(lineWidth: max(2, size * 0.045), lineCap: .round))
                    .frame(width: size * 0.13, height: size * 0.13)
                    .offset(y: size * 0.02)
            } else {
                Circle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: size * 0.11, height: size * 0.11)
                    .offset(y: mood == .encouraging ? size * 0.02 : 0)

                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.04, height: size * 0.04)
                    .offset(x: -size * 0.025, y: -size * 0.025)
            }
        }
    }

    private var beakView: some View {
        Capsule()
            .fill(DuoColor.beeYellow)
            .frame(width: size * 0.14, height: size * 0.08)
    }
}
