//
//  SelectionScreenView.swift
//  Экран «Чьё расписание открыть?» (Select.dc.html): поиск, Студент/Преподаватель,
//  чипы фильтров и список групп или преподавателей. Только отображение.
//

import UIKit

final class SelectionScreenView: UIView, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {

    struct Row {
        let id: String
        let title: String
        let subtitle: String
        let badge: String
        let isSelected: Bool
    }

    struct Section {
        let title: String
        let count: String?
        let rows: [Row]
    }

    struct ChipGroup {
        enum Style { case filter, course }
        let title: String
        let items: [String]
        let selected: Int?
        let style: Style
    }

    var onBack: (() -> Void)?
    var onQuery: ((String) -> Void)?
    var onModeChange: ((Bool) -> Void)?
    var onChip: ((Int, Int) -> Void)?
    var onSelectRow: ((Row) -> Void)?

    var canGoBack = true { didSet { backButton.isHidden = !canGoBack } }

    private let backdrop = BackdropView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let headerContainer = UIView()
    private let headerStack = UIStackView.ds(.vertical)
    private let chipsStack = UIStackView.ds(.vertical)
    private let searchField = UITextField()
    private let searchBox = CardView(radius: 16, shadow: .xs)
    private let clearButton = DSTapControl()
    private let modeControl = DSSegmentedControl(items: ["Студент", "Преподаватель"], segmentHeight: 38, fontSize: 14, minSegmentWidth: 60, outerRadius: 12)
    private let backButton = GlassIconButton(symbol: "chevron.left", pointSize: 17)
    private var backTop: NSLayoutConstraint!
    private var sections: [Section] = []
    private var emptyView: UIView?
    private let footerContainer = UIView()

