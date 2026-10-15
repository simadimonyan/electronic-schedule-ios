//
//  FloatingNavBar.swift
//  Плавающая нижняя навигация (Chrome.dc.html): стеклянная капсула с вкладками
//  «Сегодня / Неделя / Настройки» и круглая кнопка поиска группы или преподавателя.
//

import UIKit

final class FloatingNavBar: UIView {

    enum Item: Int, CaseIterable {
        case today, week, settings

        var title: String {
            switch self {
            case .today: return "Сегодня"
            case .week: return "Неделя"
            case .settings: return "Настройки"
            }
        }

        var symbol: String {
            switch self {
            case .today: return "calendar"
            case .week: return "tablecells"
            case .settings: return "slider.horizontal.3"
            }
        }
    }

    var onSelect: ((Item) -> Void)?
    var onSearch: (() -> Void)?

    /// nil — ни одна вкладка не выбрана
    var selected: Item? { didSet { refresh(animated: true) } }

    /// Кнопка поиска (выбор группы); скрывается настройкой «Убрать выбор группы»
    var isSearchHidden = false { didSet { searchButton.isHidden = isSearchHidden } }

    private let bar = GlassView(interactive: true)
    private let searchButton = GlassIconButton(symbol: "magnifyingglass", size: 62, pointSize: 19, weight: .semibold)
    private var tabs: [TabButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        bar.isCapsule = true
        searchButton.accessibilityLabel = "Найти группу или преподавателя"
        searchButton.onTap = { [weak self] in self?.onSearch?() }

        let tabsStack = UIStackView.ds(.horizontal, spacing: 2)
        tabsStack.distribution = .fillEqually
        bar.contentView.addSubview(tabsStack)
        tabsStack.pinEdges(to: bar.contentView, insets: UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5))
        for item in Item.allCases {
            let tab = TabButton(item: item)
            tab.onTap = { [weak self] in
                UISelectionFeedbackGenerator().selectionChanged()
                self?.onSelect?(item)
            }
            tabs.append(tab)
            tabsStack.addArrangedSubview(tab)
        }

        let row = UIStackView.ds(.horizontal, spacing: 8, alignment: .center, views: [bar, searchButton])
        addSubview(row)
        row.pinEdges(to: self)
        bar.heightAnchor.constraint(equalToConstant: 62).isActive = true
        refresh(animated: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func refresh(animated: Bool) {
        let apply = {
            for tab in self.tabs { tab.setActive(tab.item == self.selected) }
        }
        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: apply)
        } else {
            apply()
        }
    }

    private final class TabButton: DSTapControl {
        let item: Item
        private let pill = UIView()
        private let icon = UIImageView()
        private let label = UILabel()

        init(item: Item) {
            self.item = item
            super.init(frame: .zero)
            pressScale = 0.94
            pill.backgroundColor = DS.Color.accentSoft
            pill.layer.cornerRadius = 26
            pill.isUserInteractionEnabled = false
            addSubview(pill)
            pill.pinEdges(to: self)
            icon.contentMode = .center
            let col = UIStackView.ds(.vertical, spacing: 2, alignment: .center, views: [icon, label])
            col.isUserInteractionEnabled = false
            addSubview(col)
            NSLayoutConstraint.activate([
                col.centerXAnchor.constraint(equalTo: centerXAnchor),
                col.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
            accessibilityLabel = item.title
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func setActive(_ active: Bool) {
            pill.alpha = active ? 1 : 0
            let color = active ? DS.Color.accent : DS.Color.fg
            icon.image = DS.symbol(item.symbol, size: 18, weight: active ? .semibold : .regular)
            icon.tintColor = color
            label.setDS(item.title, font: DS.Font.text(10.5, active ? .bold : .semibold), color: color, alignment: .center)
            accessibilityTraits = active ? [.button, .selected] : .button
        }
    }
}
