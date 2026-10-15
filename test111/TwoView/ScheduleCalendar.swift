//
//  ScheduleCalendar.swift
//  test111
//
//  Расписание на любую дату и календарь для всех режимов.
//
//  Очное расписание с сервера — шаблон недели 1 и недели 2, без дат.
//  Чётность сегодняшней недели известна (isOddWeek: ручная настройка или
//  weekCount с сервера), недели чередуются, поэтому для любой даты:
//  дата → понедельник её недели → сколько недель от текущей → чётность →
//  день недели → пары шаблона этой чётности.
//  У заочников дни уже датированы (isoDate), их берём как есть.
//

import UIKit

// MARK: - Расписание на дату

final class ScheduleDateResolver {

    /// Шаблоны недель по чётности (1 / 2): дни Пн…Вс, как отдаёт mapAPIScheduleToWeek
    private(set) var templates: [Int: [DaySchedule]] = [:]
    /// Датированные дни (сессия заочников)
    private(set) var dated: [String: DaySchedule] = [:]

    var isDated: Bool { !dated.isEmpty }

    static var calendar: Calendar { ScheduleTime.calendar }

    /// Чётность сегодняшней недели — то же, что использует загрузка расписания
    static var currentParity: Int {
        UserDefaults.standard.bool(forKey: "isOddWeek") ? 1 : 2
    }

    /// Понедельник недели, в которой лежит дата (начало дня)
    static func monday(of date: Date) -> Date {
        let day = Calendar.current.startOfDay(for: date)
        return Calendar.current.date(byAdding: .day, value: -ScheduleTime.weekdayIndex(of: day), to: day) ?? day
    }

    /// Сколько недель между неделей `date` и неделей `today` (со знаком)
    static func weeksFromCurrent(_ date: Date, today: Date = Date()) -> Int {
        let days = Calendar.current.dateComponents([.day], from: monday(of: today), to: monday(of: date)).day ?? 0
        // Переход на летнее время может дать 6 дней и 23 часа — округляем
        return Int((Double(days) / 7).rounded())
    }

    /// Чётность недели, в которой лежит дата: чётное число недель от текущей — та же чётность
    static func parity(of date: Date, currentParity: Int = ScheduleDateResolver.currentParity, today: Date = Date()) -> Int {
        let weeks = weeksFromCurrent(date, today: today)
        return weeks % 2 == 0 ? currentParity : 3 - currentParity
    }

    func reset() {
        templates = [:]
        dated = [:]
    }

    /// Запомнить загруженную неделю. Датированное расписание (сессия) кладём отдельно.
    func store(_ days: [DaySchedule], parity: Int) {
        if days.contains(where: { $0.isoDate != nil }) {
            templates = [:]
            dated = Dictionary(days.compactMap { d in d.isoDate.map { ($0, d) } }, uniquingKeysWith: { a, _ in a })
            return
        }
        dated = [:]
        guard !days.isEmpty else { return }
        templates[parity] = days
    }

    func hasTemplate(_ parity: Int) -> Bool { templates[parity] != nil }

    /// Неделя, для которой ещё нет шаблона (нужно догрузить)
    func missingParity(for date: Date) -> Int? {
        guard !isDated else { return nil }
        let p = Self.parity(of: date)
        return hasTemplate(p) ? nil : p
    }

    /// Пары на дату; nil — шаблон этой чётности ещё не загружен
    func lessons(on date: Date) -> [Lesson]? {
        if isDated {
            let iso = ScheduleTime.iso.string(from: date)
            return dated[iso].map { ScheduleTime.realLessons($0) } ?? []
        }
        guard let template = templates[Self.parity(of: date)] else { return nil }
        let index = ScheduleTime.weekdayIndex(of: date)
        guard index < template.count else { return [] }
        let day = template.first { $0.day == ScheduleTime.fullDays[index] } ?? template[index]
        return ScheduleTime.realLessons(day)
    }