    init(isTeacher: Bool, placeholder: String) {
        super.init(frame: .zero)
        backgroundColor = DS.Color.bg

        addSubview(backdrop)
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: trailingAnchor),
            backdrop.heightAnchor.constraint(equalToConstant: 320)
        ])
        backdrop.showsGrid = false
        backdrop.showsSky = false

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.keyboardDismissMode = .onDrag
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 60
        tableView.sectionFooterHeight = 0
        if #available(iOS 15.0, *) { tableView.sectionHeaderTopPadding = 0 }
        tableView.register(SelectionCell.self, forCellReuseIdentifier: SelectionCell.reuseId)
        addSubview(tableView)
        tableView.pinEdges(to: self)

        // Шапка списка
        let eyebrow = EyebrowPill("Академия ИМСИТ")
        let eyebrowWrap = UIView()
        eyebrowWrap.addSubview(eyebrow)
        NSLayoutConstraint.activate([
            eyebrow.topAnchor.constraint(equalTo: eyebrowWrap.topAnchor),
            eyebrow.bottomAnchor.constraint(equalTo: eyebrowWrap.bottomAnchor),
            eyebrow.leadingAnchor.constraint(equalTo: eyebrowWrap.leadingAnchor)
        ])
        let title = UILabel.display("Чьё расписание\nоткрыть?", size: 34)
        title.setDS("Чьё расписание\nоткрыть?", font: DS.Font.display(34, .heavy), kern: -0.85, lineHeight: 36)

        // Поиск
        let magnifier = UIImageView(image: DS.symbol("magnifyingglass", size: 16, weight: .semibold))
        magnifier.tintColor = DS.Color.soft
        magnifier.setContentHuggingPriority(.required, for: .horizontal)
        searchField.font = DS.Font.text(15.5)
        searchField.textColor = DS.Color.fg
        searchField.tintColor = DS.Color.accent
        searchField.attributedPlaceholder = .ds(placeholder, font: DS.Font.text(15.5), color: DS.Color.soft)
        searchField.returnKeyType = .search
        searchField.autocorrectionType = .no
        searchField.clearButtonMode = .never
        searchField.delegate = self
        searchField.accessibilityLabel = placeholder
        searchField.addTarget(self, action: #selector(queryChanged), for: .editingChanged)
        let clearIcon = UIImageView(image: DS.symbol("xmark", size: 10, weight: .bold))
        clearIcon.tintColor = DS.Color.soft
        clearIcon.contentMode = .center
        clearButton.backgroundColor = DS.Color.sunk
        clearButton.layer.cornerRadius = 13
        clearButton.fixSize(width: 26, height: 26)
        clearButton.addSubview(clearIcon)
        clearIcon.pinEdges(to: clearButton)
        clearButton.isHidden = true
        clearButton.accessibilityLabel = "Очистить"
        clearButton.onTap = { [weak self] in
            self?.searchField.text = ""
            self?.queryChanged()
        }
        let searchRow = UIStackView.ds(.horizontal, spacing: 10, alignment: .center, views: [magnifier, searchField, clearButton])
        searchBox.borderColor = DS.Color.borderStrong
        searchBox.borderWidth = 1.5
        searchBox.addSubview(searchRow)
        searchRow.pinEdges(to: searchBox, insets: UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14))
        searchBox.fixSize(height: 52)

        modeControl.icons = ["graduationcap", "person"]
        modeControl.selectedIndex = isTeacher ? 1 : 0
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)

        headerStack.addArrangedSubview(eyebrowWrap)
        headerStack.addArrangedSubview(title)
        headerStack.addArrangedSubview(searchBox)
        headerStack.addArrangedSubview(modeControl)
        headerStack.addArrangedSubview(chipsStack)
        headerStack.setCustomSpacing(10, after: eyebrowWrap)
        headerStack.setCustomSpacing(18, after: title)
        headerStack.setCustomSpacing(12, after: searchBox)
        headerContainer.addSubview(headerStack)
        headerStack.pinEdges(to: headerContainer, insets: UIEdgeInsets(top: 0, left: DS.Inset.side, bottom: 0, right: DS.Inset.side))
        tableView.tableHeaderView = headerContainer
        tableView.tableFooterView = footerContainer

        // Назад
        backButton.accessibilityLabel = "Назад"
        backButton.onTap = { [weak self] in
            self?.endEditing(true)
            self?.onBack?()
        }
        addSubview(backButton)
        backTop = backButton.topAnchor.constraint(equalTo: topAnchor, constant: 58)
        NSLayoutConstraint.activate([
            backTop,
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DS.Inset.side)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        let top = max(safeAreaInsets.top, 20)
        backTop.constant = top + 4
        tableView.contentInset = UIEdgeInsets(top: top + 4 + 44 + 10, left: 0, bottom: max(safeAreaInsets.bottom, 16) + 32, right: 0)
        tableView.scrollIndicatorInsets = tableView.contentInset
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        sizeHeaderToFit()
    }

    private func sizeHeaderToFit() {
        let width = tableView.bounds.width
        guard width > 0 else { return }
        let size = headerContainer.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        if abs(headerContainer.frame.height - size.height) > 0.5 || headerContainer.frame.width != width {
            headerContainer.frame = CGRect(x: 0, y: 0, width: width, height: size.height)
            tableView.tableHeaderView = headerContainer
        }
        if let content = footerContainer.subviews.first {
            let fs = content.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
            if abs(footerContainer.frame.height - fs.height) > 0.5 {
                footerContainer.frame = CGRect(x: 0, y: 0, width: width, height: fs.height)
                tableView.tableFooterView = footerContainer
            }
        }
    }

    // MARK: - Данные

    var query: String { searchField.text ?? "" }

    func setMode(isTeacher: Bool) {
        modeControl.selectedIndex = isTeacher ? 1 : 0
    }

    func setChipGroups(_ groups: [ChipGroup]) {
        chipsStack.removeAllArranged()
        for (groupIndex, group) in groups.enumerated() {
            let caption = UILabel.eyebrow(group.title, size: 10)
            let captionWrap = UIView()
            captionWrap.addSubview(caption)
            caption.pinEdges(to: captionWrap, insets: UIEdgeInsets(top: groupIndex == 0 ? 16 : 14, left: 4, bottom: 8, right: 4))
            chipsStack.addArrangedSubview(captionWrap)

            let scroll = UIScrollView()
            scroll.translatesAutoresizingMaskIntoConstraints = false
            scroll.showsHorizontalScrollIndicator = false
            scroll.clipsToBounds = false
            let row = UIStackView.ds(.horizontal, spacing: 6, alignment: .center)
            scroll.addSubview(row)
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
                row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
                row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
                row.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
                scroll.heightAnchor.constraint(equalToConstant: group.style == .course ? 34 : 32)
            ])
            for (itemIndex, item) in group.items.enumerated() {
                let chip = ChipButton(title: item, selected: group.selected == itemIndex, style: group.style)
                chip.onTap = { [weak self] in
                    UISelectionFeedbackGenerator().selectionChanged()
                    self?.onChip?(groupIndex, itemIndex)
                }
                row.addArrangedSubview(chip)
            }
            chipsStack.addArrangedSubview(scroll)
        }
        chipsStack.isHidden = groups.isEmpty || !query.isEmpty
        setNeedsLayout()
    }

    func setSections(_ sections: [Section], emptyTitle: String?, emptyText: String?) {
        self.sections = sections
        tableView.reloadData()
        footerContainer.subviews.forEach { $0.removeFromSuperview() }
        footerContainer.frame.size.height = 0
        if sections.isEmpty, let emptyTitle = emptyTitle {
            footerContainer.addSubview(emptyCard(title: emptyTitle, text: emptyText))
        }
        if let ad = adView {
            let wrap = adWrap(ad)
            if let card = footerContainer.subviews.first {
                let stack = UIStackView.ds(.vertical, spacing: 0, views: [])
                card.removeFromSuperview()
                stack.addArrangedSubview(card)
                stack.addArrangedSubview(wrap)
                footerContainer.addSubview(stack)
            } else {
                footerContainer.addSubview(wrap)
            }
        }
        if let content = footerContainer.subviews.first {
            content.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                content.topAnchor.constraint(equalTo: footerContainer.topAnchor),
                content.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor),
                content.widthAnchor.constraint(equalTo: footerContainer.widthAnchor)
            ])
        }
        footerContainer.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 1)
        tableView.tableFooterView = footerContainer
        setNeedsLayout()
    }

    /// Рекламный баннер (если включён) — под списком
    var adView: UIView?

    private func adWrap(_ ad: UIView) -> UIView {
        let wrap = UIView()
        ad.removeFromSuperview()
        wrap.addSubview(ad)
        ad.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ad.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 20),
            ad.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
            ad.centerXAnchor.constraint(equalTo: wrap.centerXAnchor)
        ])
        return wrap
    }

    private func emptyCard(title: String, text: String?) -> UIView {
        let wrap = UIView()
        let card = CardView(radius: DS.Radius.card, shadow: .none)
        card.fill = .clear
        card.dashed = true
        card.borderColor = DS.Color.borderStrong
        let image = UIImageView(image: UIImage(named: "IlloSearch"))
        image.contentMode = .scaleAspectFit
        image.fixSize(width: 140, height: 140)
        var views: [UIView] = [image, UILabel.display(title, size: 16, weight: .bold, alignment: .center)]
        if let text = text {
            views.append(UILabel.ds(text, font: DS.Font.text(13), color: DS.Color.soft, lines: 0, alignment: .center))
        }
        let col = UIStackView.ds(.vertical, spacing: 4, alignment: .center, views: views)
        card.addSubview(col)
        col.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 16, bottom: 26, right: 16))
        wrap.addSubview(card)
        card.pinEdges(to: wrap, insets: UIEdgeInsets(top: 22, left: DS.Inset.side, bottom: 0, right: DS.Inset.side))
        return wrap
    }

    // MARK: - Действия

    @objc private func queryChanged() {
        let q = query.trimmingCharacters(in: .whitespaces)
        clearButton.isHidden = q.isEmpty
        searchBox.borderColor = q.isEmpty ? DS.Color.borderStrong : DS.Color.accent
        chipsStack.isHidden = !q.isEmpty || chipsStack.arrangedSubviews.isEmpty
        onQuery?(q)
        setNeedsLayout()
    }

    @objc private func modeChanged() {
        onModeChange?(modeControl.selectedIndex == 1)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    // MARK: - Таблица

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].rows.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SelectionCell.reuseId, for: indexPath) as! SelectionCell
        let rows = sections[indexPath.section].rows
        cell.configure(rows[indexPath.row], isFirst: indexPath.row == 0, isLast: indexPath.row == rows.count - 1)
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        let title = dsSectionTitle(sections[section].title, trailing: sections[section].count)
        view.addSubview(title)
        title.pinEdges(to: view, insets: UIEdgeInsets(top: 22, left: DS.Inset.side, bottom: 8, right: DS.Inset.side))
        return view
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 44 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        endEditing(true)
        UISelectionFeedbackGenerator().selectionChanged()
        onSelectRow?(sections[indexPath.section].rows[indexPath.row])
    }
}

