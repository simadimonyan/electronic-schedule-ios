//
//  DSComponents.swift
//  Базовые компоненты дизайн-системы: стекло, карточки, фон, кнопки, сегменты, тост.
//

import UIKit

// MARK: - Стекло

/// Стеклянный материал iOS-макетов (`mat`): blur + полупрозрачность + внутренняя подсветка.
/// На iOS 26 — системное «жидкое стекло» (UIGlassEffect), ниже — UIVisualEffectView с подложкой.
final class GlassView: UIView {
    /// Сюда добавляется содержимое
    let contentView = UIView()
    var cornerRadius: CGFloat = 22 { didSet { setNeedsLayout() } }
    /// Капсула: радиус = половина высоты
    var isCapsule = false { didSet { setNeedsLayout() } }
    var shadowStyle: DS.Shadow = .glass { didSet { applyTraits() } }

    private let effectView: UIVisualEffectView
    private let tintView = UIView()
    private let highlight = CALayer()
    private let edge = CALayer()
    private let usesSystemGlass: Bool

    init(interactive: Bool = false) {
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect(style: .regular)
            glass.isInteractive = interactive
            effectView = UIVisualEffectView(effect: glass)
            usesSystemGlass = true
        } else {
            effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
            usesSystemGlass = false
        }
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        effectView.clipsToBounds = true
        addSubview(effectView)
        effectView.pinEdges(to: self)

        if !usesSystemGlass {
            tintView.backgroundColor = DS.Color.glassTint
            effectView.contentView.addSubview(tintView)
            tintView.pinEdges(to: effectView.contentView)
            effectView.layer.addSublayer(edge)
            effectView.layer.addSublayer(highlight)
            edge.borderWidth = 1
        }

        effectView.contentView.addSubview(contentView)
        contentView.pinEdges(to: effectView.contentView)
        applyTraits()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = isCapsule ? bounds.height / 2 : cornerRadius
        if usesSystemGlass, #available(iOS 26.0, *) {
            effectView.cornerConfiguration = .corners(radius: .fixed(radius))
        } else {
            effectView.layer.cornerRadius = radius
            if #available(iOS 13.0, *) { effectView.layer.cornerCurve = .continuous }
            edge.frame = bounds
            edge.cornerRadius = radius
            // Внутренняя подсветка сверху: тонкая линия по верхней кромке
            highlight.frame = CGRect(x: radius * 0.6, y: 0, width: max(0, bounds.width - radius * 1.2), height: 1)
        }
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTraits()
    }

    private func applyTraits() {
        shadowStyle.apply(to: layer, traits: traitCollection)
        edge.borderColor = DS.Color.glassEdge.resolvedColor(with: traitCollection).cgColor
        highlight.backgroundColor = DS.Color.glassHighlight.resolvedColor(with: traitCollection).cgColor
    }
}

// MARK: - Карточка

/// Поверхность с границей 1px, радиусом и тенью — `surface` + `border` + `shXs/shSm` из макетов
class CardView: UIView {
    var fill: UIColor = DS.Color.surface { didSet { applyTraits() } }
    var borderColor: UIColor? = DS.Color.border { didSet { applyTraits() } }
    var borderWidth: CGFloat = 1 { didSet { applyTraits() } }
    var shadow: DS.Shadow = .xs { didSet { applyTraits() } }
    var radius: CGFloat = DS.Radius.card { didSet { setNeedsLayout() } }
    /// Пунктирная граница (пустые состояния)
    var dashed = false { didSet { applyTraits() } }

    private let dashLayer = CAShapeLayer()

    init(radius: CGFloat = DS.Radius.card, shadow: DS.Shadow = .xs) {
        self.radius = radius
        self.shadow = shadow
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        dashLayer.fillColor = UIColor.clear.cgColor
        dashLayer.lineDashPattern = [4, 3]
        dashLayer.lineWidth = 1
        layer.addSublayer(dashLayer)
        applyTraits()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = radius
        if #available(iOS 13.0, *) { layer.cornerCurve = .continuous }
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
        dashLayer.frame = bounds
        dashLayer.path = UIBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerRadius: radius).cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTraits()
    }

    func applyTraits() {
        backgroundColor = fill
        if dashed {
            layer.borderWidth = 0
            dashLayer.isHidden = false
            dashLayer.strokeColor = (borderColor ?? DS.Color.borderStrong).resolvedColor(with: traitCollection).cgColor
        } else {
            dashLayer.isHidden = true
            layer.borderWidth = borderColor == nil ? 0 : borderWidth
            layer.borderColor = borderColor?.resolvedColor(with: traitCollection).cgColor
        }
        shadow.apply(to: layer, traits: traitCollection)
    }
}

