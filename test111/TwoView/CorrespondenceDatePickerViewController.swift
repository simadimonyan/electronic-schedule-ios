//
//  CorrespondenceDatePickerViewController.swift
//  test111
//
//  Месячный календарь: только даты с занятиями можно выбрать; точка — есть пары.
//

import UIKit

private final class CorrespondenceCalendarDayCell: UICollectionViewCell {
    static let reuseId = "day"

    private let circle = UIView()
    private let numberLabel = UILabel()
    private let dotView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        circle.translatesAutoresizingMaskIntoConstraints = false
        circle.layer.cornerRadius = 20
        contentView.addSubview(circle)
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        numberLabel.textAlignment = .center
        dotView.translatesAutoresizingMaskIntoConstraints = false
        dotView.layer.cornerRadius = 2
        circle.addSubview(numberLabel)
        circle.addSubview(dotView)
        NSLayoutConstraint.activate([
            circle.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            circle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            circle.widthAnchor.constraint(equalToConstant: 40),
            circle.heightAnchor.constraint(equalToConstant: 40),
            numberLabel.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            numberLabel.centerYAnchor.constraint(equalTo: circle.centerYAnchor, constant: -2),
            dotView.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            dotView.topAnchor.constraint(equalTo: numberLabel.bottomAnchor, constant: 1),
            dotView.widthAnchor.constraint(equalToConstant: 4),
            dotView.heightAnchor.constraint(equalToConstant: 4)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(day: Int, isCurrentMonth: Bool, isSunday: Bool, hasLessons: Bool, isSelected: Bool, isSelectable: Bool, isToday: Bool) {
        circle.isHidden = day <= 0
        guard day > 0 else { return }
        let fg: UIColor
        circle.layer.borderWidth = 0
        if isSelected {
            circle.backgroundColor = DS.Color.brand
            fg = .white
        } else if isToday {
            circle.backgroundColor = hasLessons ? DS.Color.accentSoft : .clear
            circle.layer.borderWidth = 1.5
            circle.layer.borderColor = DS.Color.accent.resolvedColor(with: traitCollection).cgColor
            fg = DS.Color.accent
        } else if hasLessons {
            circle.backgroundColor = DS.Color.accentSoft
            fg = DS.Color.fg
        } else {
            circle.backgroundColor = .clear
            fg = DS.Color.faint
        }
        numberLabel.setDS("\(day)", font: DS.Font.text(14.5, hasLessons ? .bold : .medium), color: fg, alignment: .center)
        dotView.backgroundColor = isSelected ? .white : (hasLessons ? DS.Color.accent : .clear)
        contentView.alpha = isSelectable || isCurrentMonth ? 1 : 0.45
        accessibilityLabel = "\(day)" + (hasLessons ? ", день сессии" : "")
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}

final class CorrespondenceDatePickerViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    var isoDates: [String] = []
    var selectedISO: String?
    var onPick: ((String) -> Void)?

    private var displayedMonth: Date = Date()
    private var availableMonthAnchors: [Date] = []
    private var displayedMonthIndex: Int = 0

    private static let isoFmt: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Календарь сетки: понедельник — первый столбец (как на макете).
    private var gridCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "en_US_POSIX")
        c.firstWeekday = 2
        return c
    }()

    private var dayItems: [(date: Date?, day: Int, inMonth: Bool)] = []

    private let monthTitleLabel = UILabel()
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private var weekdayRow = UIStackView()
    private var collectionView: UICollectionView!