// MARK: - Ячейка

private final class SelectionCell: UITableViewCell {
    static let reuseId = "SelectionCell"

    private let card = UIView()
    private let outline = CAShapeLayer()
    private let separator = UIView()
    private let badge = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let check = UIImageView()
    private let chevron = UIImageView(image: DS.symbol("chevron.right", size: 12, weight: .semibold))
    private var isFirst = false
    private var isLast = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = DS.Color.surface
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DS.Inset.side),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DS.Inset.side)
        ])
        outline.fillColor = UIColor.clear.cgColor
        outline.lineWidth = 1
        card.layer.addSublayer(outline)

        separator.backgroundColor = DS.Color.border
        separator.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(separator)

        badge.textAlignment = .center
        badge.layer.cornerRadius = 19
        badge.clipsToBounds = true
        badge.fixSize(width: 38, height: 38)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        let texts = UIStackView.ds(.vertical, spacing: 1, views: [titleLabel, subtitleLabel])
        check.image = DS.symbol("checkmark", size: 11, weight: .heavy)
        check.tintColor = .white
        check.backgroundColor = DS.Color.brand
        check.contentMode = .center
        check.layer.cornerRadius = 12
        check.fixSize(width: 24, height: 24)
        chevron.tintColor = DS.Color.faint
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView.ds(.horizontal, spacing: 12, alignment: .center, views: [badge, texts, check, chevron])
        card.addSubview(row)
        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: card.topAnchor),
            separator.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ row: SelectionScreenView.Row, isFirst: Bool, isLast: Bool) {
        self.isFirst = isFirst
        self.isLast = isLast
        separator.isHidden = isFirst
        badge.setDS(row.badge, font: DS.Font.display(12.5, .heavy), color: row.isSelected ? .white : DS.Color.accent, alignment: .center)
        badge.backgroundColor = row.isSelected ? DS.Color.brand : DS.Color.accentSoft
        titleLabel.setDS(row.title, font: DS.Font.display(15, .bold), kern: -0.15)
        subtitleLabel.setDS(row.subtitle, font: DS.Font.text(12.5), color: DS.Color.soft)
        subtitleLabel.isHidden = row.subtitle.isEmpty
        check.isHidden = !row.isSelected
        chevron.isHidden = row.isSelected
        card.backgroundColor = row.isSelected ? DS.Color.accentSoft.resolvedOver(DS.Color.surface) : DS.Color.surface
        accessibilityLabel = row.title + (row.subtitle.isEmpty ? "" : ", " + row.subtitle)
        accessibilityTraits = row.isSelected ? [.button, .selected] : .button
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let r: CGFloat = DS.Radius.card
        var corners: CACornerMask = []
        if isFirst { corners.formUnion([.layerMinXMinYCorner, .layerMaxXMinYCorner]) }
        if isLast { corners.formUnion([.layerMinXMaxYCorner, .layerMaxXMaxYCorner]) }
        card.layer.cornerRadius = corners.isEmpty ? 0 : r
        card.layer.maskedCorners = corners
        card.clipsToBounds = true

        // Обводка: боковые стороны всегда, верх — у первой строки, низ — у последней
        let b = card.bounds.insetBy(dx: 0.5, dy: 0)
        let path = UIBezierPath()
        let top = isFirst ? b.minY + 0.5 : b.minY
        let bottom = isLast ? b.maxY - 0.5 : b.maxY
        let rt = isFirst ? r - 0.5 : 0
        let rb = isLast ? r - 0.5 : 0
        path.move(to: CGPoint(x: b.minX, y: bottom - rb))
        path.addLine(to: CGPoint(x: b.minX, y: top + rt))
        if isFirst {
            path.addArc(withCenter: CGPoint(x: b.minX + rt, y: top + rt), radius: rt, startAngle: .pi, endAngle: 1.5 * .pi, clockwise: true)
            path.addLine(to: CGPoint(x: b.maxX - rt, y: top))
            path.addArc(withCenter: CGPoint(x: b.maxX - rt, y: top + rt), radius: rt, startAngle: 1.5 * .pi, endAngle: 0, clockwise: true)
        } else {
            path.move(to: CGPoint(x: b.maxX, y: top))
        }
        path.addLine(to: CGPoint(x: b.maxX, y: bottom - rb))
        if isLast {
            path.addArc(withCenter: CGPoint(x: b.maxX - rb, y: bottom - rb), radius: rb, startAngle: 0, endAngle: 0.5 * .pi, clockwise: true)
            path.addLine(to: CGPoint(x: b.minX + rb, y: bottom))
            path.addArc(withCenter: CGPoint(x: b.minX + rb, y: bottom - rb), radius: rb, startAngle: 0.5 * .pi, endAngle: .pi, clockwise: true)
        }
        outline.frame = card.bounds
        outline.path = path.cgPath
        outline.strokeColor = DS.Color.border.resolvedColor(with: traitCollection).cgColor
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        card.alpha = highlighted ? 0.7 : 1
    }
}

