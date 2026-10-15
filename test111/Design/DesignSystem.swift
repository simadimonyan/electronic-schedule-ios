//
//  DesignSystem.swift
//  Дизайн-система «Моя Академия»: цвета светлой и тёмной темы, шрифты, тени, радиусы.
//  Значения взяты из макетов design-kit (объект `c`, ветки platform === 'ios').
//

import UIKit

// MARK: - Цвета

extension UIColor {
    /// Цвет из 0xRRGGBB
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: alpha)
    }

    /// Динамический цвет: светлая / тёмная тема
    static func ds(_ light: UIColor, _ dark: UIColor) -> UIColor {
        return UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }
}

enum DS {

    enum Color {
        // Поверхности
        static let bg = UIColor.ds(UIColor(rgb: 0xF8FAFC), UIColor(rgb: 0x0A0F1E))
        static let surface = UIColor.ds(UIColor(rgb: 0xFFFFFF), UIColor(rgb: 0x131A2E))
        static let soft2 = UIColor.ds(UIColor(rgb: 0xF8FAFC), UIColor(rgb: 0x0F1628))
        static let sunk = UIColor.ds(UIColor(rgb: 0xF1F5F9), UIColor(rgb: 0x0A1020))
        static let border = UIColor.ds(UIColor(rgb: 0x0F172A, alpha: 0.08), UIColor(rgb: 0x94A3B8, alpha: 0.12))
        static let borderStrong = UIColor.ds(UIColor(rgb: 0x0F172A, alpha: 0.14), UIColor(rgb: 0x94A3B8, alpha: 0.22))

        // Текст
        static let fg = UIColor.ds(UIColor(rgb: 0x0F172A), UIColor(rgb: 0xF1F5F9))
        static let muted = UIColor.ds(UIColor(rgb: 0x475569), UIColor(rgb: 0xCBD5E1))
        static let soft = UIColor.ds(UIColor(rgb: 0x64748B), UIColor(rgb: 0x94A3B8))
        static let faint = UIColor.ds(UIColor(rgb: 0x94A3B8), UIColor(rgb: 0x64748B))

        // Акцент
        static let accent = UIColor.ds(UIColor(rgb: 0x1A4FDB), UIColor(rgb: 0x60A5FA))
        static let accentSoft = UIColor.ds(UIColor(rgb: 0x1A4FDB, alpha: 0.08), UIColor(rgb: 0x60A5FA, alpha: 0.14))
        static let accentSoft2 = UIColor.ds(UIColor(rgb: 0x1A4FDB, alpha: 0.12), UIColor(rgb: 0x60A5FA, alpha: 0.20))
        static let accentBorder = UIColor.ds(UIColor(rgb: 0x1A4FDB, alpha: 0.25), UIColor(rgb: 0x60A5FA, alpha: 0.35))
        static let sky = UIColor.ds(UIColor(rgb: 0x0EA5E9, alpha: 0.10), UIColor(rgb: 0x0EA5E9, alpha: 0.12))

        /// Фирменный синий — одинаковый в обеих темах (кнопки, выбранные элементы)
        static let brand = UIColor(rgb: 0x1A4FDB)
        static let brandMid = UIColor(rgb: 0x1D6FE0)
        static let brandSky = UIColor(rgb: 0x0EA5E9)

        // Статусы
        static let green = UIColor(rgb: 0x10B981)
        static let amber = UIColor(rgb: 0xF59E0B)
        static let red = UIColor(rgb: 0xEF4444)
        static let okFg = UIColor.ds(UIColor(rgb: 0x047857), UIColor(rgb: 0x34D399))
        static let amberFg = UIColor.ds(UIColor(rgb: 0xB45309), UIColor(rgb: 0xFBBF24))
        static let redFg = UIColor.ds(UIColor(rgb: 0xDC2626), UIColor(rgb: 0xF87171))
        static let danger = UIColor(rgb: 0xDC2626)

        // Стекло (фолбэк до iOS 26)
        static let glassTint = UIColor.ds(UIColor(white: 1, alpha: 0.64), UIColor(rgb: 0x131A2E, alpha: 0.58))
        static let glassEdge = UIColor.ds(UIColor(white: 1, alpha: 0.7), UIColor(rgb: 0x94A3B8, alpha: 0.14))
        static let glassHighlight = UIColor.ds(UIColor(white: 1, alpha: 1), UIColor(white: 1, alpha: 0.14))
        static let sheet = UIColor.ds(UIColor(rgb: 0xF8FAFC, alpha: 0.95), UIColor(rgb: 0x0F1628, alpha: 0.92))
    }

    // MARK: Тип занятия → цвет полоски и чипа

    struct LessonKind {
        let stripe: UIColor
        let chipBg: UIColor
        let chipFg: UIColor

