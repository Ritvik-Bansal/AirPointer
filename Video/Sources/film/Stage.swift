import SwiftUI

/// The room the whole film is set in: a wall and a floor, two flat tones.
struct Room: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Look.wall
            Look.floor.frame(height: Look.size.height - Look.horizon)
        }
    }
}