/// Карточка, у которой содержимое обрезается по радиусу (тень рисует внешняя обёртка)
final class ClippedCardView: UIView {
    let card = CardView()
    let content = UIView()

    init(radius: CGFloat = DS.Radius.card, shadow: DS.Shadow = .xs) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        card.radius = radius
        card.shadow = shadow
        addSubview(card)
        card.pinEdges(to: self)
        content.translatesAutoresizingMaskIntoConstraints = false
        content.clipsToBounds = true
        content.layer.cornerRadius = radius
        if #available(iOS 13.0, *) { content.layer.cornerCurve = .continuous }
        addSubview(content)
        content.pinEdges(to: self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Фон с сиянием и сеткой

/// Декоративный фон верхней части экрана: радиальные пятна акцента и сетка 28px
final class BackdropView: UIView {
    private let glowA = CAGradientLayer()
    private let glowB = CAGradientLayer()
    private let fadeMask = CAGradientLayer()
    private let gridView = GridView()
    private let gridMask = CAGradientLayer()
    var showsGrid = true { didSet { gridView.isHidden = !showsGrid } }
    var showsSky = true { didSet { glowB.isHidden = !showsSky } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        translatesAutoresizingMaskIntoConstraints = false
        let glows = UIView()
        glows.isUserInteractionEnabled = false
        addSubview(glows)
        glows.pinEdges(to: self)
        glowA.type = .radial
        glowB.type = .radial
        glows.layer.addSublayer(glowA)
        glows.layer.addSublayer(glowB)
        fadeMask.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        fadeMask.locations = [0, 0.6, 1]
        glows.layer.mask = fadeMask

        addSubview(gridView)
        gridView.pinEdges(to: self)
        gridMask.type = .radial
        gridMask.colors = [UIColor.black.cgColor, UIColor.clear.cgColor]
        gridMask.locations = [0, 0.72]
        gridMask.startPoint = CGPoint(x: 0.6, y: 0.25)
        gridMask.endPoint = CGPoint(x: 1.3, y: 0.95)
        gridView.layer.mask = gridMask
        applyTraits()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // radial-gradient(70% 60% at 100% 0%, accentSoft2, transparent 62%)
        glowA.frame = bounds
        glowA.startPoint = CGPoint(x: 1, y: 0)
        glowA.endPoint = CGPoint(x: 1.7, y: 0.6)
        glowA.locations = [0, 0.62]
        // radial-gradient(55% 45% at 0% 70%, sky, transparent 62%)
        glowB.frame = bounds
        glowB.startPoint = CGPoint(x: 0, y: 0.7)
        glowB.endPoint = CGPoint(x: 0.55, y: 1.15)
        glowB.locations = [0, 0.62]
        fadeMask.frame = bounds
        gridMask.frame = bounds
        CATransaction.commit()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTraits()
    }

    private func applyTraits() {
        let a = DS.Color.accentSoft2.resolvedColor(with: traitCollection)
        let b = DS.Color.sky.resolvedColor(with: traitCollection)
        glowA.colors = [a.cgColor, a.withAlphaComponent(0).cgColor]
        glowB.colors = [b.cgColor, b.withAlphaComponent(0).cgColor]
        gridView.setNeedsDisplay()
    }

    private final class GridView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            isOpaque = false
            backgroundColor = .clear
            contentMode = .redraw
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func draw(_ rect: CGRect) {
            guard let ctx = UIGraphicsGetCurrentContext() else { return }
            ctx.setFillColor(DS.Color.border.resolvedColor(with: traitCollection).cgColor)
            let step: CGFloat = 28
            var x: CGFloat = 0
            while x < bounds.width { ctx.fill(CGRect(x: x, y: 0, width: 1, height: bounds.height)); x += step }
            var y: CGFloat = 0
            while y < bounds.height { ctx.fill(CGRect(x: 0, y: y, width: bounds.width, height: 1)); y += step }
        }

        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            setNeedsDisplay()
        }
    }
}

