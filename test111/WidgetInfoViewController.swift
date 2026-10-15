//
//  WidgetInfoViewController.swift
//  test111
//
//  Created by GPT Assistant
//

import UIKit

/// «Добавлены виджеты» (WidgetsInfo.dc.html): превью виджетов и как их добавить
class WidgetInfoViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stack = UIStackView.ds(.vertical)
    private var stackTop: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = DS.Color.bg
        let backdrop = BackdropView()
        view.addSubview(backdrop)
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.heightAnchor.constraint(equalToConstant: 360)
        ])

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)
        scrollView.pinEdges(to: view)
        scrollView.addSubview(stack)
        stackTop = stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 112)
        NSLayoutConstraint.activate([
            stackTop,
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: DS.Inset.side),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -DS.Inset.side),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -40)
        ])

        let eyebrow = EyebrowPill("Новое")
        let eyebrowWrap = UIView()
        eyebrowWrap.addSubview(eyebrow)
        NSLayoutConstraint.activate([
            eyebrow.topAnchor.constraint(equalTo: eyebrowWrap.topAnchor),
            eyebrow.bottomAnchor.constraint(equalTo: eyebrowWrap.bottomAnchor),
            eyebrow.leadingAnchor.constraint(equalTo: eyebrowWrap.leadingAnchor)
        ])
        stack.addArrangedSubview(eyebrowWrap)
        stack.setCustomSpacing(10, after: eyebrowWrap)
        let title = UILabel.display("Добавлены виджеты", size: 34)
        stack.addArrangedSubview(title)
        stack.setCustomSpacing(6, after: title)
        let text = UILabel.ds("Текущая и следующая пара на главном экране — без запуска приложения.", font: DS.Font.text(14.5), color: DS.Color.soft, lines: 0, lineHeight: 22)
        stack.addArrangedSubview(text)
        stack.setCustomSpacing(18, after: text)

        // Превью на «обоях»
        let wall = WallpaperView()
        let medium = WidgetPreviewView(kind: .medium, dark: false)
        let smallA = WidgetPreviewView(kind: .small, dark: false)
        let smallB = WidgetPreviewView(kind: .small, dark: true)
        let smallRow = UIStackView.ds(.horizontal, spacing: 24, alignment: .center, views: [smallA, smallB])
        let wallCol = UIStackView.ds(.vertical, spacing: 16, alignment: .center, views: [medium, smallRow])
        wall.addSubview(wallCol)
        wallCol.pinEdges(to: wall, insets: UIEdgeInsets(top: 22, left: 13, bottom: 22, right: 13))
        NSLayoutConstraint.activate([
            medium.widthAnchor.constraint(equalTo: wallCol.widthAnchor),
            medium.heightAnchor.constraint(equalTo: medium.widthAnchor, multiplier: 170.0 / 364.0),
            smallA.widthAnchor.constraint(equalTo: medium.heightAnchor),
            smallA.heightAnchor.constraint(equalTo: smallA.widthAnchor),
            smallB.widthAnchor.constraint(equalTo: smallA.widthAnchor),
            smallB.heightAnchor.constraint(equalTo: smallA.heightAnchor)
        ])
        stack.addArrangedSubview(wall)

        // Как добавить
        let caption = dsSectionTitle("Как добавить")
        stack.setCustomSpacing(22, after: wall)
        stack.addArrangedSubview(caption)
        stack.setCustomSpacing(8, after: caption)
        let steps = ["Удерживайте палец на пустом месте главного экрана", "Нажмите «Изменить» → «Добавить виджет»", "Найдите «Моя Академия» и выберите размер"]
        let group = DSListGroup()
        for (i, step) in steps.enumerated() {
            let number = UILabel.ds("\(i + 1)", font: DS.Font.mono(12, .bold), color: .white, alignment: .center)
            number.backgroundColor = DS.Color.brand
            number.layer.cornerRadius = 13
            number.clipsToBounds = true
            number.fixSize(width: 26, height: 26)
            let label = UILabel.ds(step, font: DS.Font.text(14), lines: 0, lineHeight: 19.6)
            let row = UIStackView.ds(.horizontal, spacing: 12, alignment: .center, views: [number, label])
            let wrap = UIView()
            wrap.addSubview(row)
            row.pinEdges(to: wrap, insets: UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14))
            if i > 0 {
                let line = UIView()
                line.backgroundColor = DS.Color.border
                line.translatesAutoresizingMaskIntoConstraints = false
                wrap.addSubview(line)
                NSLayoutConstraint.activate([
                    line.topAnchor.constraint(equalTo: wrap.topAnchor),
                    line.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
                    line.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
                    line.heightAnchor.constraint(equalToConstant: 1)
                ])
            }
            group.add(wrap)
        }
        stack.addArrangedSubview(group)

        let ok = DSButton("Понятно")
        ok.onTap = { [weak self] in self?.closeButtonTapped() }
        stack.setCustomSpacing(18, after: group)
        stack.addArrangedSubview(ok)

        // Назад / закрыть
        let close = GlassIconButton(symbol: "xmark", pointSize: 15)
        close.accessibilityLabel = "Закрыть"
        close.onTap = { [weak self] in self?.closeButtonTapped() }
        view.addSubview(close)
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            close.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DS.Inset.side)
        ])
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        stackTop.constant = max(view.safeAreaInsets.top, 20) + 58
    }

    @objc private func closeButtonTapped() {
        // Сохраняем флаг, что окно уже было показано
        UserDefaults.standard.set(true, forKey: "hasSeenWidgetInfo")

        // Закрываем окно с анимацией
        dismiss(animated: true)
    }
}

