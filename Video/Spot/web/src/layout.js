// Where things are. Metres, y up, the desk at y = 0, the viewer toward +z.

/// The laptop: a plain aluminium notebook of ordinary size, open on the desk.
export const LAPTOP = {
  width: 0.3041, depth: 0.2150, base: 0.0112, lidThick: 0.0040,
  centre: [0, 0, -0.50],
  /// How far the lid is tipped back from upright, degrees.
  tilt: 17,
  /// The lit area of the display: the shape of a 13-inch notebook's, a little taller than 16 by 10.
  screenWidth: 0.2880, screenHeight: 0.1872,
  bezel: 0.0058,
}

/// The display's lit rectangle in the world: its centre, its right and up directions, the
/// direction it faces, and its size.
export const SCREEN = (() => {
  const tilt = LAPTOP.tilt * Math.PI / 180
  const hinge = [0, LAPTOP.base + 0.0015, LAPTOP.centre[2] - LAPTOP.depth / 2 + 0.0045]
  const up = [0, Math.cos(tilt), -Math.sin(tilt)]
  const facing = [0, Math.sin(tilt), Math.cos(tilt)]
  // The lit area sits a bezel's width below the lid's top edge.
  const reach = LAPTOP.depth - LAPTOP.bezel - LAPTOP.screenHeight / 2 - 0.0005
  const centre = [
    hinge[0] + up[0] * reach + facing[0] * 0.0012,
    hinge[1] + up[1] * reach + facing[1] * 0.0012,
    hinge[2] + up[2] * reach + facing[2] * 0.0012,
  ]
  return { hinge, up, facing, right: [1, 0, 0], centre, width: LAPTOP.screenWidth, height: LAPTOP.screenHeight, tilt }
})()

/// Where the case is held: in front of the Mac, about where a hand would be.
export const CASE = [0, 0.158, 0.02]

/// The screen's contents are laid out in points, as on a real display.
export const UI = {
  width: 1280, height: 832,
  /// Texture pixels per point: two for a 1080p film, where the window is never shown larger
  /// than about one and a half, and three for 4K. (The preview page asks for fewer still.)
  scale: (() => {
    const query = new URLSearchParams(globalThis.location ? globalThis.location.search : '')
    return Number(query.get('ui')) || (Number(query.get('scale') || 1) > 1 ? 3 : 2)
  })(),
  menuBar: 24,
  /// The AirPointer window, as the app draws it: 880 by 672.
  window: { x: 200, y: 62, w: 880, h: 672 },
  panel: { x: 432.8, y: 52.8, w: 428, h: 537.6, trackFrom: 504, trackWidth: 285.6 },
}

/// The world position of a point on the screen, given in the screen's own points.
export function screenPoint(px, py) {
  const u = (px / UI.width - 0.5) * SCREEN.width
  const v = (0.5 - py / UI.height) * SCREEN.height
  return [
    SCREEN.centre[0] + SCREEN.right[0] * u + SCREEN.up[0] * v,
    SCREEN.centre[1] + SCREEN.right[1] * u + SCREEN.up[1] * v,
    SCREEN.centre[2] + SCREEN.right[2] * u + SCREEN.up[2] * v,
  ]
}