// MARK: - Надзаголовок-пилюля

/// `eb`-пилюля: точка + капс, accentSoft / accent
final class EyebrowPill: UIView {
    private let label = UILabel()
    private let dot = UIView()

    init(_ text: String, size: CGFloat = 11, tint: UIColor = DS.Color.accent, fill: UIColor = DS.Color.accentSoft, showsDot: Bool = true) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = fill
        dot.backgroundColor = tint
        dot.layer.cornerRadius = 2.5
        dot.fixSize(width: 5, height: 5)
        label.translatesAutoresizingMaskIntoConstraints = false
        let stack = UIStackView.ds(.horizontal, spacing: 6, alignment: .center, views: showsDot ? [dot, label] : [label])
        addSubview(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10))
        setText(text, size: size, tint: tint)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setText(_ text: String, size: CGFloat = 11, tint: UIColor = DS.Color.accent) {
        label.setDS(text.uppercased(), font: DS.Font.text(size, .bold), color: tint, kern: 0.09 * size)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}

// MARK: - Кнопки

final class DSButton: DSTapControl {
    enum Style { case primary, secondary, outlineAccent, ghost, white, danger }

    private let titleLabel = UILabel()
    private let iconView = UIImageView()
    private let stack = UIStackView()
    private let style: Style
    private let fontSize: CGFloat
    private let border = CardView(radius: 0, shadow: .none)
    var title: String { didSet { applyTraits() } }
    var icon: UIImage? { didSet { iconView.image = icon; iconView.isHidden = icon == nil } }
    var iconTrailing = false { didSet { rebuild() } }

    init(_ title: String, style: Style = .primary, height: CGFloat = 52, fontSize: CGFloat = 15.5, icon: UIImage? = nil) {
        self.style = style
        self.title = title
        self.fontSize = fontSize
        self.icon = icon
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: height).isActive = true

        border.isUserInteractionEnabled = false
        addSubview(border)
        border.pinEdges(to: self)

        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16)
        ])
        iconView.contentMode = .scaleAspectFit
        iconView.image = icon
        iconView.isHidden = icon == nil
        titleLabel.textAlignment = .center
        rebuild()
        applyTraits()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func rebuild() {
        stack.removeAllArranged()
        if iconTrailing {
            stack.addArrangedSubview(titleLabel)
            stack.addArrangedSubview(iconView)
        } else {
            stack.addArrangedSubview(iconView)
            stack.addArrangedSubview(titleLabel)
        }
    }

    override var isEnabled: Bool { didSet { applyTraits() } }

    override func layoutSubviews() {
        super.layoutSubviews()
        border.radius = bounds.height / 2
        layer.cornerRadius = bounds.height / 2
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: bounds.height / 2).cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTraits()
    }

    private func applyTraits() {
        var fg: UIColor
        border.borderColor = nil
        border.fill = .clear
        DS.Shadow.none.apply(to: layer, traits: traitCollection)
        switch style {
        case .primary:
            if isEnabled {
                border.fill = DS.Color.brand
                fg = .white
                DS.Shadow.primary.apply(to: layer, traits: traitCollection)
            } else {
                border.fill = DS.Color.sunk
                fg = DS.Color.faint
            }
        case .secondary:
            border.fill = DS.Color.surface
            border.borderColor = DS.Color.borderStrong
            fg = DS.Color.fg
        case .outlineAccent:
            border.borderColor = DS.Color.accentBorder
            fg = DS.Color.accent
        case .ghost:
            fg = DS.Color.muted
        case .white:
            border.fill = .white
            fg = DS.Color.brand
            DS.Shadow.xs.apply(to: layer, traits: UITraitCollection(userInterfaceStyle: .light))
        case .danger:
            border.fill = DS.Color.surface
            border.borderColor = DS.Color.border
            fg = DS.Color.danger
        }
        titleLabel.setDS(title, font: DS.Font.text(fontSize, .semibold), color: fg, alignment: .center)
        iconView.tintColor = fg
    }
}