    /// Семь дней недели, в которой лежит дата, с правильными датами. nil — шаблона нет.
    func week(containing date: Date) -> [DaySchedule]? {
        let monday = Self.monday(of: date)
        var result: [DaySchedule] = []
        for i in 0..<7 {
            let d = Calendar.current.date(byAdding: .day, value: i, to: monday) ?? monday
            guard let lessons = lessons(on: d) else { return nil }
            result.append(DaySchedule(day: ScheduleTime.fullDays[i], date: ScheduleTime.dayMonth(d), lessons: lessons))
        }
        return result
    }

    /// Месяцы, которые можно листать: для сессии — от первой до последней даты (и текущий месяц),
    /// для очного — год назад и год вперёд
    func monthRange(today: Date = Date()) -> (first: Date, last: Date) {
        let cal = Self.calendar
        func monthStart(_ d: Date) -> Date {
            cal.date(from: cal.dateComponents([.year, .month], from: d)) ?? d
        }
        let current = monthStart(today)
        if isDated {
            let dates = dated.keys.compactMap { ScheduleTime.iso.date(from: $0) }.sorted()
            let first = min(dates.first ?? today, today)
            let last = max(dates.last ?? today, today)
            return (monthStart(first), monthStart(last))
        }
        let first = cal.date(byAdding: .month, value: -12, to: current) ?? current
        let last = cal.date(byAdding: .month, value: 12, to: current) ?? current
        return (first, last)
    }
}

// MARK: - Типы пар → точки

enum LessonDot {
    /// Порядок и цвета: лекция, практика, лабораторная, экзамен/зачёт
    static let colors: [UIColor] = [DS.Color.accent, DS.Color.green, DS.Color.amber, DS.Color.red]
    static let names = ["лекция", "практика", "лабораторная", "экзамен или зачёт"]

    /// Какие типы есть в дне (номера корзин DS.LessonKind.bucket, по порядку)
    static func buckets(_ lessons: [Lesson]) -> [Int] {
        Array(Set(lessons.map { DS.LessonKind.bucket($0.type) })).sorted()
    }
}

// MARK: - Ячейка дня

private final class ScheduleCalendarDayCell: UICollectionViewCell {
    static let reuseId = "scheduleDay"