private extension UIColor {
    /// Полупрозрачный цвет поверх подложки — чтобы выделенная строка не просвечивала фон
    func resolvedOver(_ base: UIColor) -> UIColor {
        return UIColor { traits in
            let top = self.resolvedColor(with: traits)
            let bottom = base.resolvedColor(with: traits)
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            top.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            bottom.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            return UIColor(red: r1 * a1 + r2 * (1 - a1), green: g1 * a1 + g2 * (1 - a1), blue: b1 * a1 + b2 * (1 - a1), alpha: 1)
        }
    }
}

// MARK: - Чип фильтра

private final class ChipButton: DSTapControl {
    init(title: String, selected: Bool, style: SelectionScreenView.ChipGroup.Style) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let card = CardView(radius: style == .course ? 17 : 10, shadow: .none)
        card.isUserInteractionEnabled = false
        addSubview(card)
        card.pinEdges(to: self)
        let fg: UIColor
        switch (style, selected) {
        case (.course, true):
            card.fill = DS.Color.brand
            card.borderColor = nil
            DS.Shadow.primary.apply(to: card.layer, traits: traitCollection)
            fg = .white
        case (.course, false):
            card.fill = DS.Color.surface
            card.borderColor = DS.Color.borderStrong
            fg = DS.Color.muted
        case (.filter, true):
            card.fill = DS.Color.accentSoft
            card.borderColor = DS.Color.accentBorder
            fg = DS.Color.accent
        case (.filter, false):
            card.fill = DS.Color.surface
            card.borderColor = DS.Color.border
            fg = DS.Color.muted
        }
        let label = UILabel.ds(title, font: DS.Font.text(style == .course ? 13 : 12.5, .semibold), color: fg)
        addSubview(label)
        label.pinEdges(to: self, insets: UIEdgeInsets(top: 0, left: style == .course ? 14 : 12, bottom: 0, right: style == .course ? 14 : 12))
        heightAnchor.constraint(equalToConstant: style == .course ? 34 : 32).isActive = true
        accessibilityLabel = title
        accessibilityTraits = selected ? [.button, .selected] : .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
