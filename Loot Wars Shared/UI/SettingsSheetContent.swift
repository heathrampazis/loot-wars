//
//  SettingsSheetContent.swift
//  Loot Wars
//
//  What goes inside the menu's sheet: the settings, and the About page behind
//  them.
//
//  A short list - sound, left-handed controls, assisted controls, difficulty, tips
//  on or off, and About. (Dev mode no longer has a row - see Prefs.devMode.)
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
        case sound, leftHanded, easyControls, difficulty, tips, about
    }

    private static let rowHeight: CGFloat = 56

    /// The row height actually used: the full 56 where there is room, a little
    /// less on a short screen so every row still fits.
    private var rowHeight: CGFloat = SettingsSheetContent.rowHeight

    private var width: CGFloat = 0
    private var difficultyButton: SKShapeNode?
    private var difficultyLabel: SKLabelNode?
    private var soundToggle: MenuToggleNode?
    private var handToggle: MenuToggleNode?
    private var easyToggle: MenuToggleNode?
    private var tipsToggle: MenuToggleNode?


    func layOut(width: CGFloat, maxHeight: CGFloat) -> CGFloat {
        self.width = width
        node.removeAllChildren()
        rowHeight = max(44, min(SettingsSheetContent.rowHeight,
                                (maxHeight / CGFloat(Row.allCases.count)).rounded(.down)))

        for row in Row.allCases {
            let centreY = -rowHeight * (CGFloat(row.rawValue) + 0.5)

            if row.rawValue > 0 {
                node.addChild(Sheet.separator(width: width,
                                              y: -rowHeight * CGFloat(row.rawValue)))
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

            case .easyControls:
                addLabels("Assisted controls", detail: "Aim assist and auto healing", y: centreY)
                let toggle = MenuToggleNode(isOn: Prefs.easyControls)
                toggle.position = CGPoint(x: width / 2 - MenuToggleNode.trackSize.width / 2 - 4, y: centreY)
                node.addChild(toggle)
                easyToggle = toggle

            case .difficulty:
                addLabels("Difficulty", detail: "How hard the other players are", y: centreY)
                addDifficultyButton(y: centreY)

            case .tips:
                addLabels("Tips", detail: "Hints while you play", y: centreY)
                let toggle = MenuToggleNode(isOn: Prefs.tipsOn)
                toggle.position = CGPoint(x: width / 2 - MenuToggleNode.trackSize.width / 2 - 4, y: centreY)
                node.addChild(toggle)
                tipsToggle = toggle

            case .about:
                addLabels("About", detail: nil, y: centreY)
                let chevron = Sheet.chevron()
                chevron.position = CGPoint(x: width / 2 - 14, y: centreY)
                node.addChild(chevron)
            }
        }

        return rowHeight * CGFloat(Row.allCases.count)
    }

    func tap(at point: CGPoint) {
        guard abs(point.x) <= width / 2, point.y <= 0,
              let row = Row(rawValue: Int(-point.y / rowHeight)) else { return }

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

        case .easyControls:
            Prefs.easyControls.toggle()
            easyToggle?.set(Prefs.easyControls)
            SoundPlayer.shared.play(.select)

        case .difficulty:
            Prefs.difficulty = Prefs.difficulty.next
            SoundPlayer.shared.play(.select)
            paintDifficultyButton()
            difficultyButton?.run(.sequence([.scale(to: 0.9, duration: 0.05),
                                             .scale(to: 1, duration: 0.12)]))

        case .tips:
            Prefs.tipsOn.toggle()
            tipsToggle?.set(Prefs.tipsOn)
            SoundPlayer.shared.play(.select)

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

    /// Easy, Medium, Hard or Hardcore, on a pill. Tapping the row steps to the
    /// next one round; the next match is played on whichever it shows.
    private func addDifficultyButton(y: CGFloat) {
        let size = CGSize(width: 92, height: 30)
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

        difficultyButton = button
        difficultyLabel = label
        paintDifficultyButton()
    }

    private func paintDifficultyButton() {
        let difficulty = Prefs.difficulty
        let tone: RenderPalette.MenuTone
        switch difficulty {
        case .easy:     tone = RenderPalette.menuPlay
        case .medium:   tone = RenderPalette.menuCaution
        case .hard:     tone = RenderPalette.menuSettings
        case .hardcore: tone = RenderPalette.menuDanger
        }
        difficultyButton?.fillColor = tone.face
        difficultyButton?.strokeColor = tone.edge
        difficultyLabel?.attributedText = Sheet.text(difficulty.title, size: 13, weight: .bold,
                                                     colour: .white)
    }
}

// MARK: - About

/// The game's name and version, and the Terms of Use and Privacy Policy.
final class AboutSheetContent: MenuSheetContent {

    let node = SKNode()

    /// Called when Back is tapped.
    var onBack: (() -> Void)?

    /// Called when Terms of Use or Privacy Policy is tapped.
    var onOpen: ((LegalDocument) -> Void)?

    private static let rowHeight: CGFloat = 44
    private static let headHeight: CGFloat = 58
    private static let items = ["Terms of Use", "Privacy Policy"]

    /// What each row opens.
    private static let documents: [LegalDocument] = [.terms, .privacy]

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

            let chevron = Sheet.chevron()
            chevron.position = CGPoint(x: width / 2 - 10, y: centreY)
            node.addChild(chevron)

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
        guard abs(point.x) <= width / 2 else { return }

        // A document row opens it.
        let row = Int((-AboutSheetContent.headHeight - point.y) / AboutSheetContent.rowHeight)
        if point.y <= -AboutSheetContent.headHeight,
           AboutSheetContent.documents.indices.contains(row) {
            SoundPlayer.shared.play(.select)
            onOpen?(AboutSheetContent.documents[row])
            return
        }

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