    private let circle = UIView()
    private let numberLabel = UILabel()
    private let dots = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        circle.translatesAutoresizingMaskIntoConstraints = false
        circle.layer.cornerRadius = 21
        circle.isUserInteractionEnabled = false
        contentView.addSubview(circle)
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        numberLabel.textAlignment = .center
        dots.translatesAutoresizingMaskIntoConstraints = false
        dots.axis = .horizontal
        dots.spacing = 2
        dots.alignment = .center
        circle.addSubview(numberLabel)
        circle.addSubview(dots)
        NSLayoutConstraint.activate([
            circle.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            circle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            circle.widthAnchor.constraint(equalToConstant: 42),
            circle.heightAnchor.constraint(equalToConstant: 42),
            numberLabel.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            numberLabel.centerYAnchor.constraint(equalTo: circle.centerYAnchor, constant: -3),
            dots.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            dots.topAnchor.constraint(equalTo: numberLabel.bottomAnchor, constant: 1),
            dots.heightAnchor.constraint(equalToConstant: 4)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var todayRing = false

    func applyEmpty() {
        circle.isHidden = true
        isAccessibilityElement = false
        accessibilityLabel = nil
    }

    func apply(date: Date, buckets: [Int]?, lessonCount: Int, isSelected: Bool, isToday: Bool) {
        circle.isHidden = false
        isAccessibilityElement = true
        let weekday = ScheduleTime.weekdayIndex(of: date)
        let isWeekend = weekday >= 5
        let hasLessons = lessonCount > 0
        todayRing = isToday && !isSelected

        let fg: UIColor
        circle.layer.borderWidth = 0
        if isSelected {
            circle.backgroundColor = DS.Color.brand
            fg = .white
        } else if isToday {
            circle.backgroundColor = hasLessons ? DS.Color.accentSoft : .clear
            circle.layer.borderWidth = 1.5
            fg = DS.Color.accent
        } else if hasLessons {
            circle.backgroundColor = isWeekend ? .clear : DS.Color.accentSoft
            fg = isWeekend ? DS.Color.soft : DS.Color.fg
        } else {
            circle.backgroundColor = .clear
            fg = isWeekend ? DS.Color.faint.withAlphaComponent(0.7) : DS.Color.soft
        }
        updateRingColor()
        numberLabel.setDS(ScheduleTime.dayNumber(date), font: DS.Font.text(14.5, hasLessons ? .bold : .medium), color: fg, alignment: .center)

        dots.removeAllArranged()
        for bucket in (buckets ?? []).prefix(4) {
            let dot = UIView()
            dot.backgroundColor = isSelected ? .white : LessonDot.colors[min(bucket, 3)]
            dot.layer.cornerRadius = 2
            dot.fixSize(width: 4, height: 4)
            dots.addArrangedSubview(dot)
        }

        // VoiceOver: «Четверг, 15 октября, сегодня, 3 пары: лекция, практика»
        var label = ScheduleTime.weekdayName(date) + ", " + ScheduleTime.dayMonth(date)
        if isToday { label += ", сегодня" }
        if buckets == nil {
            label += ", расписание загружается"
        } else if hasLessons {
            label += ", \(lessonCount) \(dsPlural(lessonCount, "пара", "пары", "пар")): "
            label += (buckets ?? []).map { LessonDot.names[min($0, 3)] }.joined(separator: ", ")
        } else {
            label += isWeekend ? ", выходной" : ", пар нет"
        }
        accessibilityLabel = label
        accessibilityHint = "Открыть расписание дня"
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }

    private func updateRingColor() {
        circle.layer.borderColor = DS.Color.accent.resolvedColor(with: traitCollection).cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if todayRing { updateRingColor() }
    }
}

// MARK: - Месячный календарь

/// Нижний лист с сеткой месяца (макет Session, variant calendar): точки по типам пар,
/// сегодня обведено, выходные приглушены. Нажатие на день открывает его расписание.
final class ScheduleCalendarViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    let resolver: ScheduleDateResolver
    var selectedDate: Date
    /// Выбран день
    var onPick: ((Date) -> Void)?
    /// Для дат, чья неделя ещё не загружена (очное: вторая чётность)
    var onNeedParity: ((Int) -> Void)?

    private let gridCalendar = ScheduleDateResolver.calendar
    private var displayedMonth: Date
    private var firstMonth: Date
    private var lastMonth: Date
    private var dayItems: [Date?] = []

    private let monthButton = DSTapControl()
    private let monthTitleLabel = UILabel()
    private let prevButton = DSTapControl()
    private let nextButton = DSTapControl()
    private var collectionView: UICollectionView!
    private var gridHeight: NSLayoutConstraint!
    private var legendRing: UIView?
    private let todayButton = DSButton("", style: .secondary, height: 48, fontSize: 15)

    init(resolver: ScheduleDateResolver, selectedDate: Date) {
        self.resolver = resolver
        self.selectedDate = selectedDate
        let range = resolver.monthRange()
        firstMonth = range.first
        lastMonth = range.last
        let cal = ScheduleDateResolver.calendar
        displayedMonth = cal.date(from: cal.dateComponents([.year, .month], from: selectedDate)) ?? selectedDate
        super.init(nibName: nil, bundle: nil)
        displayedMonth = min(max(displayedMonth, firstMonth), lastMonth)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Нижний лист в стиле макета Session (variant calendar)
    func presentAsSheet(from presenter: UIViewController) {
        modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *), let sheet = sheetPresentationController {
            if #available(iOS 16.0, *) {
                sheet.detents = [.custom(resolver: { _ in 500 }), .large()]
            } else {
                sheet.detents = [.large()]
            }
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = DS.Radius.sheet
        }
        presenter.present(self, animated: true)
    }