    /// Нижний лист в стиле макета Session (variant calendar)
    func presentAsSheet(from presenter: UIViewController) {
        modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *), let sheet = sheetPresentationController {
            if #available(iOS 16.0, *) {
                sheet.detents = [.custom(resolver: { _ in 470 }), .large()]
            } else {
                sheet.detents = [.medium(), .large()]
            }
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = DS.Radius.sheet
        }
        presenter.present(self, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.Color.bg

        buildAvailableMonths()
        if let s = selectedISO, let d = Self.isoFmt.date(from: s) {
            setDisplayedMonth(containing: d)
        } else if let f = isoDates.sorted().first, let d = Self.isoFmt.date(from: f) {
            setDisplayedMonth(containing: d)
        } else {
            displayedMonth = Date()
        }

        monthTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        for (button, symbol, label) in [(prevButton, "chevron.left", "Предыдущий месяц"), (nextButton, "chevron.right", "Следующий месяц")] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setImage(DS.symbol(symbol, size: 14, weight: .bold), for: .normal)
            button.tintColor = DS.Color.fg
            button.backgroundColor = DS.Color.sunk
            button.layer.cornerRadius = 18
            button.accessibilityLabel = label
            button.widthAnchor.constraint(equalToConstant: 36).isActive = true
            button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        }
        prevButton.addTarget(self, action: #selector(prevMonth), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextMonth), for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [monthTitleLabel, prevButton, nextButton])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 8
        header.translatesAutoresizingMaskIntoConstraints = false
        monthTitleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        weekdayRow = UIStackView()
        weekdayRow.axis = .horizontal
        weekdayRow.distribution = .fillEqually
        weekdayRow.translatesAutoresizingMaskIntoConstraints = false
        for t in ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"] {
            let lab = UILabel()
            lab.setDS(t, font: DS.Font.text(11, .bold), color: DS.Color.faint, kern: 0.55, alignment: .center)
            weekdayRow.addArrangedSubview(lab)
        }

        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isScrollEnabled = false
        collectionView.register(CorrespondenceCalendarDayCell.self, forCellWithReuseIdentifier: CorrespondenceCalendarDayCell.reuseId)

        // Легенда: день сессии / сегодня
        let sessionDot = UIView()
        sessionDot.backgroundColor = DS.Color.accent
        sessionDot.layer.cornerRadius = 4
        sessionDot.fixSize(width: 8, height: 8)
        let todayDot = UIView()
        todayDot.layer.cornerRadius = 4
        todayDot.layer.borderWidth = 1.5
        todayDot.layer.borderColor = DS.Color.accent.resolvedColor(with: traitCollection).cgColor
        todayDot.fixSize(width: 8, height: 8)
        let legend = UIStackView.ds(.horizontal, spacing: 14, alignment: .center, views: [
            UIStackView.ds(.horizontal, spacing: 6, alignment: .center, views: [sessionDot, UILabel.ds("День сессии", font: DS.Font.text(12), color: DS.Color.soft)]),
            UIStackView.ds(.horizontal, spacing: 6, alignment: .center, views: [todayDot, UILabel.ds("Сегодня", font: DS.Font.text(12), color: DS.Color.soft)]),
            UIView()
        ])

        view.addSubview(header)
        view.addSubview(weekdayRow)
        view.addSubview(collectionView)
        view.addSubview(legend)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 26),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),

            weekdayRow.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 14),
            weekdayRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            weekdayRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),

            collectionView.topAnchor.constraint(equalTo: weekdayRow.bottomAnchor, constant: 6),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            collectionView.heightAnchor.constraint(equalToConstant: 44 * 6),

            legend.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 8),
            legend.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            legend.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        rebuildMonthGrid()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func prevMonth() {
        guard displayedMonthIndex > 0 else { return }
        displayedMonthIndex -= 1
        displayedMonth = availableMonthAnchors[displayedMonthIndex]
        rebuildMonthGrid()
    }

    @objc private func nextMonth() {
        guard displayedMonthIndex + 1 < availableMonthAnchors.count else { return }
        displayedMonthIndex += 1
        displayedMonth = availableMonthAnchors[displayedMonthIndex]
        rebuildMonthGrid()
    }

    private func rebuildMonthGrid() {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "LLLL yyyy"
        monthTitleLabel.setDS(fmt.string(from: displayedMonth).capitalized, font: DS.Font.display(20, .heavy), kern: -0.5)

        let cal = gridCalendar
        var comps = cal.dateComponents([.year, .month], from: displayedMonth)
        comps.day = 1
        guard let startOfMonth = cal.date(from: comps),
              let daysInMonth = cal.range(of: .day, in: .month, for: startOfMonth)?.count else {
            dayItems = []
            collectionView.reloadData()
            return
        }

        let weekdayOfFirst = cal.component(.weekday, from: startOfMonth)
        let leading = (weekdayOfFirst - cal.firstWeekday + 7) % 7

        dayItems = []

        // Не показываем дни других месяцев
        for _ in 0..<leading {
            dayItems.append((nil, 0, false))
        }

        for day in 1...daysInMonth {
            if let d = cal.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                dayItems.append((d, day, true))
            }
        }

        while dayItems.count % 7 != 0 {
            dayItems.append((nil, 0, false))
        }

        while dayItems.count < 42 {
            dayItems.append((nil, 0, false))
        }

        collectionView.reloadData()
        updateMonthNavButtons()
    }

    private func buildAvailableMonths() {
        let cal = gridCalendar
        let sorted = isoDates.sorted()
        var set = Set<String>()
        var anchors: [Date] = []
        for iso in sorted {
            guard let d = Self.isoFmt.date(from: iso) else { continue }
            let comps = cal.dateComponents([.year, .month], from: d)
            let key = "\(comps.year ?? 0)-\(comps.month ?? 0)"
            if set.contains(key) { continue }
            set.insert(key)
            if let anchor = cal.date(from: comps) { anchors.append(anchor) }
        }
        availableMonthAnchors = anchors.sorted()
        displayedMonthIndex = 0
        updateMonthNavButtons()
    }

    private func setDisplayedMonth(containing date: Date) {
        let cal = gridCalendar
        let comps = cal.dateComponents([.year, .month], from: date)
        guard let anchor = cal.date(from: comps) else { return }
        if let idx = availableMonthAnchors.firstIndex(where: { cal.isDate($0, equalTo: anchor, toGranularity: .month) }) {
            displayedMonthIndex = idx
            displayedMonth = availableMonthAnchors[idx]
        } else {
            displayedMonth = anchor
        }
        updateMonthNavButtons()
    }

    private func updateMonthNavButtons() {
        prevButton.isEnabled = displayedMonthIndex > 0
        nextButton.isEnabled = displayedMonthIndex + 1 < availableMonthAnchors.count
        prevButton.alpha = prevButton.isEnabled ? 1.0 : 0.35
        nextButton.alpha = nextButton.isEnabled ? 1.0 : 0.35
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dayItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CorrespondenceCalendarDayCell.reuseId, for: indexPath) as! CorrespondenceCalendarDayCell
        guard indexPath.item < dayItems.count else {
            cell.apply(day: 0, isCurrentMonth: false, isSunday: false, hasLessons: false, isSelected: false, isSelectable: false, isToday: false)
            return cell
        }
        let item = dayItems[indexPath.item]
        guard let d = item.date else {
            cell.apply(day: 0, isCurrentMonth: false, isSunday: false, hasLessons: false, isSelected: false, isSelectable: false, isToday: false)
            return cell
        }
        let iso = Self.isoFmt.string(from: d)
        let has = isoDates.contains(iso)
        let sel = (iso == selectedISO)
        let sun = gridCalendar.component(.weekday, from: d) == 1
        // Выбираем любые дни внутри месяца: если на этот день нет пар — покажем выходной (плейсхолдером в таблице).
        let isToday = gridCalendar.isDateInToday(d)
        cell.apply(day: item.day, isCurrentMonth: item.inMonth, isSunday: sun, hasLessons: has, isSelected: sel, isSelectable: item.inMonth, isToday: isToday)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < dayItems.count,
              let d = dayItems[indexPath.item].date,
              dayItems[indexPath.item].inMonth else { return }

        let iso = Self.isoFmt.string(from: d)
        onPick?(iso)
        dismiss(animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let w = floor((collectionView.bounds.width) / 7)
        return CGSize(width: w, height: 44)
    }
}
