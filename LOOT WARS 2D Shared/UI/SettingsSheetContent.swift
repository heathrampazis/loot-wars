//
//  SettingsSheetContent.swift
//  Loot Wars
//
//  What goes inside the menu's sheet: the settings, and the About page behind
//  them.
//
//  Four rows and no more - sound, left-handed controls, the tips again, and About.
//  A short page of things people actually change on a phone reads as finished; a
//  long one reads as a checklist. Each row is its own tap target, the whole width
//  of the card, because a switch thirty points tall is a small thing to aim at
//  and the row it sits on is not.
//
//  Everything is saved the moment it changes (Prefs), so there is no Save button
//  and nothing to lose by closing the sheet.
//

import SpriteKit
import UIKit

/// Something the menu sheet can hold instead of a line of text - see
/// MenuSheetNode.open(title:content:on:).
protocol MenuSheetContent: AnyObject {
    var node: SKNode { get }

    /// How wide the card should be on this screen, or nil for the sheet's usual
    /// width. The How to Play pages ask for more room than a list of switches.
    func preferredCardWidth(for screen: CGSize) -> CGFloat?

    /// Lays the content out for a card this wide and says how tall it came out,
    /// never more than `maxHeight`. The node's origin is the top-centre of the
    /// space it is given; content grows downwards from there.
    func layOut(width: CGFloat, maxHeight: CGFloat) -> CGFloat

    /// A tap on the card, in the content node's own space.
    func tap(at point: CGPoint)

    /// A finger dragging across the card, in the content node's own space - for
    /// content that swipes. Most content ignores these.
    func dragBegan(at point: CGPoint)
    func dragMoved(to point: CGPoint)
    func dragEnded(at point: CGPoint)
}

extension MenuSheetContent {
    func preferredCardWidth(for screen: CGSize) -> CGFloat? { nil }
    func dragBegan(at point: CGPoint) {}
    func dragMoved(to point: CGPoint) {}
    func dragEnded(at point: CGPoint) {}
}

// MARK: - Settings

final class SettingsSheetContent: MenuSheetContent {

    let node = SKNode()

    /// Called when About is tapped. MenuScene swaps the sheet over to it.
    var onAbout: (() -> Void)?

    private enum Row: Int, CaseIterable {
        case sound, leftHanded, tips, about
    }

    private static let rowHeight: CGFloat = 56

    private var width: CGFloat = 0
    private var soundToggle: MenuToggleNode?
    private var handToggle: MenuToggleNode?
    private var tipsButton: SKShapeNode?
    private var tipsLabel: SKLabelNode?

    /// Whether the tips have been reset since the sheet was opened, so the button
    /// can say it worked and not offer to do it twice.
    private var tipsReset = false

    func layOut(width: CGFloat, maxHeight: CGFloat) -> CGFloat {
        self.width = width
        node.removeAllChildren()

        for row in Row.allCases {
            let centreY = -SettingsSheetContent.rowHeight * (CGFloat(row.rawValue) + 0.5)

            if row.rawValue > 0 {
                node.addChild(Sheet.separator(width: width,
                                              y: -SettingsSheetContent.rowHeight * CGFloat(row.rawValue)))
            }

            switch row {
            case .sound:
                addLabels("Sound", detail: nil, y: centreY)
                let toggle = MenuToggleNode(isOn: Prefs.soundOn)
                toggle.position = CGPoint(x: width / 2 - MenuToggleNode.trackSize.width / 2 - 4, y: centreY)
                node.addChild(toggle)
                soundToggle = toggle

            case .leftHanded:
                addLabels("Left-handed controls", detail: "Move on the right, aim on the left", y: centreY)
                let toggle = MenuToggleNode(isOn: Prefs.leftHanded)
                toggle.position = CGPoint(x: width / 2 - MenuToggleNode.trackSize.width / 2 - 4, y: centreY)
                node.addChild(toggle)
                handToggle = toggle

            case .tips:
                addLabels("Show tips again", detail: "Replay the hints from your first match", y: centreY)
                addTipsButton(y: centreY)

            case .about:
                addLabels("About", detail: nil, y: centreY)
                let chevron = Sheet.chevron()
                chevron.position = CGPoint(x: width / 2 - 14, y: centreY)
                node.addChild(chevron)
            }
        }

        return SettingsSheetContent.rowHeight * CGFloat(Row.allCases.count)
    }