    /// Обновить сетку (например, догрузилась вторая неделя)
    func reloadDays() {
        guard isViewLoaded else { return }
        collectionView.reloadData()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.Color.bg

        // Заголовок месяца — кнопка быстрого выбора даты
        monthTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        monthTitleLabel.isUserInteractionEnabled = false
        let chevron = UIImageView(image: DS.symbol("chevron.down", size: 12, weight: .bold))
        chevron.tintColor = DS.Color.accent
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        let titleRow = UIStackView.ds(.horizontal, spacing: 6, alignment: .center, views: [monthTitleLabel, chevron])
        titleRow.isUserInteractionEnabled = false
        monthButton.addSubview(titleRow)
        NSLayoutConstraint.activate([
            titleRow.leadingAnchor.constraint(equalTo: monthButton.leadingAnchor),
            titleRow.trailingAnchor.constraint(lessThanOrEqualTo: monthButton.trailingAnchor),
            titleRow.centerYAnchor.constraint(equalTo: monthButton.centerYAnchor)
        ])
        monthButton.fixSize(height: 44)
        monthButton.accessibilityHint = "Выбрать дату"
        monthButton.accessibilityTraits = .button
        monthButton.isAccessibilityElement = true
        monthButton.onTap = { [weak self] in self?.openDatePicker() }

        for (button, symbol, label) in [(prevButton, "chevron.left", "Предыдущий месяц"), (nextButton, "chevron.right", "Следующий месяц")] {
            button.fixSize(width: 44, height: 44)
            let circle = UIView()
            circle.backgroundColor = DS.Color.sunk
            circle.layer.cornerRadius = 18
            circle.isUserInteractionEnabled = false
            let image = UIImageView(image: DS.symbol(symbol, size: 14, weight: .bold))
            image.tintColor = DS.Color.fg
            image.contentMode = .center
            circle.addSubview(image)
            image.pinEdges(to: circle)
            button.addSubview(circle)
            circle.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                circle.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                circle.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                circle.widthAnchor.constraint(equalToConstant: 36),
                circle.heightAnchor.constraint(equalToConstant: 36)
            ])
            button.isAccessibilityElement = true
            button.accessibilityLabel = label
            button.accessibilityTraits = .button
        }
        prevButton.onTap = { [weak self] in self?.shiftMonth(-1) }
        nextButton.onTap = { [weak self] in self?.shiftMonth(1) }

        let header = UIStackView.ds(.horizontal, spacing: 0, alignment: .center, views: [monthButton, UIView(), prevButton, nextButton])
        monthButton.setContentHuggingPriority(.required, for: .horizontal)

        let weekdayRow = UIStackView.ds(.horizontal)
        weekdayRow.distribution = .fillEqually
        weekdayRow.isAccessibilityElement = false
        for (i, t) in ScheduleTime.shortDays.enumerated() {
            let lab = UILabel.ds(t, font: DS.Font.text(11, .bold), color: i >= 5 ? DS.Color.faint.withAlphaComponent(0.7) : DS.Color.faint, kern: 0.55, alignment: .center)
            lab.isAccessibilityElement = false
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
        collectionView.register(ScheduleCalendarDayCell.self, forCellWithReuseIdentifier: ScheduleCalendarDayCell.reuseId)

        // Листание месяцев свайпом
        for direction in [UISwipeGestureRecognizer.Direction.left, .right] {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
            swipe.direction = direction
            collectionView.addGestureRecognizer(swipe)
        }

        let legend = makeLegend()

        todayButton.onTap = { [weak self] in
            guard let self = self else { return }
            self.pick(Date())
        }

        let stack = UIStackView.ds(.vertical, spacing: 0, views: [header, weekdayRow, collectionView, legend, todayButton])
        stack.setCustomSpacing(10, after: header)
        stack.setCustomSpacing(4, after: weekdayRow)
        stack.setCustomSpacing(10, after: collectionView)
        stack.setCustomSpacing(16, after: legend)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
        ])
        gridHeight = collectionView.heightAnchor.constraint(equalToConstant: 48 * 6)
        gridHeight.isActive = true

        rebuildMonthGrid()
    }

    private func makeLegend() -> UIView {
        func item(_ color: UIColor?, ring: Bool = false, _ text: String) -> UIView {
            let dot = UIView()
            dot.layer.cornerRadius = 4
            dot.fixSize(width: 8, height: 8)
            if let color = color { dot.backgroundColor = color }
            if ring {
                dot.layer.borderWidth = 1.5
                legendRing = dot
            }
            return UIStackView.ds(.horizontal, spacing: 6, alignment: .center, views: [dot, UILabel.ds(text, font: DS.Font.text(12), color: DS.Color.soft)])
        }
        let row1 = UIStackView.ds(.horizontal, spacing: 14, alignment: .center, views: [
            item(LessonDot.colors[0], "Лекция"), item(LessonDot.colors[1], "Практика"), item(LessonDot.colors[2], "Лабораторная"), UIView()
        ])
        let row2 = UIStackView.ds(.horizontal, spacing: 14, alignment: .center, views: [
            item(LessonDot.colors[3], "Экзамен, зачёт"), item(nil, ring: true, "Сегодня"), UIView()
        ])
        let legend = UIStackView.ds(.vertical, spacing: 8, views: [row1, row2])
        legend.isAccessibilityElement = true
        legend.accessibilityLabel = "Точки под датой: синяя — лекция, зелёная — практика, жёлтая — лабораторная, красная — экзамен или зачёт"
        let wrap = UIView()
        wrap.addSubview(legend)
        legend.pinEdges(to: wrap, insets: UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 2))
        return wrap
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
        // Цвет обводки слоя не динамический — пересчитываем под тему
        legendRing?.layer.borderColor = DS.Color.accent.resolvedColor(with: traitCollection).cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        view.setNeedsLayout()
        collectionView?.reloadData()
    }

    @objc private func swiped(_ gesture: UISwipeGestureRecognizer) {
        shiftMonth(gesture.direction == .left ? 1 : -1)
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = gridCalendar.date(byAdding: .month, value: delta, to: displayedMonth),
              next >= firstMonth, next <= lastMonth else { return }
        displayedMonth = next
        UISelectionFeedbackGenerator().selectionChanged()
        rebuildMonthGrid()
        UIAccessibility.post(notification: .layoutChanged, argument: monthButton)
    }

    private func pick(_ date: Date) {
        UISelectionFeedbackGenerator().selectionChanged()
        selectedDate = date
        onPick?(date)
        dismiss(animated: true)
    }

    private func openDatePicker() {
        let picker = ScheduleDatePickerViewController(selectedDate: selectedDate, minimum: firstMonth,
                                                      maximum: gridCalendar.date(byAdding: DateComponents(month: 1, day: -1), to: lastMonth) ?? lastMonth)
        picker.dismissesOnPick = false
        picker.onPick = { [weak self] date in
            guard let self = self else { return }
            // Быстрый переход: сразу открываем выбранный день
            self.selectedDate = date
            self.onPick?(date)
            self.presentingViewController?.dismiss(animated: true)
        }
        picker.presentAsSheet(from: self)
    }

    private func rebuildMonthGrid() {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "LLLL yyyy"
        let monthText = fmt.string(from: displayedMonth).capitalized
        monthTitleLabel.setDS(monthText, font: DS.Font.display(20, .heavy), kern: -0.5)
        monthButton.accessibilityLabel = monthText

        let cal = gridCalendar
        guard let daysInMonth = cal.range(of: .day, in: .month, for: displayedMonth)?.count else { return }
        let leading = ScheduleTime.weekdayIndex(of: displayedMonth)
        dayItems = Array(repeating: nil, count: leading)
        for day in 0..<daysInMonth {
            dayItems.append(cal.date(byAdding: .day, value: day, to: displayedMonth))
        }
        while dayItems.count % 7 != 0 { dayItems.append(nil) }
        gridHeight.constant = CGFloat(48 * (dayItems.count / 7))

        // Для очного: если в месяце есть недели незагруженной чётности — просим догрузить
        var missing = Set<Int>()
        for case let d? in dayItems { if let p = resolver.missingParity(for: d) { missing.insert(p) } }
        missing.forEach { onNeedParity?($0) }

        prevButton.isEnabled = displayedMonth > firstMonth
        nextButton.isEnabled = displayedMonth < lastMonth
        prevButton.alpha = prevButton.isEnabled ? 1 : 0.35
        nextButton.alpha = nextButton.isEnabled ? 1 : 0.35

        todayButton.title = "Сегодня, " + ScheduleTime.dayMonth(Date())
        collectionView.reloadData()
    }

    // MARK: Сетка

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dayItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ScheduleCalendarDayCell.reuseId, for: indexPath) as! ScheduleCalendarDayCell
        guard indexPath.item < dayItems.count, let date = dayItems[indexPath.item] else {
            cell.applyEmpty()
            return cell
        }
        let lessons = resolver.lessons(on: date)
        cell.apply(date: date,
                   buckets: lessons.map { LessonDot.buckets($0) },
                   lessonCount: lessons?.count ?? 0,
                   isSelected: gridCalendar.isDate(date, inSameDayAs: selectedDate),
                   isToday: gridCalendar.isDateInToday(date))
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        indexPath.item < dayItems.count && dayItems[indexPath.item] != nil
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < dayItems.count, let date = dayItems[indexPath.item] else { return }
        pick(date)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: floor(collectionView.bounds.width / 7), height: 48)
    }
}