/// Круглая стеклянная кнопка 44×44 (назад, закрыть, календарь)
final class GlassIconButton: DSTapControl {
    let glass = GlassView(interactive: true)
    private let imageView = UIImageView()

    init(symbol: String, size: CGFloat = 44, pointSize: CGFloat = 17, weight: UIImage.SymbolWeight = .semibold) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        fixSize(width: size, height: size)
        glass.isCapsule = true
        glass.isUserInteractionEnabled = false
        addSubview(glass)
        glass.pinEdges(to: self)
        imageView.image = DS.symbol(symbol, size: pointSize, weight: weight)
        imageView.tintColor = DS.Color.fg
        imageView.contentMode = .center
        glass.contentView.addSubview(imageView)
        imageView.pinEdges(to: glass.contentView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSymbol(_ name: String, pointSize: CGFloat = 17) {
        imageView.image = DS.symbol(name, size: pointSize, weight: .semibold)
    }
}

/// Плашка 32×32 с иконкой (accentSoft / accent)
final class IconBadge: UIView {
    private let imageView = UIImageView()

    init(symbol: String, size: CGFloat = 32, pointSize: CGFloat = 15, tint: UIColor = DS.Color.accent, fill: UIColor = DS.Color.accentSoft, radius: CGFloat = DS.Radius.icon) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        fixSize(width: size, height: size)
        backgroundColor = fill
        layer.cornerRadius = radius
        imageView.image = DS.symbol(symbol, size: pointSize, weight: .medium)
        imageView.tintColor = tint
        imageView.contentMode = .center
        addSubview(imageView)
        imageView.pinEdges(to: self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Сегменты

/// Сегментированный переключатель макетов: подложка sunk, активный сегмент surface + accent + тень
final class DSSegmentedControl: UIControl {
    private(set) var items: [String]
    private var buttons: [DSTapControl] = []
    private var labels: [UILabel] = []
    private var pills: [CardView] = []
    private let stack = UIStackView()
    private let fontSize: CGFloat
    private let mono: Bool
    var selectedIndex: Int = 0 { didSet { refresh() } }
    var icons: [String?] = [] { didSet { rebuild() } }
    private let segmentHeight: CGFloat

    init(items: [String], segmentHeight: CGFloat = 28, fontSize: CGFloat = 12.5, mono: Bool = false, minSegmentWidth: CGFloat = 34, outerRadius: CGFloat = 10) {
        self.items = items
        self.fontSize = fontSize
        self.mono = mono
        self.segmentHeight = segmentHeight
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = DS.Color.sunk
        layer.cornerRadius = outerRadius
        stack.axis = .horizontal
        stack.spacing = 3
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 3, left: 3, bottom: 3, right: 3))
        self.minSegmentWidth = minSegmentWidth
        rebuild()
    }

