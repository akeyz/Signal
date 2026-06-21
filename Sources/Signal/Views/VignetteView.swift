import SwiftUI

struct VignetteView: View {
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            let maxDimension = max(geo.size.width, geo.size.height)
            ZStack {
                // Soft edge glow using radial gradient
                RadialGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        color.opacity(0.12),
                        color.opacity(0.4)
                    ]),
                    center: .center,
                    startRadius: maxDimension * 0.35,
                    endRadius: maxDimension * 0.65
                )
                
                // Intense border glow using thick stroked rectangle
                Rectangle()
                    .stroke(color, lineWidth: 24)
                    .blur(radius: 20)
                    .padding(-12) // Keep the blur from getting cut off at the window bounds
                    .opacity(0.7)
            }
        }
        .ignoresSafeArea()
    }
}

struct OverlayContentView: View {
    @ObservedObject var viewModel: ScreenOverlayViewModel
    
    var body: some View {
        VignetteView(color: viewModel.overlayColor)
            .opacity(viewModel.opacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