// MARK: - Выбор даты

/// Быстрый переход к дате (макет Main, overlay datepicker): системный календарь в листе
final class ScheduleDatePickerViewController: UIViewController {
    var onPick: ((Date) -> Void)?
    /// Закрыть лист после выбора (false — закроет тот, кто показал)
    var dismissesOnPick = true

    private let picker = UIDatePicker()
    private let initialDate: Date
    private let minimum: Date
    private let maximum: Date

    init(selectedDate: Date, minimum: Date, maximum: Date) {
        initialDate = selectedDate
        self.minimum = minimum
        self.maximum = maximum
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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

        let title = UILabel.ds("Календарь", font: DS.Font.text(17, .semibold), alignment: .center)
        title.accessibilityTraits = .header
        let close = GlassIconButton(symbol: "xmark", size: 44, pointSize: 13, weight: .bold)
        close.accessibilityLabel = "Закрыть"
        close.onTap = { [weak self] in self?.dismiss(animated: true) }

        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.datePickerMode = .date
        if #available(iOS 14.0, *) { picker.preferredDatePickerStyle = .inline }
        picker.locale = Locale(identifier: "ru_RU")
        picker.calendar = ScheduleDateResolver.calendar
        picker.tintColor = DS.Color.accent
        picker.minimumDate = minimum
        picker.maximumDate = maximum
        picker.date = min(max(initialDate, minimum), maximum)
        picker.addTarget(self, action: #selector(changed), for: .valueChanged)

        view.addSubview(title)
        view.addSubview(close)
        view.addSubview(picker)
        title.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            close.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            title.centerYAnchor.constraint(equalTo: close.centerYAnchor),
            title.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            picker.topAnchor.constraint(equalTo: close.bottomAnchor, constant: 4),
            picker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            picker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12)
        ])
    }

    @objc private func changed() {
        // Листание месяца в системном календаре тоже шлёт valueChanged только при выборе дня
        let date = picker.date
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            self.onPick?(date)
            if self.dismissesOnPick { self.dismiss(animated: true) }
        }
    }
}

// MARK: - Вход экрана «Сегодня» для любой даты

extension ScheduleDateResolver {
    /// Заполняет вход экрана дня для даты. Возвращает чётность, которую нужно догрузить.
    func fillDay(_ input: inout ScheduleBoardView.Input, date: Date, currentWeek: [DaySchedule], failed: Set<Int>) -> Int? {
        input.selectedDay = ScheduleTime.weekdayIndex(of: date)
        let monday = Self.monday(of: date)
        if Calendar.current.isDate(monday, inSameDayAs: Self.monday(of: Date())) {
            input.days = currentWeek
            input.parity = Self.currentParity
            return nil
        }
        input.weekStart = monday
        let parity = Self.parity(of: date)
        input.parity = parity
        if let week = week(containing: date) {
            input.days = week
            return nil
        }
        input.days = []
        if failed.contains(parity) {
            input.weekUnavailable = true
            return nil
        }
        return parity
    }
}