// MARK: - Обои для превью

private final class WallpaperView: UIView {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 24
        clipsToBounds = true
        gradient.colors = [UIColor(rgb: 0xDBEAFE).cgColor, UIColor(rgb: 0x93C5FD).cgColor]
        gradient.startPoint = CGPoint(x: 0.4, y: 0)
        gradient.endPoint = CGPoint(x: 0.6, y: 1)
        layer.insertSublayer(gradient, at: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}

// MARK: - Превью виджета (Widget.dc.html: small / medium, состояние «сейчас»)

final class WidgetPreviewView: UIView {
    enum Kind { case small, medium }

    private let rail = CAGradientLayer()
    private let kind: Kind

    init(kind: Kind, dark: Bool) {
        self.kind = kind
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 22
        let fg = dark ? UIColor(rgb: 0xF1F5F9) : UIColor(rgb: 0x0F172A)
        let soft = dark ? UIColor(rgb: 0xA3AEC2) : UIColor(rgb: 0x64748B)
        let accent = dark ? UIColor(rgb: 0x60A5FA) : DS.Color.brand
        let track = dark ? UIColor(rgb: 0x94A3B8, alpha: 0.22) : UIColor(rgb: 0xE2E8F0)
        backgroundColor = dark ? UIColor(rgb: 0x16203A) : .white
        layer.shadowColor = UIColor(rgb: 0x0F172A).cgColor
        layer.shadowOpacity = dark ? 0.3 : 0.14
        layer.shadowRadius = 15
        layer.shadowOffset = CGSize(width: 0, height: 10)

        rail.colors = dark ? [UIColor(rgb: 0x3B82F6).cgColor, UIColor(rgb: 0x38BDF8).cgColor] : [DS.Color.brand.cgColor, DS.Color.brandSky.cgColor]
        let clip = UIView()
        clip.layer.cornerRadius = 22
        clip.clipsToBounds = true
        addSubview(clip)
        clip.pinEdges(to: self)
        clip.layer.addSublayer(rail)

        let small = kind == .small
        func block(label: String, subject: String, meta: String, live: Bool, progress: CGFloat?) -> UIView {
            let node = UIView()
            node.translatesAutoresizingMaskIntoConstraints = false
            let size: CGFloat = live ? 13 : 11
            node.layer.cornerRadius = size / 2
            node.backgroundColor = live ? .white : (dark ? UIColor(rgb: 0x16203A) : .white)
            node.layer.borderWidth = live ? 3 : 2.5
            node.layer.borderColor = accent.cgColor
            if live {
                node.layer.shadowColor = accent.cgColor
                node.layer.shadowOpacity = 0.6
                node.layer.shadowRadius = 5
                node.layer.shadowOffset = .zero
            }
            var views: [UIView] = []
            if small {
                views.append(UILabel.ds(label.uppercased(), font: DS.Font.text(10, .bold), color: live ? accent : soft, kern: 0.8))
                views.append(UILabel.ds(subject, font: DS.Font.display(14, .heavy), color: fg, lines: live ? 2 : 1, lineHeight: 17))
            } else {
                let titleRow = UIStackView.ds(.horizontal, spacing: 10, alignment: .firstBaseline, views: [
                    UILabel.ds(subject, font: DS.Font.display(15.5, .heavy), color: fg),
                    UILabel.ds(label, font: DS.Font.text(11, .semibold), color: live ? accent : soft)
                ])
                titleRow.arrangedSubviews[1].setContentHuggingPriority(.required, for: .horizontal)
                titleRow.arrangedSubviews[1].setContentCompressionResistancePriority(.required, for: .horizontal)
                views.append(titleRow)
            }
            views.append(UILabel.ds(meta, font: small ? DS.Font.mono(10.5) : DS.Font.text(12), color: soft))
            if let progress = progress {
                let bar = UIView()
                bar.backgroundColor = track
                bar.layer.cornerRadius = 2
                bar.clipsToBounds = true
                bar.fixSize(height: 4)
                let fill = UIView()
                fill.backgroundColor = accent
                fill.translatesAutoresizingMaskIntoConstraints = false
                bar.addSubview(fill)
                NSLayoutConstraint.activate([
                    fill.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
                    fill.topAnchor.constraint(equalTo: bar.topAnchor),
                    fill.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
                    fill.widthAnchor.constraint(equalTo: bar.widthAnchor, multiplier: progress)
                ])
                views.append(bar)
            }
            let col = UIStackView.ds(.vertical, spacing: 3, views: views)
            let wrap = UIView()
            wrap.translatesAutoresizingMaskIntoConstraints = false
            wrap.addSubview(col)
            col.pinEdges(to: wrap)
            wrap.addSubview(node)
            let railX: CGFloat = small ? -14.5 : -17.5
            NSLayoutConstraint.activate([
                node.widthAnchor.constraint(equalToConstant: size),
                node.heightAnchor.constraint(equalToConstant: size),
                node.centerXAnchor.constraint(equalTo: wrap.leadingAnchor, constant: railX),
                node.centerYAnchor.constraint(equalTo: wrap.topAnchor, constant: small ? 7 : 10)
            ])
            return wrap
        }

        let first = block(label: small ? "Сейчас идёт" : "Сейчас идёт", subject: "Этические вопросы", meta: small ? "1-102 · 13:10–14:40" : "Чавыкина У.Г. · 13:10–14:40 · 1-102", live: true, progress: 0.36)
        let second = block(label: small ? "Следующая" : "Следующая пара", subject: small ? "Вычисл. системы" : "Вычислительные системы и сети", meta: small ? "1-208 · 14:50" : "Капустин С.А. · 14:50–16:20 · 1-208", live: false, progress: nil)
        let col = UIStackView.ds(.vertical, spacing: 0, views: [first, UIView(), second])
        col.distribution = .equalSpacing
        clip.addSubview(col)
        col.pinEdges(to: clip, insets: small ? UIEdgeInsets(top: 13, left: 31, bottom: 12, right: 12) : UIEdgeInsets(top: 14, left: 36, bottom: 14, right: 16))
        isAccessibilityElement = true
        accessibilityLabel = "Пример виджета «Моя Академия»"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let x: CGFloat = kind == .small ? 15 : 17
        rail.frame = CGRect(x: x, y: 0, width: 3, height: bounds.height)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 22).cgPath
    }
}