        static func of(_ rawType: String) -> LessonKind {
            let t = rawType.lowercased()
            if t.contains("экзам") || t.contains("зач") {
                return LessonKind(stripe: Color.red, chipBg: UIColor(rgb: 0xEF4444, alpha: 0.12), chipFg: Color.redFg)
            }
            if t.contains("лаб") {
                return LessonKind(stripe: Color.amber, chipBg: UIColor(rgb: 0xF59E0B, alpha: 0.14), chipFg: Color.amberFg)
            }
            if t.contains("лек") {
                return LessonKind(stripe: Color.accent, chipBg: Color.accentSoft, chipFg: Color.accent)
            }
            if t.contains("пр") || t.contains("сем") {
                return LessonKind(stripe: Color.green, chipBg: UIColor(rgb: 0x10B981, alpha: 0.12), chipFg: Color.okFg)
            }
            return LessonKind(stripe: Color.accent, chipBg: Color.accentSoft, chipFg: Color.accent)
        }

        /// Группа для легенды недели
        static func bucket(_ rawType: String) -> Int {
            let t = rawType.lowercased()
            if t.contains("экзам") || t.contains("зач") { return 3 }
            if t.contains("лаб") { return 2 }
            if t.contains("лек") { return 0 }
            return 1
        }
    }

    // MARK: - Шрифты

    enum Font {
        /// Plus Jakarta Sans — заголовки. В шрифте нет кириллицы, поэтому
        /// кириллица берётся из системного шрифта той же насыщенности (как и в вебе).
        static func display(_ size: CGFloat, _ weight: UIFont.Weight = .heavy) -> UIFont {
            let name: String
            switch weight {
            case .heavy, .black: name = "PlusJakartaSans-ExtraBold"
            case .bold: name = "PlusJakartaSans-Bold"
            default: name = "PlusJakartaSans-SemiBold"
            }
            return custom(name, size: size, fallbackWeight: weight)
        }

        /// Inter — основной текст
        static func text(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
            let name: String
            switch weight {
            case .bold, .heavy, .black: name = "Inter-Bold"
            case .semibold: name = "Inter-SemiBold"
            case .medium: name = "Inter-Medium"
            default: name = "Inter-Regular"
            }
            return custom(name, size: size, fallbackWeight: weight)
        }

        /// JetBrains Mono — время, аудитории, цифры
        static func mono(_ size: CGFloat, _ weight: UIFont.Weight = .medium) -> UIFont {
            let name: String
            switch weight {
            case .bold, .heavy, .black: name = "JetBrainsMono-Bold"
            case .semibold: name = "JetBrainsMono-SemiBold"
            case .medium: name = "JetBrainsMono-Medium"
            default: name = "JetBrainsMono-Regular"
            }
            if let font = UIFont(name: name, size: size) { return font }
            return UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        }

        private static func custom(_ name: String, size: CGFloat, fallbackWeight: UIFont.Weight) -> UIFont {
            let system = UIFont.systemFont(ofSize: size, weight: fallbackWeight)
            guard let font = UIFont(name: name, size: size) else { return system }
            let descriptor = font.fontDescriptor.addingAttributes([.cascadeList: [system.fontDescriptor]])
            return UIFont(descriptor: descriptor, size: size)
        }
    }

    // MARK: - Радиусы и отступы

    enum Radius {
        static let card: CGFloat = 16
        static let hero: CGFloat = 20
        static let tile: CGFloat = 14
        static let icon: CGFloat = 9
        static let sheet: CGFloat = 40
    }

    /// Отступы сверху на iOS: шапка (headTop 58) и начало контента (top 116) от верха экрана
    enum Inset {
        static let side: CGFloat = 16
        static let headerHeight: CGFloat = 44
        static let contentBelowHeader: CGFloat = 14
        static let bottomForNav: CGFloat = 132
    }

    // MARK: - Тени

    enum Shadow {
        case none, xs, sm, glass, hero, primary, md

        func apply(to layer: CALayer, traits: UITraitCollection) {
            let dark = traits.userInterfaceStyle == .dark
            layer.shadowOffset = .zero
            layer.shadowOpacity = 0
            layer.shadowRadius = 0
            switch self {
            case .none:
                break
            case .xs:
                guard !dark else { return }
                layer.shadowColor = UIColor(rgb: 0x0F172A).cgColor
                layer.shadowOpacity = 0.04
                layer.shadowOffset = CGSize(width: 0, height: 1)
                layer.shadowRadius = 0.5
            case .sm:
                layer.shadowColor = dark ? UIColor.black.cgColor : UIColor(rgb: 0x0F172A).cgColor
                layer.shadowOpacity = dark ? 0.5 : 0.06
                layer.shadowOffset = CGSize(width: 0, height: 1)
                layer.shadowRadius = 1.5
            case .md:
                layer.shadowColor = dark ? UIColor.black.cgColor : UIColor(rgb: 0x0F172A).cgColor
                layer.shadowOpacity = dark ? 0.5 : 0.08
                layer.shadowOffset = CGSize(width: 0, height: 4)
                layer.shadowRadius = 6
            case .glass:
                layer.shadowColor = dark ? UIColor.black.cgColor : UIColor(rgb: 0x0F172A).cgColor
                layer.shadowOpacity = dark ? 0.5 : 0.10
                layer.shadowOffset = CGSize(width: 0, height: 10)
                layer.shadowRadius = 15
            case .hero:
                layer.shadowColor = Color.brand.cgColor
                layer.shadowOpacity = 0.45
                layer.shadowOffset = CGSize(width: 0, height: 12)
                layer.shadowRadius = 12
            case .primary:
                layer.shadowColor = Color.brand.cgColor
                layer.shadowOpacity = 0.3
                layer.shadowOffset = CGSize(width: 0, height: 6)
                layer.shadowRadius = 9
            }
        }
    }

