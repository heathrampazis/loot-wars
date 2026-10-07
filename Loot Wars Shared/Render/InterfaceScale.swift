//
//  InterfaceScale.swift
//  Loot Wars
//
//  How much bigger the buttons, panels and text are drawn on a big screen.
//
//  The scene is the view's size in points, so on an iPad every control came out
//  at its phone size on a screen that is far bigger, and read as tiny. The map
//  already zooms in to match a phone (GridGeometry.zoom), so the interface has to
//  grow with it or the two feel out of step.
//

import CoreGraphics

enum InterfaceScale {

    /// The phone everything was laid out on, in landscape points.
    static let referenceScreen = CGSize(width: 844, height: 390)

    /// The narrowest screen the layout fits, in points. A scaled interface never
    /// gets less room than this across, or the top row would collide.
    static let narrowestLayout: CGFloat = 667

    /// Anything shorter than this is a phone, and keeps the layout it has.
    static let tabletHeight: CGFloat = 600

    /// One on every phone. On a tablet, enough to cover the same share of the
    /// screen as on the reference phone: matched by area, like the map's zoom, and
    /// held back so the layout always has a phone's width to work in.
    static func factor(for screen: CGSize) -> CGFloat {
        let long = max(screen.width, screen.height)
        let short = min(screen.width, screen.height)
        guard short >= tabletHeight else { return 1 }

        let byArea = ((long * short) / (referenceScreen.width * referenceScreen.height)).squareRoot()
        let byWidth = long / narrowestLayout
        return max(1, min(byArea, byWidth))
    }

    /// The screen in the interface's own points, once the factor is taken out.
    static func size(for screen: CGSize) -> CGSize {
        let k = factor(for: screen)
        return CGSize(width: screen.width / k, height: screen.height / k)
    }
}