    private var minSegmentWidth: CGFloat = 34

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func rebuild() {
        stack.removeAllArranged()
        buttons = []; labels = []; pills = []
        for (index, item) in items.enumerated() {
            let button = DSTapControl()
            button.pressScale = 1
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalToConstant: segmentHeight).isActive = true
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: minSegmentWidth).isActive = true
            let pill = CardView(radius: segmentHeight > 32 ? 9 : 7, shadow: .sm)
            pill.borderColor = nil
            pill.isUserInteractionEnabled = false
            button.addSubview(pill)
            pill.pinEdges(to: button)
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            let row = UIStackView.ds(.horizontal, spacing: 7, alignment: .center)
            row.isUserInteractionEnabled = false
            if index < icons.count, let icon = icons[index] {
                let iv = UIImageView(image: DS.symbol(icon, size: 13, weight: .semibold))
                iv.tag = 99
                row.addArrangedSubview(iv)
            }
            row.addArrangedSubview(label)
            button.addSubview(row)
            NSLayoutConstraint.activate([
                row.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                row.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                row.leadingAnchor.constraint(greaterThanOrEqualTo: button.leadingAnchor, constant: 8),
                row.trailingAnchor.constraint(lessThanOrEqualTo: button.trailingAnchor, constant: -8)
            ])
            label.text = item
            button.onTap = { [weak self] in
                guard let self = self, self.isEnabled, self.selectedIndex != index else { return }
                self.selectedIndex = index
                UISelectionFeedbackGenerator().selectionChanged()
                self.sendActions(for: .valueChanged)
            }
            stack.addArrangedSubview(button)
            buttons.append(button)
            labels.append(label)
            pills.append(pill)
        }
        refresh()
    }

    override var isEnabled: Bool { didSet { alpha = isEnabled ? 1 : 0.45 } }

    private func refresh() {
        for (index, label) in labels.enumerated() {
            let on = index == selectedIndex
            let color = on ? DS.Color.accent : DS.Color.soft
            let font = mono ? DS.Font.mono(fontSize, .bold) : DS.Font.text(fontSize, on ? .bold : .semibold)
            label.setDS(items[index], font: font, color: color, alignment: .center)
            pills[index].isHidden = !on
            (buttons[index].subviews.compactMap { $0 as? UIStackView }.first?.arrangedSubviews.first { $0.tag == 99 } as? UIImageView)?.tintColor = color
            buttons[index].accessibilityTraits = on ? [.button, .selected] : .button
            buttons[index].accessibilityLabel = items[index]
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refresh()
    }
}

// MARK: - Тост

enum DSToast {
    /// Тёмная плашка снизу над навигацией: «Ссылка eios скопирована · вставьте в браузер»
    static func show(title: String, detail: String? = nil, in host: UIView? = nil, bottom: CGFloat = 104) {
        guard let container = host ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return }
        let toast = UIView()
        toast.translatesAutoresizingMaskIntoConstraints = false
        toast.backgroundColor = UIColor(rgb: 0x0F172A)
        toast.layer.cornerRadius = 14
        toast.layer.shadowColor = UIColor(rgb: 0x0F172A).cgColor
        toast.layer.shadowOpacity = 0.3
        toast.layer.shadowRadius = 16
        toast.layer.shadowOffset = CGSize(width: 0, height: 12)
        let dot = UIView()
        dot.backgroundColor = DS.Color.green
        dot.layer.cornerRadius = 4
        dot.fixSize(width: 8, height: 8)
        let label = UILabel()
        label.numberOfLines = 2
        let text = NSMutableAttributedString(attributedString: .ds(title, font: DS.Font.text(13.5, .semibold), color: UIColor(rgb: 0xF1F5F9)))
        if let detail = detail {
            text.append(.ds(" · " + detail, font: DS.Font.text(13.5), color: UIColor(rgb: 0xF1F5F9, alpha: 0.7)))
        }
        label.attributedText = text
        let row = UIStackView.ds(.horizontal, spacing: 10, alignment: .center, views: [dot, label])
        toast.addSubview(row)
        row.pinEdges(to: toast, insets: UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14))
        container.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            toast.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            toast.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -bottom)
        ])
        toast.alpha = 0
        toast.transform = CGAffineTransform(translationX: 0, y: 12)
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.4, options: [], animations: {
            toast.alpha = 1
            toast.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.6, options: [], animations: {
                toast.alpha = 0
                toast.transform = CGAffineTransform(translationX: 0, y: 8)
            }) { _ in toast.removeFromSuperview() }
        }
    }
}

// MARK: - Строка списка в карточке (настройки, «О приложении»)

final class DSListRow: DSTapControl {
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    let valueLabel = UILabel()
    let accessoryContainer = UIStackView()
    private let separator = UIView()
    private let chevron = UIImageView(image: DS.symbol("chevron.right", size: 12, weight: .semibold))