    func tap(at point: CGPoint) {
        guard abs(point.x) <= width / 2, point.y <= 0,
              let row = Row(rawValue: Int(-point.y / SettingsSheetContent.rowHeight)) else { return }

        switch row {
        case .sound:
            let on = !Prefs.soundOn
            Prefs.soundOn = on
            soundToggle?.set(on)
            // Heard only when turning it ON, which is the confirmation it worked.
            SoundPlayer.shared.play(.select)

        case .leftHanded:
            Prefs.leftHanded.toggle()
            handToggle?.set(Prefs.leftHanded)
            SoundPlayer.shared.play(.select)

        case .tips:
            guard !tipsReset else { return }
            tipsReset = true
            Prefs.forgetLessons()
            SoundPlayer.shared.play(.select)
            paintTipsButton()
            tipsButton?.run(.sequence([.scale(to: 0.9, duration: 0.05),
                                       .scale(to: 1, duration: 0.12)]))

        case .about:
            SoundPlayer.shared.play(.select)
            onAbout?()
        }
    }

    // MARK: - Pieces

    private func addLabels(_ title: String, detail: String?, y: CGFloat) {
        let left = -width / 2 + 6

        let label = SKLabelNode()
        label.attributedText = Sheet.text(title, size: 16, weight: .bold,
                                          colour: RenderPalette.menuInk)
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: left, y: detail == nil ? y : y + 8)
        node.addChild(label)

        guard let detail else { return }
        let small = SKLabelNode()
        small.attributedText = Sheet.text(detail, size: 12, weight: .regular,
                                          colour: SKColor(white: 0, alpha: 0.45))
        small.horizontalAlignmentMode = .left
        small.verticalAlignmentMode = .center
        small.position = CGPoint(x: left, y: y - 10)
        node.addChild(small)
    }

    private func addTipsButton(y: CGFloat) {
        let size = CGSize(width: 76, height: 30)
        let button = SKShapeNode(rect: CGRect(x: -size.width / 2, y: -size.height / 2,
                                              width: size.width, height: size.height),
                                 cornerRadius: size.height / 2)
        button.lineWidth = 2.5
        button.position = CGPoint(x: width / 2 - size.width / 2 - 4, y: y)
        node.addChild(button)

        let label = SKLabelNode()
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 1
        button.addChild(label)

        tipsButton = button
        tipsLabel = label
        paintTipsButton()
    }

    private func paintTipsButton() {
        if tipsReset {
            tipsButton?.fillColor = SKColor(white: 0.84, alpha: 1)
            tipsButton?.strokeColor = SKColor(white: 0.72, alpha: 1)
            tipsLabel?.attributedText = Sheet.text("Done", size: 13, weight: .bold,
                                                   colour: SKColor(white: 0, alpha: 0.5))
        } else {
            tipsButton?.fillColor = RenderPalette.menuInfo.face
            tipsButton?.strokeColor = RenderPalette.menuInfo.edge
            tipsLabel?.attributedText = Sheet.text("Reset", size: 13, weight: .bold,
                                                   colour: .white)
        }
    }
}

// MARK: - About

/// Who made it, which version this is, and - later - the terms, privacy policy
/// and credits. The rows are placeholders now so the page exists and the links
/// have somewhere to go when the documents are written.
final class AboutSheetContent: MenuSheetContent {

    let node = SKNode()

    /// Called when Back is tapped.
    var onBack: (() -> Void)?

