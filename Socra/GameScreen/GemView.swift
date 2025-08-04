// GemView.swift (Hardened: Added error state visualization)
import SwiftUI

struct GemView: View {
    @Binding var state: GemState  // Binding to control the state from parent
    
    @State private var processingRotation: Double = 0
    
    private let size: CGFloat = 100  // Base size of the gem
    
    var body: some View {
        ZStack {
            // Glow Effect Layer
            gemShape
                .fill(gemGradient)
                .blur(radius: 20)
                .opacity(0.8)
                .frame(width: size, height: size)
            
            // Main Gem
            gemShape
                .fill(gemGradient)
                .frame(width: size, height: size)
                .shadow(color: glowColor.opacity(0.6), radius: 15)
                .shadow(color: glowColor.opacity(0.4), radius: 30)
                .overlay(
                    // Inner glow and shadow for depth
                    gemShape
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .blur(radius: 2)
                )
            
            // Facets (triangular overlays for 3D effect)
            facetTop
            facetBottom
            
            // Sparkles
            SparklesView()
                .frame(width: size, height: size)
        }
        .rotationEffect(.degrees(rotationAngle + processingRotation))
        .scaleEffect(scaleFactor)
        .animation(.easeInOut(duration: 0.4), value: state)
        .scaleEffect(pulseScale)
        .animation(pulseAnimation, value: state)
        .onChange(of: state) {
            if state == .processing {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    processingRotation += 360
                }
            } else {
                withAnimation(nil) {
                    processingRotation = 0
                }
            }
        }
    }
    
    // Custom diamond shape for the gem
    private var gemShape: some Shape {
        DiamondShape()
    }
    
    // Top facet triangle
    private var facetTop: some View {
        Triangle()
            .fill(topFacetColor)
            .frame(width: size, height: 15)
            .offset(y: -size / 2 - 7.5)  // Position above the diamond
            .rotationEffect(.degrees(rotationAngle + processingRotation))  // Sync rotation
    }
    
    // Bottom facet triangle
    private var facetBottom: some View {
        Triangle()
            .fill(bottomFacetColor)
            .frame(width: size, height: 15)
            .rotationEffect(.degrees(180))  // Invert for bottom
            .offset(y: size / 2 + 7.5)  // Position below the diamond
            .rotationEffect(.degrees(rotationAngle + processingRotation))  // Sync rotation
    }
    
    // State-dependent properties
    private var gemGradient: LinearGradient {
        switch state {
        case .idle:
            return LinearGradient(gradient: Gradient(colors: [Color(hex: "#3a7bd5"), Color(hex: "#00d2ff")]), startPoint: .topLeading, endPoint: .bottomTrailing)
        case .listening:
            return LinearGradient(gradient: Gradient(colors: [Color(hex: "#1dd1a1"), Color(hex: "#10ac84")]), startPoint: .topLeading, endPoint: .bottomTrailing)
        case .talking:
            return LinearGradient(gradient: Gradient(colors: [Color(hex: "#ff6b6b"), Color(hex: "#ee5253")]), startPoint: .topLeading, endPoint: .bottomTrailing)
        case .processing:
            return LinearGradient(gradient: Gradient(colors: [Color(hex: "#9b59b6"), Color(hex: "#8e44ad")]), startPoint: .topLeading, endPoint: .bottomTrailing)
        case .errorRetry:
            return LinearGradient(gradient: Gradient(colors: [Color(hex: "#e74c3c"), Color(hex: "#c0392b")]), startPoint: .topLeading, endPoint: .bottomTrailing)  // Red for error
        }
    }
    
    private var glowColor: Color {
        switch state {
        case .idle: return Color(hex: "#3a7bd5")
        case .listening: return Color(hex: "#1dd1a1")
        case .talking: return Color(hex: "#ff6b6b")
        case .processing: return Color(hex: "#9b59b6")
        case .errorRetry: return Color(hex: "#e74c3c")
        }
    }
    
    private var topFacetColor: Color {
        switch state {
        case .idle: return Color(hex: "#5c9eff")
        case .listening: return Color(hex: "#48e6b8")
        case .talking: return Color(hex: "#ff8b8b")
        case .processing: return Color(hex: "#bb8fce")
        case .errorRetry: return Color(hex: "#ff6b6b")
        }
    }
    
    private var bottomFacetColor: Color {
        switch state {
        case .idle: return Color(hex: "#2a6bc8")
        case .listening: return Color(hex: "#0d8f6a")
        case .talking: return Color(hex: "#d64243")
        case .processing: return Color(hex: "#7d3c98")
        case .errorRetry: return Color(hex: "#a93226")
        }
    }
    
    private var rotationAngle: Double {
        switch state {
        case .idle: return 0
        case .listening: return 90
        case .talking: return -90
        case .processing: return 0
        case .errorRetry: return 0  // Steady for error
        }
    }
    
    private var scaleFactor: CGFloat {
        switch state {
        case .idle: return 1.0
        case .listening: return 0.95
        case .talking: return 1.0
        case .processing: return 1.05
        case .errorRetry: return 0.9  // Smaller for attention
        }
    }
    
    private var pulseScale: CGFloat {
        1.0  // Placeholder; actual pulsing handled by animation modifier
    }
    
    private var pulseAnimation: Animation? {
        switch state {
        case .idle:
            return .easeInOut(duration: 4).repeatForever(autoreverses: true)
        case .listening:
            return .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
        case .talking:
            return .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
       case .processing:
            return .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
        case .errorRetry:
            return .easeInOut(duration: 0.3).repeatCount(3, autoreverses: true)  // Quick pulse for error
        }
    }
}

// Custom Diamond Shape
struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: CGPoint(x: center.x, y: center.y - radius))
        path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        path.addLine(to: CGPoint(x: center.x - radius, y: center.y))
        path.closeSubpath()
        return path
    }
}

// Custom Triangle Shape for facets
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

// Sparkles View with animation
struct SparklesView: View {
    @State private var sparklePhase: Double = 0
    
    var body: some View {
        ZStack {
            ForEach(0..<4) { i in
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
                    .shadow(color: .white, radius: 5)
                    .shadow(color: .white, radius: 10)
                    .shadow(color: .white, radius: 15)
                    .offset(sparkleOffset(for: i))
                    .opacity(sparkleOpacity)
                    .rotationEffect(.degrees(sparkleRotation))
                    .scaleEffect(sparkleScale)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(Double(i) * 0.5), value: sparklePhase)
            }
        }
        .onAppear {
            sparklePhase = 1
        }
    }
    
    private func sparkleOffset(for index: Int) -> CGSize {
        switch index {
        case 0: return CGSize(width: -40, height: -40)
        case 1: return CGSize(width: 40, height: -40)
        case 2: return CGSize(width: -40, height: 40)
        case 3: return CGSize(width: 40, height: 40)
        default: return .zero
        }
    }
    
    private var sparkleOpacity: Double {
        sparklePhase > 0.5 ? 1 : 0
    }
    
    private var sparkleRotation: Double {
        sparklePhase * 180
    }
    
    private var sparkleScale: CGFloat {
        sparklePhase > 0.5 ? 1 : 0.5
    }
}

// Extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