    init(symbol: String?, title: String, subtitle: String? = nil, value: String? = nil, chevron: Bool = false, externalLink: Bool = false) {
        super.init(frame: .zero)
        pressScale = 1
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true

        titleLabel.setDS(title, font: DS.Font.text(14.5, .medium))
        titleLabel.numberOfLines = 0
        subtitleLabel.numberOfLines = 0
        if let subtitle = subtitle {
            subtitleLabel.setDS(subtitle, font: DS.Font.text(12), color: DS.Color.faint, lineHeight: 16)
        }
        subtitleLabel.isHidden = subtitle == nil
        let texts = UIStackView.ds(.vertical, spacing: 1, views: [titleLabel, subtitleLabel])
        texts.isUserInteractionEnabled = false

        accessoryContainer.axis = .horizontal
        accessoryContainer.spacing = 6
        accessoryContainer.alignment = .center
        if let value = value {
            valueLabel.setDS(value, font: DS.Font.mono(12), color: DS.Color.faint)
            accessoryContainer.addArrangedSubview(valueLabel)
        }
        if chevron || externalLink {
            self.chevron.image = DS.symbol(externalLink ? "arrow.up.right.square" : "chevron.right", size: externalLink ? 13 : 12, weight: .semibold)
            self.chevron.tintColor = DS.Color.faint
            self.chevron.contentMode = .center
            self.chevron.fixSize(width: 16, height: 16)
            accessoryContainer.addArrangedSubview(self.chevron)
        }

        var views: [UIView] = []
        if let symbol = symbol { views.append(IconBadge(symbol: symbol)) }
        views.append(texts)
        views.append(accessoryContainer)
        let row = UIStackView.ds(.horizontal, spacing: 12, alignment: .center, views: views)
        texts.setContentHuggingPriority(.defaultLow, for: .horizontal)
        texts.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        accessoryContainer.setContentHuggingPriority(.required, for: .horizontal)
        accessoryContainer.setContentCompressionResistancePriority(.required, for: .horizontal)
        addSubview(row)
        row.pinEdges(to: self, insets: UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14))

        separator.backgroundColor = DS.Color.border
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)
        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var showsSeparator: Bool {
        get { !separator.isHidden }
        set { separator.isHidden = !newValue }
    }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted && onTap != nil ? DS.Color.sunk : .clear }
    }

    func setAccessory(_ view: UIView) {
        accessoryContainer.removeAllArranged()
        accessoryContainer.addArrangedSubview(view)
    }

    func setValue(_ text: String) {
        valueLabel.setDS(text, font: DS.Font.mono(12), color: DS.Color.faint)
    }
}

/// Карточка-группа строк (разделитель — 1px border)
final class DSListGroup: UIView {
    let stack = UIStackView.ds(.vertical)
    private let clipped = ClippedCardView(radius: DS.Radius.card, shadow: .xs)

    init(rows: [UIView] = []) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(clipped)
        clipped.pinEdges(to: self)
        clipped.content.addSubview(stack)
        stack.pinEdges(to: clipped.content)
        rows.forEach { add($0) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func add(_ row: UIView) {
        if let listRow = row as? DSListRow { listRow.showsSeparator = !stack.arrangedSubviews.isEmpty }
        stack.addArrangedSubview(row)
    }
}

/// Заголовок секции: «РАСПИСАНИЕ» 10.5px faint
func dsSectionTitle(_ text: String, trailing: String? = nil) -> UIView {
    let wrap = UIView()
    wrap.translatesAutoresizingMaskIntoConstraints = false
    let title = UILabel.eyebrow(text, size: 10.5)
    wrap.addSubview(title)
    var constraints = [
        title.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 4),
        title.topAnchor.constraint(equalTo: wrap.topAnchor),
        title.bottomAnchor.constraint(equalTo: wrap.bottomAnchor)
    ]
    if let trailing = trailing {
        let value = UILabel.ds(trailing, font: DS.Font.mono(11), color: DS.Color.faint)
        wrap.addSubview(value)
        constraints += [
            value.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -4),
            value.firstBaselineAnchor.constraint(equalTo: title.firstBaselineAnchor)
        ]
    }
    NSLayoutConstraint.activate(constraints)
    return wrap
}

/// Вертикальный отступ для UIStackView
func dsSpacer(_ height: CGFloat) -> UIView {
    let v = UIView()
    v.translatesAutoresizingMaskIntoConstraints = false
    v.heightAnchor.constraint(equalToConstant: height).isActive = true
    return v
}