    private static let rowHeight: CGFloat = 44
    private static let headHeight: CGFloat = 58
    private static let items = ["Terms of Service", "Privacy Policy", "Credits"]

    private var width: CGFloat = 0

    func layOut(width: CGFloat, maxHeight: CGFloat) -> CGFloat {
        self.width = width
        node.removeAllChildren()

        let name = SKLabelNode()
        name.attributedText = Sheet.text("Loot Wars", size: 18, weight: .bold,
                                         colour: RenderPalette.menuInk)
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: 0, y: -16)
        node.addChild(name)

        let version = SKLabelNode()
        version.attributedText = Sheet.text(AboutSheetContent.versionText, size: 12,
                                            weight: .regular,
                                            colour: SKColor(white: 0, alpha: 0.45))
        version.verticalAlignmentMode = .center
        version.position = CGPoint(x: 0, y: -38)
        node.addChild(version)

        var top = -AboutSheetContent.headHeight
        for item in AboutSheetContent.items {
            node.addChild(Sheet.separator(width: width, y: top))
            let centreY = top - AboutSheetContent.rowHeight / 2

            let label = SKLabelNode()
            label.attributedText = Sheet.text(item, size: 15, weight: .semibold,
                                              colour: RenderPalette.menuInk)
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: -width / 2 + 6, y: centreY)
            node.addChild(label)

            let soon = SKLabelNode()
            soon.attributedText = Sheet.text("Coming soon", size: 12, weight: .regular,
                                             colour: SKColor(white: 0, alpha: 0.4))
            soon.horizontalAlignmentMode = .right
            soon.verticalAlignmentMode = .center
            soon.position = CGPoint(x: width / 2 - 6, y: centreY)
            node.addChild(soon)

            top -= AboutSheetContent.rowHeight
        }

        node.addChild(Sheet.separator(width: width, y: top))

        let back = SKLabelNode()
        back.attributedText = Sheet.text("‹  Back to settings", size: 14, weight: .bold,
                                         colour: RenderPalette.menuInfo.edge)
        back.verticalAlignmentMode = .center
        back.position = CGPoint(x: 0, y: top - AboutSheetContent.rowHeight / 2)
        node.addChild(back)

        return AboutSheetContent.headHeight
            + AboutSheetContent.rowHeight * CGFloat(AboutSheetContent.items.count + 1)
    }

    func tap(at point: CGPoint) {
        // Only the Back row does anything yet; the document rows light up when
        // there are documents to open.
        let backTop = -AboutSheetContent.headHeight
            - AboutSheetContent.rowHeight * CGFloat(AboutSheetContent.items.count)
        guard abs(point.x) <= width / 2,
              point.y <= backTop, point.y >= backTop - AboutSheetContent.rowHeight else { return }
        SoundPlayer.shared.play(.exit)
        onBack?()
    }

    /// "Version 1.0 (3)", from the app's own Info.plist, so it can never be out of
    /// date with what was actually built.
    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}

// MARK: - Shared drawing

/// Small pieces both pages use.
private enum Sheet {

    static func separator(width: CGFloat, y: CGFloat) -> SKShapeNode {
        let line = SKShapeNode(rect: CGRect(x: -width / 2, y: y - 0.5, width: width, height: 1))
        line.fillColor = SKColor(white: 0, alpha: 0.08)
        line.strokeColor = .clear
        return line
    }

    static func chevron() -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -4, y: 8))
        path.addLine(to: CGPoint(x: 4, y: 0))
        path.addLine(to: CGPoint(x: -4, y: -8))
        let node = SKShapeNode(path: path)
        node.strokeColor = SKColor(white: 0, alpha: 0.35)
        node.lineWidth = 3
        node.lineCap = .round
        node.lineJoin = .round
        return node
    }

    static func text(_ string: String, size: CGFloat, weight: UIFont.Weight,
                     colour: SKColor) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: colour
        ])
    }
}
