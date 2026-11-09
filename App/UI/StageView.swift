import PointerKit
import SwiftUI

/// The room: a pale wall for the screen to hang on, and a floor, a shade deeper, for the
/// case to stand on. The line where they meet passes behind the case.
struct StageBackground: View {
    /// How far down the window the wall meets the floor.
    static let horizon = 0.628

    var body: some View {
        GeometryReader { proxy in
            let y = proxy.size.height * Self.horizon
            ZStack(alignment: .top) {
                Theme.stageFloor
                // Wall: brightest at the top, where the light is.
                LinearGradient(colors: [Theme.panel.opacity(0.55), Theme.stage, Theme.stage], startPoint: .top, endPoint: .bottom)
                    .background(Theme.stage)
                    .frame(height: y)
                // Floor: lightest where it meets the wall, deepening toward the viewer.
                LinearGradient(colors: [Theme.stage.opacity(0.75), Theme.stageFloor.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 90)
                    .offset(y: y)
                // The skirting line, fading out toward the sides.
                LinearGradient(
                    colors: [Theme.hairline.opacity(0), Theme.hairline, Theme.hairline, Theme.hairline.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 1)
                .offset(y: y)
            }
        }
        .ignoresSafeArea()
    }
}