    // MARK: - Картинки

    enum Image {
        static var logo: UIImage? { UIImage(named: "BrandLogo") }
    }

    /// SF Symbol заданного размера и насыщенности
    static func symbol(_ name: String, size: CGFloat, weight: UIImage.SymbolWeight = .medium) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: weight)
        return UIImage(systemName: name, withConfiguration: config)
    }
}

// MARK: - Текст с трекингом и межстрочным интервалом

extension NSAttributedString {
    static func ds(_ text: String,
                   font: UIFont,
                   color: UIColor,
                   kern: CGFloat = 0,
                   lineHeight: CGFloat? = nil,
                   alignment: NSTextAlignment = .natural) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byTruncatingTail
        if let lineHeight = lineHeight {
            style.minimumLineHeight = lineHeight
            style.maximumLineHeight = lineHeight
        }
        var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
        if kern != 0 { attrs[.kern] = kern }
        return NSAttributedString(string: text, attributes: attrs)
    }
}

extension UILabel {
    /// Метка в стиле дизайн-системы
    static func ds(_ text: String = "",
                   font: UIFont,
                   color: UIColor = DS.Color.fg,
                   kern: CGFloat = 0,
                   lines: Int = 1,
                   lineHeight: CGFloat? = nil,
                   alignment: NSTextAlignment = .natural) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = lines
        label.setDS(text, font: font, color: color, kern: kern, lineHeight: lineHeight, alignment: alignment)
        return label
    }

    func setDS(_ text: String,
               font: UIFont,
               color: UIColor = DS.Color.fg,
               kern: CGFloat = 0,
               lineHeight: CGFloat? = nil,
               alignment: NSTextAlignment = .natural) {
        attributedText = .ds(text, font: font, color: color, kern: kern, lineHeight: lineHeight, alignment: alignment)
        if numberOfLines != 1 {
            lineBreakMode = .byTruncatingTail
        }
    }

    /// Заголовок Plus Jakarta Sans с трекингом -0.025em
    static func display(_ text: String, size: CGFloat, weight: UIFont.Weight = .heavy, color: UIColor = DS.Color.fg, lines: Int = 0, alignment: NSTextAlignment = .natural) -> UILabel {
        return .ds(text, font: DS.Font.display(size, weight), color: color, kern: -0.025 * size, lines: lines, lineHeight: size * 1.08, alignment: alignment)
    }

    /// Надзаголовок: 11px, жирный, разрядка .09em, капсом
    static func eyebrow(_ text: String, size: CGFloat = 11, color: UIColor = DS.Color.faint) -> UILabel {
        return .ds(text.uppercased(), font: DS.Font.text(size, .bold), color: color, kern: 0.09 * size)
    }
}

// MARK: - Мелочи

extension UIView {
    func pinEdges(to other: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: other.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: other.trailingAnchor, constant: -insets.right),
            bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: -insets.bottom)
        ])
    }

    func fixSize(width: CGFloat? = nil, height: CGFloat? = nil) {
        translatesAutoresizingMaskIntoConstraints = false
        if let width = width { widthAnchor.constraint(equalToConstant: width).isActive = true }
        if let height = height { heightAnchor.constraint(equalToConstant: height).isActive = true }
    }
}

extension UIStackView {
    static func ds(_ axis: NSLayoutConstraint.Axis, spacing: CGFloat = 0, alignment: UIStackView.Alignment = .fill, views: [UIView] = []) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = axis
        stack.spacing = spacing
        stack.alignment = alignment
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    func removeAllArranged() {
        arrangedSubviews.forEach { $0.removeFromSuperview() }
    }
}

/// Русские формы: 1 пара, 2 пары, 5 пар
func dsPlural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
    let mod10 = n % 10, mod100 = n % 100
    if mod100 >= 11 && mod100 <= 19 { return many }
    if mod10 == 1 { return one }
    if mod10 >= 2 && mod10 <= 4 { return few }
    return many
}

/// Кнопка с замыканием (UIAction доступен только с iOS 14)
class DSTapControl: UIControl {
    var onTap: (() -> Void)?
    var pressScale: CGFloat = 0.97

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handleTap() { onTap?() }

    override var isHighlighted: Bool {
        didSet {
            guard pressScale < 1 else { return }
            UIView.animate(withDuration: 0.12, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: self.pressScale, y: self.pressScale) : .identity
            }
        }
    }
}
