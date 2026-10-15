//
//  ScheduleBoardView.swift
//  Экран расписания в новом дизайне: «Сегодня», «Неделя», сессия заочников,
//  загрузка, без сети и ошибка. Общий для студента и преподавателя.
//  Только отображение — данные и действия приходят из контроллера.
//

import UIKit

final class ScheduleBoardView: UIView {

    struct Input {
        enum Mode { case day, week, session, sessionList }
        enum Phase { case content, loading, error }

        var who: String = ""
        var isTeacher = false
        /// Чётность недели 1/2 (nil — не показываем)
        var parity: Int?
        /// Чётность приходит с сервера — менять вручную нельзя
        var parityLocked = false
        /// Данные из кеша, сеть недоступна
        var offline = false
        var mode: Mode = .day
        var phase: Phase = .content
        var days: [DaySchedule] = []
        /// Для .day — индекс дня недели (Пн = 0)
        var selectedDay = 0
        /// Понедельник показанной недели (выбор даты из календаря); nil — текущая неделя
        var weekStart: Date?
        /// Шаблон чётности этой недели не загрузился
        var weekUnavailable = false

        /// Дата дня показанной недели
        func weekDate(_ index: Int) -> Date {
            guard let monday = weekStart else { return ScheduleTime.dateInCurrentWeek(index) }
            return Calendar.current.date(byAdding: .day, value: index, to: monday) ?? monday
        }

        /// Показана ли текущая неделя
        var isCurrentWeek: Bool {
            guard let monday = weekStart else { return true }
            return Calendar.current.isDate(monday, inSameDayAs: ScheduleDateResolver.monday(of: Date()))
        }
        /// Для .session — выбранная дата yyyy-MM-dd
        var selectedISO: String?
        /// Можно ли открыть выбор группы из шапки
        var canChangeGroup = true
        /// Выбрана ли группа/преподаватель вообще
        var hasSelection = true
    }

    // Действия
    var onSelectGroup: (() -> Void)?
    var onOpenWeek: (() -> Void)?
    var onSelectDay: ((Int) -> Void)?
    var onSelectISO: ((String) -> Void)?
    var onOpenCalendar: (() -> Void)?
    /// Быстрый выбор даты (долгое нажатие на кнопку календаря)
    var onOpenDatePicker: (() -> Void)?
    var onRetryWeek: (() -> Void)?
    var onBackToToday: (() -> Void)?
    var onRetry: (() -> Void)?
    var onParity: ((Int) -> Void)?

    private(set) var input = Input()

    private let backdrop = BackdropView()
    private let scrollView = UIScrollView()
    private let stack = UIStackView.ds(.vertical)
    private let header = UIStackView.ds(.horizontal, spacing: 6, alignment: .center)
    private var stackTop: NSLayoutConstraint!
    private var headerTop: NSLayoutConstraint!
    private var minuteTimer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = DS.Color.bg

        addSubview(backdrop)
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: trailingAnchor),
            backdrop.heightAnchor.constraint(equalToConstant: 380)
        ])

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        addSubview(scrollView)
        scrollView.pinEdges(to: self)

        scrollView.addSubview(stack)
        stackTop = stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 116)
        NSLayoutConstraint.activate([
            stackTop,
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: DS.Inset.side),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -DS.Inset.side),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -DS.Inset.bottomForNav)
        ])

        addSubview(header)
        headerTop = header.topAnchor.constraint(equalTo: topAnchor, constant: 58)
        NSLayoutConstraint.activate([
            headerTop,
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DS.Inset.side),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DS.Inset.side),
            header.heightAnchor.constraint(equalToConstant: DS.Inset.headerHeight)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        // headTop 58 / top 116 в макете при статус-баре 54
        let top = max(safeAreaInsets.top, 20)
        headerTop.constant = top + 4
        stackTop.constant = top + 4 + DS.Inset.headerHeight + DS.Inset.contentBelowHeader
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        minuteTimer?.invalidate()
        minuteTimer = nil
        guard window != nil else { return }
        // Карточка «Сейчас» и прогресс пары обновляются раз в минуту
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self, self.input.phase == .content, self.input.mode == .day else { return }
            self.render(self.input, animated: false)
        }
        RunLoop.main.add(timer, forMode: .common)
        minuteTimer = timer
    }

    func scrollToTop() {
        scrollView.setContentOffset(.zero, animated: false)
    }

    // MARK: - Рендер

    func render(_ input: Input, animated: Bool) {
        self.input = input
        buildHeader()
        stack.removeAllArranged()

        switch input.phase {
        case .error:
            buildError()
        case .loading, .content:
            switch input.mode {
            case .day: buildDay()
            case .week: buildWeek()
            case .session: buildSession()
            case .sessionList: buildSessionList()
            }
        }

        layoutIfNeeded()
        if animated { animateIn() }
    }

    private func animateIn() {
        for (i, view) in stack.arrangedSubviews.enumerated() {
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: 0, y: 12)
            UIView.animate(withDuration: 0.5, delay: 0.03 * Double(min(i, 12)), usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: [.allowUserInteraction], animations: {
                view.alpha = 1
                view.transform = .identity
            })
        }
    }

    private func add(_ view: UIView, spacingAfterPrevious: CGFloat) {
        if let last = stack.arrangedSubviews.last {
            stack.setCustomSpacing(spacingAfterPrevious, after: last)
        }
        stack.addArrangedSubview(view)
    }

    // MARK: Шапка

    private func buildHeader() {
        header.removeAllArranged()
        let pill = GroupPillButton(who: input.who.isEmpty ? "Выбрать группу" : input.who, isTeacher: input.isTeacher)
        pill.isEnabled = input.canChangeGroup
        pill.onTap = { [weak self] in self?.onSelectGroup?() }
        pill.accessibilityLabel = input.isTeacher ? "Сменить преподавателя" : "Сменить группу"
        header.addArrangedSubview(pill)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(spacer)

        guard input.phase != .error else { return }
        switch input.mode {
        case .day:
            if let parity = input.parity {
                let chip = ParityChip(parity: parity)
                chip.onTap = { [weak self] in self?.onOpenWeek?() }
                header.addArrangedSubview(chip)
            }
            if input.phase == .content { header.addArrangedSubview(calendarButton("Календарь")) }
        case .session, .sessionList:
            if !input.days.isEmpty {
                header.addArrangedSubview(calendarButton("Календарь сессии"))
            }
        case .week:
            if input.phase == .content { header.addArrangedSubview(calendarButton("Календарь")) }
        }
    }

    /// Кнопка календаря в шапке: нажатие — месяц, долгое нажатие — быстрый выбор даты
    private func calendarButton(_ label: String) -> UIView {
        let button = GlassIconButton(symbol: "calendar")
        button.accessibilityLabel = label
        button.accessibilityHint = "Месяц с парами. Долгое нажатие — выбрать дату"
        button.onTap = { [weak self] in self?.onOpenCalendar?() }
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(calendarLongPress(_:)))
        button.addGestureRecognizer(longPress)
        button.accessibilityCustomActions = [UIAccessibilityCustomAction(name: "Выбрать дату", target: self, selector: #selector(openDatePickerAction))]
        return button
    }

    @objc private func calendarLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onOpenDatePicker?()
    }

    @objc private func openDatePickerAction() -> Bool {
        onOpenDatePicker?()
        return true
    }

    // MARK: «Сегодня» / день недели

    private func buildDay() {
        let todayIndex = input.isCurrentWeek ? ScheduleTime.weekdayIndex(of: Date()) : -1
        let index = min(max(input.selectedDay, 0), 6)
        let isToday = index == todayIndex
        let date = input.weekDate(index)
        let day = index < input.days.count ? input.days[index] : nil
        let lessons = day.map { ScheduleTime.realLessons($0) } ?? []
        let isLoading = input.phase == .loading
        let dayName = ScheduleTime.fullDays[index]
        let dateText = ScheduleTime.dayMonth(date)

        // Надзаголовок, заголовок, подзаголовок
        var eyebrow = dayName
        if let parity = input.parity { eyebrow += " · Неделя \(parity)" }
        let dayOff = lessons.isEmpty && !isLoading
        if dayOff && isToday { eyebrow = dayName + " · " + dateText }
        add(EyebrowPill(eyebrow).leftAligned(), spacingAfterPrevious: 0)

        let title: String
        if dayOff && isToday { title = "Выходной" } else { title = isToday ? "Сегодня" : dayName }
        add(UILabel.display(title, size: 36), spacingAfterPrevious: 10)

        var sub = dateText
        if dayOff && isToday {
            sub = "Пар нет — можно выдохнуть"
        } else if let first = lessons.first, let last = lessons.last {
            sub += " · \(lessons.count) \(dsPlural(lessons.count, "пара", "пары", "пар")), \(ScheduleTime.span(first).start)–\(ScheduleTime.span(last).end)"
        } else if !isLoading {
            sub += " · пар нет"
        }
        add(UILabel.ds(sub, font: DS.Font.text(14), color: DS.Color.soft, lines: 0), spacingAfterPrevious: 4)

        if !input.isCurrentWeek {
            let back = DSButton("Вернуться к сегодня", style: .outlineAccent, height: 44, fontSize: 13.5, icon: DS.symbol("arrow.uturn.backward", size: 12, weight: .semibold))
            back.onTap = { [weak self] in self?.onBackToToday?() }
            add(back.leftAligned(), spacingAfterPrevious: 12)
        }

        if input.isTeacher && !lessons.isEmpty {
            add(teacherStats(lessons), spacingAfterPrevious: 16)
        }
        if input.offline {
            add(OfflineBanner(onRetry: { [weak self] in self?.onRetry?() }), spacingAfterPrevious: 16)
        }

        let strip = DayStripView(days: input.days, selected: index, today: todayIndex, monday: input.weekDate(0))
        strip.onSelect = { [weak self] i in self?.onSelectDay?(i) }
        add(strip, spacingAfterPrevious: 16)

        if isLoading {
            add(SkeletonView.block(height: 176, radius: 20), spacingAfterPrevious: 16)
            let line = SkeletonView.block(height: 14, radius: 6)
            line.widthAnchor.constraint(equalToConstant: 120).isActive = true
            add(line.leftAligned(), spacingAfterPrevious: 26)
            for _ in 0..<3 { add(SkeletonView.block(height: 92, radius: 16), spacingAfterPrevious: 8) }
            add(UILabel.ds("Загружаем расписание ИМСИТ…", font: DS.Font.text(12.5), color: DS.Color.faint, alignment: .center), spacingAfterPrevious: 16)
            return
        }

        if input.weekUnavailable {
            add(weekUnavailableCard(), spacingAfterPrevious: 16)
            return
        }

        if dayOff {
            add(dayOffCard(isToday: isToday, after: index), spacingAfterPrevious: 16)
            return
        }

        // Текущая пара
        let nowMinutes = ScheduleTime.minutes(of: Date())
        var nowIndex: Int?
        if isToday {
            nowIndex = lessons.firstIndex { ScheduleTime.span($0).startMin <= nowMinutes && nowMinutes < ScheduleTime.span($0).endMin }
        }
        if let nowIndex = nowIndex {
            let card = NowCardView(lesson: lessons[nowIndex], isTeacher: input.isTeacher, nowMinutes: nowMinutes)
            card.onCopy = { [weak self] link in self?.copyEios(link) }
            add(card, spacingAfterPrevious: 16)
        }

        // Список пар
        let remaining = lessons.enumerated().filter { $0.offset != nowIndex }
        if !remaining.isEmpty {
            let listHeader = UIView()
            let titleLabel = UILabel.display(isToday ? "Дальше сегодня" : "Пары", size: 18, weight: .bold, lines: 1)
            listHeader.addSubview(titleLabel)
            var constraints = [
                titleLabel.leadingAnchor.constraint(equalTo: listHeader.leadingAnchor, constant: 2),
                titleLabel.topAnchor.constraint(equalTo: listHeader.topAnchor),
                titleLabel.bottomAnchor.constraint(equalTo: listHeader.bottomAnchor)
            ]
            if isToday, let last = lessons.last {
                let meta = UILabel.ds("до " + ScheduleTime.span(last).end, font: DS.Font.mono(11.5), color: DS.Color.faint)
                listHeader.addSubview(meta)
                constraints += [
                    meta.trailingAnchor.constraint(equalTo: listHeader.trailingAnchor, constant: -2),
                    meta.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor)
                ]
            }
            NSLayoutConstraint.activate(constraints)
            add(listHeader, spacingAfterPrevious: 26)

            var first = true
            for (offset, lesson) in remaining {
                if !first, offset > 0, let text = ScheduleTime.breakText(after: lessons[offset - 1], before: lesson) {
                    add(BreakRow(text: text), spacingAfterPrevious: 8)
                }
                let past = isToday && ScheduleTime.span(lesson).endMin <= nowMinutes
                let card = LessonCardView(lesson: lesson, isTeacher: input.isTeacher)
                card.alpha = past ? 0.5 : 1
                card.onCopy = { [weak self] link in self?.copyEios(link) }
                add(card, spacingAfterPrevious: first ? 12 : 8)
                first = false
            }
        }

        // Завтра
        if isToday, let teaser = tomorrowTeaser(after: index) {
            add(teaser, spacingAfterPrevious: 18)
        }
    }

    /// Неделя другой чётности не загрузилась (нет сети и кеша)
    private func weekUnavailableCard() -> UIView {
        let card = CardView(radius: DS.Radius.hero, shadow: .sm)
        let icon = IconBadge(symbol: "icloud.slash", size: 32, pointSize: 15, tint: DS.Color.amberFg, fill: UIColor(rgb: 0xF59E0B, alpha: 0.14))
        let title = UILabel.ds("Не удалось загрузить неделю \(input.parity ?? 1)", font: DS.Font.text(14, .semibold), lines: 0)
        let text = UILabel.ds("Для этой даты нужно расписание другой недели. Проверьте подключение.", font: DS.Font.text(13), color: DS.Color.soft, lines: 0, lineHeight: 19)
        let texts = UIStackView.ds(.vertical, spacing: 2, views: [title, text])
        let top = UIStackView.ds(.horizontal, spacing: 12, alignment: .top, views: [icon, texts])
        let retry = DSButton("Повторить", style: .outlineAccent, height: 44, fontSize: 13.5)
        retry.onTap = { [weak self] in self?.onRetryWeek?() }
        let col = UIStackView.ds(.vertical, spacing: 14, views: [top, retry])
        card.addSubview(col)
        col.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return card
    }

    private func teacherStats(_ lessons: [Lesson]) -> UIView {
        let groups = Set(lessons.map { ScheduleTime.who(for: $0, isTeacher: true).who }.filter { !$0.isEmpty }).count
        var rooms: [String: Int] = [:]
        lessons.forEach { if !$0.room.isEmpty { rooms[$0.room, default: 0] += 1 } }
        let topRoom = rooms.max { $0.value < $1.value }?.key ?? "—"
        let items: [(String, String)] = [
            (String(lessons.count), dsPlural(lessons.count, "пара", "пары", "пар") + " сегодня"),
            (String(groups), dsPlural(groups, "группа", "группы", "групп")),
            (topRoom, "чаще всего")
        ]
        let row = UIStackView.ds(.horizontal, spacing: 8)
        row.distribution = .fillEqually
        for (value, key) in items {
            let tile = CardView(radius: DS.Radius.tile, shadow: .xs)
            let v = UILabel.ds(value, font: DS.Font.mono(20, .bold))
            v.adjustsFontSizeToFitWidth = true
            v.minimumScaleFactor = 0.6
            let k = UILabel.ds(key, font: DS.Font.text(11.5), color: DS.Color.soft)
            let col = UIStackView.ds(.vertical, spacing: 2, views: [v, k])
            tile.addSubview(col)
            col.pinEdges(to: tile, insets: UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
            row.addArrangedSubview(tile)
        }
        return row
    }

    private func dayOffCard(isToday: Bool, after index: Int) -> UIView {
        let card = CardView(radius: DS.Radius.hero, shadow: .sm)
        let image = UIImageView(image: UIImage(named: isToday ? "IlloFree" : "IlloDayOff"))
        image.contentMode = .scaleAspectFit
        image.fixSize(width: 150, height: 150)
        let title = UILabel.display(isToday ? "Пар нет — отдыхайте" : "Пар нет", size: 20, alignment: .center)
        var views: [UIView] = [image, title]
        if let next = nearestLesson(after: index) {
            let text = NSMutableAttributedString(attributedString: .ds("Ближайшая пара — \(next.dayName.lowercased()), ", font: DS.Font.text(13.5), color: DS.Color.soft, lineHeight: 20, alignment: .center))
            text.append(.ds(ScheduleTime.span(next.lesson).start, font: DS.Font.mono(12.5), color: DS.Color.soft, lineHeight: 20, alignment: .center))
            text.append(.ds(", " + ScheduleTime.who(for: next.lesson, isTeacher: input.isTeacher).subject, font: DS.Font.text(13.5), color: DS.Color.soft, lineHeight: 20, alignment: .center))
            if !next.lesson.room.isEmpty {
                text.append(.ds(", ауд. ", font: DS.Font.text(13.5), color: DS.Color.soft, lineHeight: 20, alignment: .center))
                text.append(.ds(next.lesson.room, font: DS.Font.mono(12.5), color: DS.Color.soft, lineHeight: 20, alignment: .center))
            }
            let label = UILabel()
            label.numberOfLines = 0
            label.attributedText = text
            views.append(label)
        }
        let button = DSButton("Открыть неделю", style: .secondary, height: 42, fontSize: 14)
        button.onTap = { [weak self] in self?.onOpenWeek?() }
        views.append(button)
        let col = UIStackView.ds(.vertical, spacing: 0, alignment: .center, views: views)
        col.setCustomSpacing(-6, after: image)
        if views.count > 3 { col.setCustomSpacing(6, after: title); col.setCustomSpacing(14, after: views[2]) } else { col.setCustomSpacing(14, after: title) }
        card.addSubview(col)
        col.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 18, bottom: 18, right: 18))
        return card
    }

    private func nearestLesson(after index: Int) -> (dayName: String, lesson: Lesson)? {
        guard index + 1 < input.days.count else { return nil }
        for i in (index + 1)..<input.days.count {
            if let lesson = ScheduleTime.realLessons(input.days[i]).first {
                return (ScheduleTime.fullDays[min(i, 6)], lesson)
            }
        }
        return nil
    }

    private func tomorrowTeaser(after index: Int) -> UIView? {
        guard index + 1 < input.days.count, index + 1 < 7 else { return nil }
        guard let lesson = ScheduleTime.realLessons(input.days[index + 1]).first else { return nil }
        let date = input.weekDate(index + 1)
        let card = CardView(radius: DS.Radius.card, shadow: .none)
        card.fill = .clear
        card.dashed = true
        card.borderColor = DS.Color.borderStrong
        let control = DSTapControl()
        control.onTap = { [weak self] in self?.onOpenWeek?() }
        card.addSubview(control)
        control.pinEdges(to: card)

        let eb = UILabel.eyebrow("Завтра · " + ScheduleTime.shortDays[index + 1] + ", " + ScheduleTime.dayShortMonth(date), size: 10)
        let parts = ScheduleTime.who(for: lesson, isTeacher: input.isTeacher)
        let typeText = lesson.type.trimmingCharacters(in: .whitespaces)
        let main = UILabel.ds((typeText.isEmpty ? "" : typeText + " · ") + parts.subject, font: DS.Font.text(14, .semibold), lines: 2)
        let meta = UILabel.ds(ScheduleTime.span(lesson).start + (lesson.room.isEmpty ? "" : " · ауд. " + lesson.room), font: DS.Font.mono(11.5), color: DS.Color.soft)
        let texts = UIStackView.ds(.vertical, spacing: 2, views: [eb, main, meta])
        let chevron = UIImageView(image: DS.symbol("chevron.right", size: 13, weight: .semibold))
        chevron.tintColor = DS.Color.faint
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView.ds(.horizontal, spacing: 12, alignment: .center, views: [texts, chevron])
        row.isUserInteractionEnabled = false
        card.addSubview(row)
        row.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14))
        return card
    }

    // MARK: «Неделя»

    private func buildWeek() {
        let todayIndex = ScheduleTime.weekdayIndex(of: Date())
        let monday = ScheduleTime.dateInCurrentWeek(0)
        let lastIndex = input.days.count > 6 && !ScheduleTime.realLessons(input.days[6]).isEmpty ? 6 : 5
        let range = ScheduleTime.dayNumber(monday) + " – " + ScheduleTime.dayMonth(ScheduleTime.dateInCurrentWeek(lastIndex))
        add(EyebrowPill(range).leftAligned(), spacingAfterPrevious: 0)

        let all = input.days.flatMap { ScheduleTime.realLessons($0) }
        let studyDays = input.days.filter { !ScheduleTime.realLessons($0).isEmpty }.count

        let titleRow = UIStackView.ds(.horizontal, spacing: 12, alignment: .bottom)
        let title = UILabel.display(input.parity.map { "Неделя \($0)" } ?? "Неделя", size: 36, lines: 1)
        let sub = NSMutableAttributedString(attributedString: .ds("\(all.count)", font: DS.Font.mono(13), color: DS.Color.soft))
        sub.append(.ds(" " + dsPlural(all.count, "пара", "пары", "пар") + " · ", font: DS.Font.text(14), color: DS.Color.soft))
        sub.append(.ds("\(studyDays)", font: DS.Font.mono(13), color: DS.Color.soft))
        sub.append(.ds(" " + dsPlural(studyDays, "учебный день", "учебных дня", "учебных дней"), font: DS.Font.text(14), color: DS.Color.soft))
        let subLabel = UILabel()
        subLabel.attributedText = sub
        let left = UIStackView.ds(.vertical, spacing: 4, views: [title, subLabel])
        titleRow.addArrangedSubview(left)
        if let parity = input.parity {
            let seg = DSSegmentedControl(items: ["1", "2"], segmentHeight: 30, fontSize: 13, mono: true, minSegmentWidth: 38)
            seg.selectedIndex = parity == 1 ? 0 : 1
            seg.isEnabled = !input.parityLocked
            seg.addTarget(self, action: #selector(paritySegmentChanged(_:)), for: .valueChanged)
            seg.widthAnchor.constraint(equalToConstant: 88).isActive = true
            titleRow.addArrangedSubview(seg)
        }
        add(titleRow, spacingAfterPrevious: 10)

        if input.offline {
            add(OfflineBanner(onRetry: { [weak self] in self?.onRetry?() }), spacingAfterPrevious: 16)
        }

        if input.phase == .loading {
            for _ in 0..<3 { add(SkeletonView.block(height: 120, radius: 16), spacingAfterPrevious: 16) }
            return
        }

        if !all.isEmpty {
            add(MixCard(lessons: all), spacingAfterPrevious: 16)
        }

        let nowMinutes = ScheduleTime.minutes(of: Date())
        for (i, day) in input.days.prefix(7).enumerated() {
            let lessons = ScheduleTime.realLessons(day)
            if i == 6 && lessons.isEmpty { continue }
            let date = ScheduleTime.dateInCurrentWeek(i)
            let isToday = i == todayIndex
            let section = WeekDaySection(name: ScheduleTime.fullDays[i], date: ScheduleTime.dayShortMonth(date), lessons: lessons, isToday: isToday, isTeacher: input.isTeacher, nowMinutes: isToday ? nowMinutes : nil)
            section.alpha = i < todayIndex ? 0.6 : 1
            add(section, spacingAfterPrevious: 24)
        }
    }

    @objc private func paritySegmentChanged(_ sender: DSSegmentedControl) {
        onParity?(sender.selectedIndex == 0 ? 1 : 2)
    }

    // MARK: Сессия заочников

    private func sessionHeader() {
        add(EyebrowPill("Заочная форма · сессия").leftAligned(), spacingAfterPrevious: 0)
        add(UILabel.display("Сессия", size: 36), spacingAfterPrevious: 10)
        let dates = input.days.compactMap { $0.isoDate.flatMap(ScheduleTime.iso.date(from:)) }.sorted()
        if let first = dates.first, let last = dates.last {
            let sub = NSMutableAttributedString(attributedString: .ds(ScheduleTime.dayMonth(first) + " – " + ScheduleTime.dayMonth(last) + " · ", font: DS.Font.text(14), color: DS.Color.soft))
            let count = input.days.filter { !ScheduleTime.realLessons($0).isEmpty }.count
            sub.append(.ds("\(count)", font: DS.Font.mono(13), color: DS.Color.soft))
            sub.append(.ds(" " + dsPlural(count, "учебный день", "учебных дня", "учебных дней"), font: DS.Font.text(14), color: DS.Color.soft))
            let label = UILabel()
            label.numberOfLines = 0
            label.attributedText = sub
            add(label, spacingAfterPrevious: 4)
        }
        if input.offline {
            add(OfflineBanner(onRetry: { [weak self] in self?.onRetry?() }), spacingAfterPrevious: 16)
        }
    }

    private func buildSession() {
        sessionHeader()
        let selectedISO = input.selectedISO ?? ScheduleTime.iso.string(from: Date())
        let ribbon = SessionRibbonView(days: input.days, selectedISO: selectedISO)
        ribbon.onSelect = { [weak self] iso in self?.onSelectISO?(iso) }
        add(ribbon, spacingAfterPrevious: 16)

        let selectedDate = ScheduleTime.iso.date(from: selectedISO) ?? Date()
        let day = input.days.first { $0.isoDate == selectedISO }
        let lessons = day.map { ScheduleTime.realLessons($0) } ?? []

        let titleRow = UIView()
        let dayTitle = UILabel.display(ScheduleTime.weekdayName(selectedDate) + ", " + ScheduleTime.dayMonth(selectedDate), size: 18, weight: .bold, lines: 1)
        titleRow.addSubview(dayTitle)
        let metaText: String
        if let first = lessons.first, let last = lessons.last {
            metaText = "\(lessons.count) \(dsPlural(lessons.count, "пара", "пары", "пар")) · \(ScheduleTime.span(first).start)–\(ScheduleTime.span(last).end)"
        } else {
            metaText = "нет занятий"
        }
        let meta = UILabel.ds(metaText, font: DS.Font.mono(11.5), color: DS.Color.faint)
        meta.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleRow.addSubview(meta)
        NSLayoutConstraint.activate([
            dayTitle.leadingAnchor.constraint(equalTo: titleRow.leadingAnchor, constant: 2),
            dayTitle.topAnchor.constraint(equalTo: titleRow.topAnchor),
            dayTitle.bottomAnchor.constraint(equalTo: titleRow.bottomAnchor),
            meta.leadingAnchor.constraint(greaterThanOrEqualTo: dayTitle.trailingAnchor, constant: 8),
            meta.trailingAnchor.constraint(equalTo: titleRow.trailingAnchor, constant: -2),
            meta.centerYAnchor.constraint(equalTo: dayTitle.centerYAnchor)
        ])
        add(titleRow, spacingAfterPrevious: 22)

        if input.phase == .loading {
            for _ in 0..<3 { add(SkeletonView.block(height: 92, radius: 16), spacingAfterPrevious: 8) }
            return
        }

        if lessons.isEmpty {
            add(sessionEmptyCard(selectedISO: selectedISO), spacingAfterPrevious: 12)
        } else {
            var first = true
            for lesson in lessons {
                let card = LessonCardView(lesson: lesson, isTeacher: input.isTeacher)
                card.onCopy = { [weak self] link in self?.copyEios(link) }
                add(card, spacingAfterPrevious: first ? 12 : 8)
                first = false
            }
        }
    }

    private func sessionEmptyCard(selectedISO: String) -> UIView {
        let card = CardView(radius: DS.Radius.hero, shadow: .sm)
        let image = UIImageView(image: UIImage(named: "IlloFree"))
        image.contentMode = .scaleAspectFit
        image.fixSize(width: 130, height: 130)
        let title = UILabel.display("На эту дату занятий нет", size: 18, alignment: .center)
        var views: [UIView] = [image, title]
        let dataDates = input.days.filter { !ScheduleTime.realLessons($0).isEmpty }.compactMap { $0.isoDate }.sorted()
        let nearest = dataDates.first { $0 > selectedISO } ?? dataDates.last { $0 < selectedISO }
        if let nearest = nearest, let date = ScheduleTime.iso.date(from: nearest) {
            let text = UILabel.ds("Ближайший день сессии — " + ScheduleTime.weekdayName(date).lowercased() + ", " + ScheduleTime.dayMonth(date), font: DS.Font.text(13.5), color: DS.Color.soft, lines: 0, alignment: .center)
            views.append(text)
            let button = DSButton("Перейти к " + ScheduleTime.dayMonth(date), style: .outlineAccent, height: 40, fontSize: 13.5)
            button.onTap = { [weak self] in self?.onSelectISO?(nearest) }
            views.append(button)
        }
        let col = UIStackView.ds(.vertical, spacing: 4, alignment: .center, views: views)
        if views.count > 3 { col.setCustomSpacing(14, after: views[2]) }
        card.addSubview(col)
        col.pinEdges(to: card, insets: UIEdgeInsets(top: 8, left: 18, bottom: 20, right: 18))
        return card
    }

    private func buildSessionList() {
        sessionHeader()
        if input.phase == .loading {
            for _ in 0..<3 { add(SkeletonView.block(height: 120, radius: 16), spacingAfterPrevious: 16) }
            return
        }
        let todayISO = ScheduleTime.iso.string(from: Date())
        let nowMinutes = ScheduleTime.minutes(of: Date())
        let sorted = input.days.sorted { ($0.isoDate ?? "") < ($1.isoDate ?? "") }
        var first = true
        for day in sorted {
            let lessons = ScheduleTime.realLessons(day)
            guard !lessons.isEmpty, let iso = day.isoDate, let date = ScheduleTime.iso.date(from: iso) else { continue }
            let isToday = iso == todayISO
            let section = WeekDaySection(name: ScheduleTime.weekdayName(date), date: ScheduleTime.dayShortMonth(date), lessons: lessons, isToday: isToday, isTeacher: input.isTeacher, nowMinutes: isToday ? nowMinutes : nil)
            section.alpha = iso < todayISO ? 0.6 : 1
            add(section, spacingAfterPrevious: first ? 16 : 24)
            first = false
        }
    }

    // MARK: Ошибка

    private func buildError() {
        let image = UIImageView(image: UIImage(named: "IlloError"))
        image.contentMode = .scaleAspectFit
        image.fixSize(width: 176, height: 176)
        add(image.centered(), spacingAfterPrevious: 0)

        let title = input.hasSelection ? "Что-то пошло не так" : (input.isTeacher ? "Выберите преподавателя" : "Выберите группу")
        add(UILabel.display(title, size: 28, alignment: .center), spacingAfterPrevious: 0)
        let text = input.hasSelection
            ? "Не удалось получить расписание с сервера академии. Сохранённых данных пока нет."
            : "Расписание появится здесь, как только вы выберете, чьё расписание открыть."
        add(UILabel.ds(text, font: DS.Font.text(14.5), color: DS.Color.soft, lines: 0, lineHeight: 22, alignment: .center), spacingAfterPrevious: 8)

        if input.hasSelection {
            let group = DSListGroup()
            let caption = UILabel.eyebrow("Пожалуйста, проверьте", size: 10)
            let captionWrap = UIView()
            captionWrap.addSubview(caption)
            caption.pinEdges(to: captionWrap, insets: UIEdgeInsets(top: 12, left: 14, bottom: 4, right: 14))
            group.add(captionWrap)
            let checks: [(String, String)] = [
                ("wifi", "Стабильно ли интернет-соединение"),
                ("trash", "Очистите кеш приложения в настройках телефона"),
                ("arrow.clockwise", "Перезапустите приложение"),
                ("globe", "Возможны временные проблемы на imsit.ru")
            ]
            for (i, item) in checks.enumerated() {
                let badge = IconBadge(symbol: item.0, size: 30, pointSize: 14)
                let label = UILabel.ds(item.1, font: DS.Font.text(13.5), lines: 0)
                let row = UIStackView.ds(.horizontal, spacing: 12, alignment: .center, views: [badge, label])
                let wrap = UIView()
                wrap.addSubview(row)
                row.pinEdges(to: wrap, insets: UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14))
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
            add(group, spacingAfterPrevious: 20)

            let retry = DSButton("Повторить")
            retry.onTap = { [weak self] in self?.onRetry?() }
            add(retry, spacingAfterPrevious: 18)

            let help = NSMutableAttributedString(attributedString: .ds("Не помогло? Напишите разработчику — ", font: DS.Font.text(13), color: DS.Color.soft, alignment: .center))
            help.append(.ds("@tsep1lov", font: DS.Font.text(13, .semibold), color: DS.Color.accent, alignment: .center))
            let helpLabel = UILabel()
            helpLabel.numberOfLines = 0
            helpLabel.attributedText = help
            add(helpLabel, spacingAfterPrevious: 14)
        } else {
            let choose = DSButton(input.isTeacher ? "Выбрать преподавателя" : "Выбрать группу")
            choose.onTap = { [weak self] in self?.onSelectGroup?() }
            add(choose, spacingAfterPrevious: 20)
        }
    }

    // MARK: eios

    private func copyEios(_ link: String) {
        UIPasteboard.general.string = link
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DSToast.show(title: "Ссылка eios скопирована", detail: "вставьте в браузер", in: self)
    }
}

// MARK: - Время и даты

enum ScheduleTime {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ru_RU")
        c.firstWeekday = 2
        return c
    }()

    static let iso: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let fullDays = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]
    static let shortDays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    private static let monthsGenitive = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
    private static let monthsShort = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]

    static let placeholderSubjects: Set<String> = ["Сегодня выходной. Наслаждайтесь отдыхом!", "На эту дату занятий нет."]

    /// Пн = 0 … Вс = 6
    static func weekdayIndex(of date: Date) -> Int {
        let weekday = Calendar.current.component(.weekday, from: date)
        return (weekday + 5) % 7
    }

    /// Дата дня текущей недели (как `calculateWeekDates` в контроллерах)
    static func dateInCurrentWeek(_ index: Int) -> Date {
        let today = Date()
        let monday = Calendar.current.date(byAdding: .day, value: -weekdayIndex(of: today), to: today) ?? today
        return Calendar.current.date(byAdding: .day, value: index, to: monday) ?? today
    }

    static func dayMonth(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.day, .month], from: date)
        return "\(c.day ?? 1) \(monthsGenitive[(c.month ?? 1) - 1])"
    }

    static func dayShortMonth(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.day, .month], from: date)
        return "\(c.day ?? 1) \(monthsShort[(c.month ?? 1) - 1])"
    }

    static func dayNumber(_ date: Date) -> String {
        return String(Calendar.current.component(.day, from: date))
    }

    static func weekdayName(_ date: Date) -> String {
        return fullDays[weekdayIndex(of: date)]
    }

    static func minutes(of date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func realLessons(_ day: DaySchedule) -> [Lesson] {
        return day.lessons.filter { !placeholderSubjects.contains($0.subject) && !$0.subject.isEmpty }
    }

    struct Span { let start: String; let end: String; let startMin: Int; let endMin: Int }

    /// "08:00-09:30" / "08.00-09.30" / "08:00–09:30"
    static func span(_ lesson: Lesson) -> Span {
        let normalized = lesson.time
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: " ", with: "")
        let parts = normalized.split(separator: "-").map { String($0).replacingOccurrences(of: ".", with: ":") }
        let start = parts.first ?? ""
        let end = parts.count > 1 ? parts[1] : ""
        return Span(start: pad(start), end: pad(end), startMin: toMinutes(start) ?? 0, endMin: toMinutes(end) ?? 0)
    }

    private static func pad(_ t: String) -> String {
        guard let m = toMinutes(t) else { return t }
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    private static func toMinutes(_ t: String) -> Int? {
        let p = t.split(separator: ":")
        guard p.count == 2, let h = Int(p[0]), let m = Int(p[1]) else { return nil }
        return h * 60 + m
    }

    static func breakText(after prev: Lesson, before next: Lesson) -> String? {
        let gap = span(next).startMin - span(prev).endMin
        guard gap > 0 else { return nil }
        if gap >= 60 {
            let hours = (Double(gap) / 60 * 10).rounded() / 10
            let text = hours == hours.rounded() ? String(Int(hours)) : String(format: "%.1f", hours).replacingOccurrences(of: ".", with: ",")
            return "окно \(text) ч"
        }
        return "\(gap) мин · " + (gap >= 20 ? "большая перемена" : "перемена")
    }

    /// Кто ведёт / какие группы, и название предмета без префикса групп
    static func who(for lesson: Lesson, isTeacher: Bool) -> (who: String, subject: String) {
        let (group, subject) = splitGroupAndSubject(lesson.subject)
        if !lesson.teacher.isEmpty { return (lesson.teacher, subject) }
        return (group, subject)
    }

    /// Как в старой ячейке: «22-ДЗ-02,23-ДЗ-01 Предмет» → группы и предмет
    static func splitGroupAndSubject(_ original: String) -> (String, String) {
        let pattern = "^\\s*([0-9]{2}-[A-Za-zА-Яа-яЁё-]+-[0-9]{2}(?:\\s*,\\s*[0-9]{2}-[A-Za-zА-Яа-яЁё-]+-[0-9]{2})*)\\s*(.*)$"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: original, range: NSRange(location: 0, length: (original as NSString).length)),
           match.numberOfRanges >= 3 {
            let ns = original as NSString
            let group = ns.substring(with: match.range(at: 1))
            let subject = ns.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            return (group, subject.isEmpty ? original : subject)
        }
        return ("", original)
    }

    /// «1-201» → «корпус 1»
    static func building(of room: String) -> String? {
        guard let dash = room.firstIndex(of: "-") else { return nil }
        let prefix = room[room.startIndex..<dash]
        guard !prefix.isEmpty, prefix.allSatisfy({ $0.isNumber }) else { return nil }
        return "корпус \(prefix)"
    }

    /// «Капустин С.А.» → «КС»
    static func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let second = parts.count > 1 ? parts[1].first.map(String.init) ?? "" : ""
        return (first + second).uppercased()
    }
}

// MARK: - Компоненты экрана

private extension UIView {
    /// Обёртка, прижимающая view к левому краю в вертикальном стеке
    func leftAligned() -> UIView {
        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false
        translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: wrap.topAnchor),
            bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
            leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            trailingAnchor.constraint(lessThanOrEqualTo: wrap.trailingAnchor)
        ])
        return wrap
    }

    func centered() -> UIView {
        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false
        translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: wrap.topAnchor),
            bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
            centerXAnchor.constraint(equalTo: wrap.centerXAnchor)
        ])
        return wrap
    }
}

/// Пилюля группы/преподавателя в шапке
final class GroupPillButton: DSTapControl {
    private let glass = GlassView(interactive: true)

    init(who: String, isTeacher: Bool) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 44).isActive = true
        glass.isCapsule = true
        glass.isUserInteractionEnabled = false
        addSubview(glass)
        glass.pinEdges(to: self)

        let avatar: UIView
        if isTeacher {
            let circle = UILabel.ds(ScheduleTime.initials(who), font: DS.Font.display(12, .heavy), color: .white, alignment: .center)
            circle.backgroundColor = DS.Color.brand
            circle.layer.cornerRadius = 16
            circle.clipsToBounds = true
            circle.fixSize(width: 32, height: 32)
            avatar = circle
        } else {
            let logo = UIImageView(image: DS.Image.logo)
            logo.layer.cornerRadius = 9
            logo.clipsToBounds = true
            logo.fixSize(width: 32, height: 32)
            avatar = logo
        }
        let name = UILabel.ds(who, font: DS.Font.display(14, .semibold), kern: -0.14)
        name.lineBreakMode = .byTruncatingTail
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let chevron = UIImageView(image: DS.symbol("chevron.down", size: 11, weight: .bold))
        chevron.tintColor = DS.Color.fg
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView.ds(.horizontal, spacing: 8, alignment: .center, views: [avatar, name, chevron])
        row.isUserInteractionEnabled = false
        glass.contentView.addSubview(row)
        row.pinEdges(to: glass.contentView, insets: UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 12))
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// «Нед. 1» с зелёной точкой
final class ParityChip: DSTapControl {
    init(parity: Int) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 44).isActive = true
        let glass = GlassView(interactive: true)
        glass.isCapsule = true
        glass.isUserInteractionEnabled = false
        addSubview(glass)
        glass.pinEdges(to: self)
        let dot = UIView()
        dot.backgroundColor = DS.Color.green
        dot.layer.cornerRadius = 3.5
        dot.fixSize(width: 7, height: 7)
        let label = UILabel.ds("Нед. \(parity)", font: DS.Font.mono(12.5, .semibold))
        let row = UIStackView.ds(.horizontal, spacing: 7, alignment: .center, views: [dot, label])
        row.isUserInteractionEnabled = false
        glass.contentView.addSubview(row)
        row.pinEdges(to: glass.contentView, insets: UIEdgeInsets(top: 0, left: 11, bottom: 0, right: 11))
        accessibilityLabel = "Неделя \(parity)"
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Полоса дней недели
final class DayStripView: CardView {
    var onSelect: ((Int) -> Void)?

    init(days: [DaySchedule], selected: Int, today: Int, monday: Date = ScheduleTime.dateInCurrentWeek(0)) {
        super.init(radius: 20, shadow: .sm)
        let row = UIStackView.ds(.horizontal, spacing: 2)
        row.distribution = .fillEqually
        addSubview(row)
        row.pinEdges(to: self, insets: UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4))
        for i in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: i, to: monday) ?? monday
            let hasLessons = i < days.count && !ScheduleTime.realLessons(days[i]).isEmpty
            let item = DayStripItem(weekday: ScheduleTime.shortDays[i], number: ScheduleTime.dayNumber(date), selected: i == selected, isToday: i == today, isSunday: i == 6, hasLessons: hasLessons)
            item.accessibilityLabel = ScheduleTime.fullDays[i] + ", " + ScheduleTime.dayMonth(date)
            item.onTap = { [weak self] in
                UISelectionFeedbackGenerator().selectionChanged()
                self?.onSelect?(i)
            }
            row.addArrangedSubview(item)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class DayStripItem: DSTapControl {
    private let isSelectedDay: Bool

    init(weekday: String, number: String, selected: Bool, isToday: Bool, isSunday: Bool, hasLessons: Bool) {
        isSelectedDay = selected
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 56).isActive = true
        layer.cornerRadius = 16
        if selected {
            backgroundColor = DS.Color.brand
            layer.shadowColor = DS.Color.brand.cgColor
            layer.shadowOpacity = 0.32
            layer.shadowRadius = 7
            layer.shadowOffset = CGSize(width: 0, height: 4)
        }
        let color: UIColor = selected ? .white : (isSunday ? DS.Color.red : DS.Color.fg)
        let wk = UILabel.ds(weekday.uppercased(), font: DS.Font.text(10, .bold), color: color.withAlphaComponent(selected ? 0.85 : 0.55), kern: 0.6, alignment: .center)
        let num = UILabel.ds(number, font: DS.Font.display(17, .heavy), color: color, kern: -0.17, alignment: .center)
        let dot = UIView()
        dot.layer.cornerRadius = 2
        dot.fixSize(width: 4, height: 4)
        if isToday {
            dot.backgroundColor = selected ? .white : DS.Color.accent
        } else {
            dot.backgroundColor = hasLessons ? DS.Color.borderStrong : .clear
        }
        let col = UIStackView.ds(.vertical, spacing: 2, alignment: .center, views: [wk, num, dot])
        col.isUserInteractionEnabled = false
        addSubview(col)
        NSLayoutConstraint.activate([
            col.centerXAnchor.constraint(equalTo: centerXAnchor),
            col.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        accessibilityTraits = selected ? [.button, .selected] : .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Карточка «Сейчас идёт»
final class NowCardView: UIView {
    var onCopy: ((String) -> Void)?
    private let gradient = CAGradientLayer()
    private let circle = UIView()
    private let link: String?

    init(lesson: Lesson, isTeacher: Bool, nowMinutes: Int) {
        link = lesson.eiosLink?.isEmpty == false ? lesson.eiosLink : nil
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = DS.Radius.hero
        DS.Shadow.hero.apply(to: layer, traits: traitCollection)

        let clip = UIView()
        clip.layer.cornerRadius = DS.Radius.hero
        clip.clipsToBounds = true
        addSubview(clip)
        clip.pinEdges(to: self)
        gradient.colors = [DS.Color.brand.cgColor, DS.Color.brandMid.cgColor, DS.Color.brandSky.cgColor]
        gradient.locations = [0, 0.55, 1]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        clip.layer.addSublayer(gradient)
        circle.backgroundColor = UIColor(white: 1, alpha: 0.12)
        circle.layer.cornerRadius = 95
        clip.addSubview(circle)

        let span = ScheduleTime.span(lesson)
        let parts = ScheduleTime.who(for: lesson, isTeacher: isTeacher)

        // Левая колонка
        let pulse = UIView()
        pulse.backgroundColor = .white
        pulse.layer.cornerRadius = 3
        pulse.fixSize(width: 6, height: 6)
        Self.addPulse(to: pulse)
        let nowLabel = UILabel.ds("СЕЙЧАС", font: DS.Font.text(10, .bold), color: .white, kern: 0.9)
        let number = UILabel.ds("№\(lesson.number) · \(span.start)–\(span.end)", font: DS.Font.mono(11), color: UIColor(white: 1, alpha: 0.85))
        let top = UIStackView.ds(.horizontal, spacing: 6, alignment: .center, views: [pulse, nowLabel])
        let topRow = UIStackView.ds(.horizontal, spacing: 8, alignment: .center, views: [top, number])
        let subject = UILabel.ds(parts.subject, font: DS.Font.display(19, .heavy), color: .white, kern: -0.47, lines: 3, lineHeight: 23)
        let typeText = lesson.type.trimmingCharacters(in: .whitespaces)
        let meta = UILabel.ds([typeText, parts.who].filter { !$0.isEmpty }.joined(separator: " · "), font: DS.Font.text(13), color: UIColor(white: 1, alpha: 0.88), lines: 2)

        let track = UIView()
        track.backgroundColor = UIColor(white: 1, alpha: 0.28)
        track.layer.cornerRadius = 2
        track.clipsToBounds = true
        track.fixSize(height: 4)
        let fill = UIView()
        fill.backgroundColor = .white
        fill.layer.cornerRadius = 2
        fill.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(fill)
        let total = max(1, span.endMin - span.startMin)
        let progress = min(max(CGFloat(nowMinutes - span.startMin) / CGFloat(total), 0.02), 1)
        NSLayoutConstraint.activate([
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            fill.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: progress)
        ])

        let left = max(0, span.endMin - nowMinutes)
        let remain = UILabel.ds("осталось \(left) мин", font: DS.Font.mono(12, .semibold), color: .white)
        let bottom = UIStackView.ds(.horizontal, spacing: 8, alignment: .center, views: [remain])
        if link != nil {
            let spacer = UIView()
            bottom.addArrangedSubview(spacer)
            let button = DSButton("eios", style: .white, height: 32, fontSize: 12.5, icon: DS.symbol("link", size: 12, weight: .semibold))
            button.accessibilityLabel = "Скопировать ссылку eios"
            button.onTap = { [weak self] in
                guard let self = self, let link = self.link else { return }
                self.onCopy?(link)
            }
            bottom.addArrangedSubview(button)
        }

        let leftCol = UIStackView.ds(.vertical, spacing: 0, views: [topRow, subject, meta, track, bottom])
        leftCol.setCustomSpacing(8, after: topRow)
        leftCol.setCustomSpacing(4, after: subject)
        leftCol.setCustomSpacing(14, after: meta)
        leftCol.setCustomSpacing(12, after: track)

        // Правая колонка — аудитория
        let right = UIView()
        right.backgroundColor = UIColor(white: 1, alpha: 0.14)
        let rightBorder = UIView()
        rightBorder.backgroundColor = UIColor(white: 1, alpha: 0.22)
        rightBorder.translatesAutoresizingMaskIntoConstraints = false
        right.addSubview(rightBorder)
        let audLabel = UILabel.ds("АУД.", font: DS.Font.text(9, .bold), color: UIColor(white: 1, alpha: 0.8), kern: 0.8, alignment: .center)
        let room = UILabel.ds(lesson.room.isEmpty ? "—" : lesson.room, font: DS.Font.mono(17, .bold), color: .white, lines: 2, alignment: .center)
        room.adjustsFontSizeToFitWidth = true
        room.minimumScaleFactor = 0.6
        var rightViews: [UIView] = [audLabel, room]
        if let building = ScheduleTime.building(of: lesson.room) {
            rightViews.append(UILabel.ds(building, font: DS.Font.text(10.5), color: UIColor(white: 1, alpha: 0.75), alignment: .center))
        }
        let rightCol = UIStackView.ds(.vertical, spacing: 4, alignment: .center, views: rightViews)
        right.addSubview(rightCol)

        clip.addSubview(leftCol)
        clip.addSubview(right)
        right.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leftCol.topAnchor.constraint(equalTo: clip.topAnchor, constant: 16),
            leftCol.leadingAnchor.constraint(equalTo: clip.leadingAnchor, constant: 18),
            leftCol.bottomAnchor.constraint(equalTo: clip.bottomAnchor, constant: -16),
            leftCol.trailingAnchor.constraint(equalTo: right.leadingAnchor, constant: -14),

            right.topAnchor.constraint(equalTo: clip.topAnchor),
            right.bottomAnchor.constraint(equalTo: clip.bottomAnchor),
            right.trailingAnchor.constraint(equalTo: clip.trailingAnchor),
            right.widthAnchor.constraint(equalToConstant: 84),

            rightBorder.leadingAnchor.constraint(equalTo: right.leadingAnchor),
            rightBorder.topAnchor.constraint(equalTo: right.topAnchor),
            rightBorder.bottomAnchor.constraint(equalTo: right.bottomAnchor),
            rightBorder.widthAnchor.constraint(equalToConstant: 1),

            rightCol.centerYAnchor.constraint(equalTo: right.centerYAnchor),
            rightCol.leadingAnchor.constraint(equalTo: right.leadingAnchor, constant: 4),
            rightCol.trailingAnchor.constraint(equalTo: right.trailingAnchor, constant: -4)
        ])
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        // top: -60px; right: 40px, 190×190
        circle.frame = CGRect(x: bounds.width - 40 - 190, y: -60, width: 190, height: 190)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: DS.Radius.hero).cgPath
    }

    private static func addPulse(to view: UIView) {
        let ring = CALayer()
        ring.frame = CGRect(x: -0.5, y: -0.5, width: 7, height: 7)
        ring.cornerRadius = 3.5
        ring.borderColor = UIColor(white: 1, alpha: 0.6).cgColor
        ring.borderWidth = 1.5
        view.layer.addSublayer(ring)
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1
        scale.toValue = 2.6
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 1.8
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        ring.add(group, forKey: "pulse")
    }
}

/// Карточка пары в списке дня
final class LessonCardView: UIView {
    var onCopy: ((String) -> Void)?
    private let link: String?

    init(lesson: Lesson, isTeacher: Bool) {
        link = lesson.eiosLink?.isEmpty == false ? lesson.eiosLink : nil
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let card = ClippedCardView(radius: DS.Radius.card, shadow: .xs)
        addSubview(card)
        card.pinEdges(to: self)
        let content = card.content
        let kind = DS.LessonKind.of(lesson.type)
        let span = ScheduleTime.span(lesson)
        let parts = ScheduleTime.who(for: lesson, isTeacher: isTeacher)

        let stripe = UIView()
        stripe.backgroundColor = kind.stripe
        stripe.layer.cornerRadius = 2
        stripe.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stripe)

        let number = UILabel.ds(lesson.number > 0 ? "\(lesson.number)" : "·", font: DS.Font.mono(10.5, .bold), alignment: .center)
        number.backgroundColor = DS.Color.soft2
        number.layer.cornerRadius = 11
        number.layer.borderWidth = 1
        number.layer.borderColor = DS.Color.borderStrong.resolvedColor(with: traitCollection).cgColor
        number.clipsToBounds = true
        number.fixSize(width: 22, height: 22)
        self.numberLabel = number
        let time = UILabel.ds(span.start.isEmpty ? lesson.time : "\(span.start)–\(span.end)", font: DS.Font.mono(11.5), color: DS.Color.muted)
        let topRow = UIStackView.ds(.horizontal, spacing: 8, alignment: .center, views: [number, time, UIView()])
        let typeText = lesson.type.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typeText.isEmpty {
            topRow.addArrangedSubview(LessonChip(text: typeText, kind: kind))
        }

        let subject = UILabel.ds(parts.subject, font: DS.Font.display(15, .bold), kern: -0.15, lines: 2, lineHeight: 19.5)

        var bottomViews: [UIView] = []
        if !parts.who.isEmpty {
            let icon = UIImageView(image: DS.symbol(isTeacher ? "person.2" : "person", size: 11, weight: .semibold))
            icon.tintColor = DS.Color.soft
            icon.setContentHuggingPriority(.required, for: .horizontal)
            let whoLabel = UILabel.ds(parts.who, font: DS.Font.text(12.5), color: DS.Color.soft)
            whoLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            bottomViews += [icon, whoLabel]
        }
        bottomViews.append(UIView())
        if link != nil {
            let eios = DSTapControl()
            let eiosRow = UIStackView.ds(.horizontal, spacing: 4, alignment: .center, views: [
                UIImageView(image: DS.symbol("link", size: 10, weight: .bold)),
                UILabel.ds("eios", font: DS.Font.text(12, .semibold), color: DS.Color.accent)
            ])
            (eiosRow.arrangedSubviews.first as? UIImageView)?.tintColor = DS.Color.accent
            eiosRow.isUserInteractionEnabled = false
            eios.addSubview(eiosRow)
            eiosRow.pinEdges(to: eios, insets: UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 0))
            eios.accessibilityLabel = "Скопировать ссылку eios"
            eios.onTap = { [weak self] in
                guard let self = self, let link = self.link else { return }
                self.onCopy?(link)
            }
            eios.setContentHuggingPriority(.required, for: .horizontal)
            bottomViews.append(eios)
        }
        let bottomRow = UIStackView.ds(.horizontal, spacing: 6, alignment: .center, views: bottomViews)

        let col = UIStackView.ds(.vertical, spacing: 4, views: [topRow, subject, bottomRow])
        content.addSubview(col)

        let roomBox = UIView()
        roomBox.backgroundColor = DS.Color.sunk
        roomBox.translatesAutoresizingMaskIntoConstraints = false
        let roomBorder = UIView()
        roomBorder.backgroundColor = DS.Color.border
        roomBorder.translatesAutoresizingMaskIntoConstraints = false
        roomBox.addSubview(roomBorder)
        let aud = UILabel.ds("АУД.", font: DS.Font.text(9, .bold), color: DS.Color.faint, kern: 0.8, alignment: .center)
        let room = UILabel.ds(lesson.room.isEmpty ? "—" : lesson.room, font: DS.Font.mono(13.5, .bold), lines: 2, lineHeight: 15.5, alignment: .center)
        room.adjustsFontSizeToFitWidth = true
        room.minimumScaleFactor = 0.7
        let roomCol = UIStackView.ds(.vertical, spacing: 3, alignment: .center, views: [aud, room])
        roomBox.addSubview(roomCol)
        content.addSubview(roomBox)

        NSLayoutConstraint.activate([
            stripe.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 6),
            stripe.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            stripe.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            stripe.widthAnchor.constraint(equalToConstant: 4),

            col.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            col.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            col.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            col.trailingAnchor.constraint(equalTo: roomBox.leadingAnchor, constant: -12),

            roomBox.topAnchor.constraint(equalTo: content.topAnchor),
            roomBox.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            roomBox.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            roomBox.widthAnchor.constraint(equalToConstant: 72),

            roomBorder.leadingAnchor.constraint(equalTo: roomBox.leadingAnchor),
            roomBorder.topAnchor.constraint(equalTo: roomBox.topAnchor),
            roomBorder.bottomAnchor.constraint(equalTo: roomBox.bottomAnchor),
            roomBorder.widthAnchor.constraint(equalToConstant: 1),

            roomCol.centerYAnchor.constraint(equalTo: roomBox.centerYAnchor),
            roomCol.leadingAnchor.constraint(equalTo: roomBox.leadingAnchor, constant: 4),
            roomCol.trailingAnchor.constraint(equalTo: roomBox.trailingAnchor, constant: -4)
        ])
    }

    private weak var numberLabel: UILabel?

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        numberLabel?.layer.borderColor = DS.Color.borderStrong.resolvedColor(with: traitCollection).cgColor
    }
}

/// Чип типа занятия
final class LessonChip: UIView {
    init(text: String, kind: DS.LessonKind, fontSize: CGFloat = 10.5, horizontal: CGFloat = 8, vertical: CGFloat = 2) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = kind.chipBg
        let label = UILabel.ds(text, font: DS.Font.text(fontSize, .semibold), color: kind.chipFg)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        addSubview(label)
        label.pinEdges(to: self, insets: UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal))
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}

/// Перемена между парами: пунктир — текст — пунктир
final class BreakRow: UIView {
    private let leftLine = CAShapeLayer()
    private let rightLine = CAShapeLayer()
    private let label: UILabel

    init(text: String) {
        label = UILabel.ds(text, font: DS.Font.mono(10.5), color: DS.Color.faint, alignment: .center)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 20).isActive = true
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        [leftLine, rightLine].forEach {
            $0.lineDashPattern = [3, 3]
            $0.lineWidth = 1
            $0.fillColor = UIColor.clear.cgColor
            layer.addSublayer($0)
        }
        applyTraits()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let y = bounds.midY
        let l = UIBezierPath()
        l.move(to: CGPoint(x: 6, y: y))
        l.addLine(to: CGPoint(x: label.frame.minX - 10, y: y))
        leftLine.path = l.cgPath
        let r = UIBezierPath()
        r.move(to: CGPoint(x: label.frame.maxX + 10, y: y))
        r.addLine(to: CGPoint(x: bounds.width - 6, y: y))
        rightLine.path = r.cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTraits()
    }

    private func applyTraits() {
        let color = DS.Color.borderStrong.resolvedColor(with: traitCollection).cgColor
        leftLine.strokeColor = color
        rightLine.strokeColor = color
    }
}

/// Плашка «Нет подключения»
final class OfflineBanner: UIView {
    init(onRetry: @escaping () -> Void) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let card = ClippedCardView(radius: DS.Radius.card, shadow: .sm)
        addSubview(card)
        card.pinEdges(to: self)

        let icon = IconBadge(symbol: "icloud.slash", size: 32, pointSize: 15, tint: DS.Color.amberFg, fill: UIColor(rgb: 0xF59E0B, alpha: 0.14))
        let title = UILabel.ds("Нет подключения", font: DS.Font.text(14, .semibold))
        let text = UILabel.ds("Показываем сохранённое расписание. Изменения подтянем, когда появится сеть.", font: DS.Font.text(13), color: DS.Color.soft, lines: 0, lineHeight: 19)
        let texts = UIStackView.ds(.vertical, spacing: 2, views: [title, text])
        let top = UIStackView.ds(.horizontal, spacing: 12, alignment: .top, views: [icon, texts])

        let footer = UIView()
        footer.backgroundColor = DS.Color.soft2
        let line = UIView()
        line.backgroundColor = DS.Color.border
        line.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(line)
        let caption = UILabel.ds("Сохранено на устройстве", font: DS.Font.mono(11), color: DS.Color.faint)
        let retry = DSButton("Повторить", style: .outlineAccent, height: 30, fontSize: 12.5)
        retry.onTap = onRetry
        let footerRow = UIStackView.ds(.horizontal, spacing: 8, alignment: .center, views: [caption, UIView(), retry])
        footer.addSubview(footerRow)
        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: footer.topAnchor),
            line.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            line.heightAnchor.constraint(equalToConstant: 1)
        ])
        footerRow.pinEdges(to: footer, insets: UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14))

        let topWrap = UIView()
        topWrap.addSubview(top)
        top.pinEdges(to: topWrap, insets: UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14))
        let col = UIStackView.ds(.vertical, views: [topWrap, footer])
        card.content.addSubview(col)
        col.pinEdges(to: card.content)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Пульсирующая заглушка загрузки
enum SkeletonView {
    static func block(height: CGFloat, radius: CGFloat) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = DS.Color.sunk
        v.layer.cornerRadius = radius
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 0.55
        anim.toValue = 1
        anim.duration = 0.7
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        v.layer.add(anim, forKey: "sk")
        return v
    }
}

/// Распределение пар недели по типам
final class MixCard: CardView {
    init(lessons: [Lesson]) {
        super.init(radius: DS.Radius.card, shadow: .sm)
        let buckets: [(String, UIColor)] = [("Лекции", DS.Color.accent), ("Практики", DS.Color.green), ("Лабораторные", DS.Color.amber), ("Экзамены и зачёты", DS.Color.red)]
        var counts = [0, 0, 0, 0]
        lessons.forEach { counts[DS.LessonKind.bucket($0.type)] += 1 }
        let items = buckets.enumerated().filter { counts[$0.offset] > 0 }.map { (label: $0.element.0, color: $0.element.1, n: counts[$0.offset]) }

        let bar = UIStackView.ds(.horizontal, spacing: 2)
        bar.layer.cornerRadius = 4
        bar.clipsToBounds = true
        bar.fixSize(height: 8)
        var first: UIView?
        for item in items {
            let seg = UIView()
            seg.backgroundColor = item.color
            seg.translatesAutoresizingMaskIntoConstraints = false
            bar.addArrangedSubview(seg)
            if let first = first, let firstItem = items.first {
                seg.widthAnchor.constraint(equalTo: first.widthAnchor, multiplier: CGFloat(item.n) / CGFloat(firstItem.n)).isActive = true
            } else {
                first = seg
            }
        }

        let grid = UIStackView.ds(.vertical, spacing: 6)
        var row: UIStackView?
        for (i, item) in items.enumerated() {
            if i % 2 == 0 {
                row = UIStackView.ds(.horizontal, spacing: 12)
                row?.distribution = .fillEqually
                grid.addArrangedSubview(row!)
            }
            let dot = UIView()
            dot.backgroundColor = item.color
            dot.layer.cornerRadius = 4
            dot.fixSize(width: 8, height: 8)
            let label = UILabel.ds(item.label, font: DS.Font.text(12.5), color: DS.Color.muted)
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.8
            let n = UILabel.ds("\(item.n)", font: DS.Font.mono(11.5), color: DS.Color.faint)
            n.setContentHuggingPriority(.required, for: .horizontal)
            let cell = UIStackView.ds(.horizontal, spacing: 7, alignment: .center, views: [dot, label, n])
            row?.addArrangedSubview(cell)
        }
        if items.count % 2 == 1 { row?.addArrangedSubview(UIView()) }

        let col = UIStackView.ds(.vertical, spacing: 10, views: [bar, grid])
        addSubview(col)
        col.pinEdges(to: self, insets: UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// День в списке недели
final class WeekDaySection: UIView {
    init(name: String, date: String, lessons: [Lesson], isToday: Bool, isTeacher: Bool, nowMinutes: Int?) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel.display(name, size: 17, weight: .bold, lines: 1)
        let dateLabel = UILabel.ds(date, font: DS.Font.mono(11.5), color: DS.Color.faint)
        let headerRow = UIStackView.ds(.horizontal, spacing: 8, alignment: .center, views: [nameLabel, dateLabel, UIView()])
        if isToday {
            headerRow.addArrangedSubview(EyebrowPill("Сегодня", size: 10, tint: .white, fill: DS.Color.brand, showsDot: false))
        } else if !lessons.isEmpty {
            headerRow.addArrangedSubview(UILabel.ds("\(lessons.count) \(dsPlural(lessons.count, "пара", "пары", "пар"))", font: DS.Font.text(12), color: DS.Color.faint))
        }
        let headerWrap = UIView()
        headerWrap.addSubview(headerRow)
        headerRow.pinEdges(to: headerWrap, insets: UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 2))

        let body: UIView
        if lessons.isEmpty {
            let empty = CardView(radius: DS.Radius.card, shadow: .none)
            empty.fill = .clear
            empty.dashed = true
            empty.borderColor = DS.Color.borderStrong
            let moon = UIImageView(image: DS.symbol("moon", size: 15, weight: .medium))
            moon.tintColor = DS.Color.soft
            moon.contentMode = .center
            moon.fixSize(width: 18, height: 18)
            let row = UIStackView.ds(.horizontal, spacing: 10, alignment: .center, views: [moon, UILabel.ds("Выходной", font: DS.Font.text(13.5), color: DS.Color.soft)])
            empty.addSubview(row)
            row.pinEdges(to: empty, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
            body = empty
        } else {
            let card = ClippedCardView(radius: DS.Radius.card, shadow: .xs)
            if isToday {
                card.card.borderColor = DS.Color.accentBorder
                card.card.layer.shadowColor = DS.Color.brand.cgColor
                card.card.layer.shadowOpacity = 0.12
                card.card.layer.shadowRadius = 3
                card.card.layer.shadowOffset = .zero
            }
            let rows = UIStackView.ds(.vertical)
            for (j, lesson) in lessons.enumerated() {
                let span = ScheduleTime.span(lesson)
                let isNow = nowMinutes.map { span.startMin <= $0 && $0 < span.endMin } ?? false
                rows.addArrangedSubview(WeekLessonRow(lesson: lesson, isTeacher: isTeacher, isNow: isNow, showsTopBorder: j > 0))
            }
            card.content.addSubview(rows)
            rows.pinEdges(to: card.content)
            body = card
        }

        let col = UIStackView.ds(.vertical, spacing: 10, views: [headerWrap, body])
        addSubview(col)
        col.pinEdges(to: self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class WeekLessonRow: UIView {
    init(lesson: Lesson, isTeacher: Bool, isNow: Bool, showsTopBorder: Bool) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = isNow ? DS.Color.accentSoft : .clear
        let kind = DS.LessonKind.of(lesson.type)
        let span = ScheduleTime.span(lesson)
        let parts = ScheduleTime.who(for: lesson, isTeacher: isTeacher)

        if showsTopBorder {
            let line = UIView()
            line.backgroundColor = DS.Color.border
            line.translatesAutoresizingMaskIntoConstraints = false
            addSubview(line)
            NSLayoutConstraint.activate([
                line.topAnchor.constraint(equalTo: topAnchor),
                line.leadingAnchor.constraint(equalTo: leadingAnchor),
                line.trailingAnchor.constraint(equalTo: trailingAnchor),
                line.heightAnchor.constraint(equalToConstant: 1)
            ])
        }
        let stripe = UIView()
        stripe.backgroundColor = kind.stripe
        stripe.layer.cornerRadius = 1.5
        stripe.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        stripe.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stripe)

        let start = UILabel.ds(span.start, font: DS.Font.mono(12, .semibold))
        let end = UILabel.ds(span.end, font: DS.Font.mono(12), color: DS.Color.faint)
        let timeCol = UIStackView.ds(.vertical, spacing: 1, views: [start, end])
        timeCol.widthAnchor.constraint(equalToConstant: 50).isActive = true

        let subject = UILabel.ds(parts.subject, font: DS.Font.text(14, .semibold))
        var metaViews: [UIView] = []
        let typeText = lesson.type.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typeText.isEmpty { metaViews.append(LessonChip(text: typeText, kind: kind, horizontal: 7, vertical: 1)) }
        let who = UILabel.ds(parts.who, font: DS.Font.text(12), color: DS.Color.soft)
        who.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        metaViews.append(who)
        let metaRow = UIStackView.ds(.horizontal, spacing: 6, alignment: .center, views: metaViews)
        let middle = UIStackView.ds(.vertical, spacing: 2, views: [subject, metaRow])
        middle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let room = UILabel.ds(lesson.room.isEmpty ? "—" : lesson.room, font: DS.Font.mono(12, .bold), alignment: .center)
        let roomTag = CardView(radius: 6, shadow: .none)
        roomTag.fill = DS.Color.sunk
        roomTag.addSubview(room)
        room.pinEdges(to: roomTag, insets: UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
        var rightViews: [UIView] = [roomTag]
        if isNow { rightViews.append(UILabel.eyebrow("сейчас", size: 9, color: DS.Color.accent)) }
        let right = UIStackView.ds(.vertical, spacing: 3, alignment: .trailing, views: rightViews)
        right.setContentHuggingPriority(.required, for: .horizontal)
        right.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView.ds(.horizontal, spacing: 12, alignment: .center, views: [timeCol, middle, right])
        addSubview(row)
        row.pinEdges(to: self, insets: UIEdgeInsets(top: 11, left: 16, bottom: 11, right: 14))
        NSLayoutConstraint.activate([
            stripe.leadingAnchor.constraint(equalTo: leadingAnchor),
            stripe.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stripe.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            stripe.widthAnchor.constraint(equalToConstant: 3)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Лента дней сессии
final class SessionRibbonView: UIView {
    var onSelect: ((String) -> Void)?
    private let scroll = UIScrollView()
    private var selectedView: UIView?

    init(days: [DaySchedule], selectedISO: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 82).isActive = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.clipsToBounds = false
        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -DS.Inset.side),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: DS.Inset.side)
        ])
        let row = UIStackView.ds(.horizontal, spacing: 6, alignment: .center)
        scroll.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 2),
            row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -4),
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: DS.Inset.side),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -DS.Inset.side),
            row.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor, constant: -6)
        ])

        // Диапазон: от первой до последней даты с данными (как в прежней шапке заочки)
        var counts: [String: Int] = [:]
        days.forEach { if let iso = $0.isoDate { counts[iso] = ScheduleTime.realLessons($0).count } }
        let sorted = counts.keys.sorted()
        guard let firstISO = sorted.first, let lastISO = sorted.last,
              let first = ScheduleTime.iso.date(from: firstISO), let last = ScheduleTime.iso.date(from: lastISO) else { return }
        let todayISO = ScheduleTime.iso.string(from: Date())
        var d = Calendar.current.startOfDay(for: first)
        let end = Calendar.current.startOfDay(for: last)
        while d <= end {
            let iso = ScheduleTime.iso.string(from: d)
            let count = counts[iso] ?? 0
            let chip = SessionDayChip(date: d, count: count, selected: iso == selectedISO, isToday: iso == todayISO)
            chip.onTap = { [weak self] in
                UISelectionFeedbackGenerator().selectionChanged()
                self?.onSelect?(iso)
            }
            row.addArrangedSubview(chip)
            if iso == selectedISO { selectedView = chip }
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var didCenter = false
    override func layoutSubviews() {
        super.layoutSubviews()
        guard !didCenter, let selected = selectedView, scroll.bounds.width > 0 else { return }
        didCenter = true
        scroll.layoutIfNeeded()
        let frame = selected.convert(selected.bounds, to: scroll)
        let maxX = max(0, scroll.contentSize.width - scroll.bounds.width)
        scroll.contentOffset.x = min(max(0, frame.midX - scroll.bounds.width / 2), maxX)
    }
}

private final class SessionDayChip: DSTapControl {
    private let card = CardView(radius: 16, shadow: .none)
    private let selectedDay: Bool
    private let hasData: Bool

    init(date: Date, count: Int, selected: Bool, isToday: Bool) {
        selectedDay = selected
        hasData = count > 0
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        fixSize(width: 56, height: 76)
        card.isUserInteractionEnabled = false
        addSubview(card)
        card.pinEdges(to: self)

        let fg: UIColor
        if selected {
            card.fill = DS.Color.brand
            card.borderColor = nil
            DS.Shadow.primary.apply(to: card.layer, traits: traitCollection)
            fg = .white
        } else if count == 0 {
            card.fill = .clear
            card.dashed = true
            card.borderColor = DS.Color.borderStrong
            fg = DS.Color.soft
        } else {
            card.fill = DS.Color.surface
            card.borderColor = isToday ? DS.Color.accent : DS.Color.border
            fg = DS.Color.fg
        }
        let wkIndex = ScheduleTime.weekdayIndex(of: date)
        let wk = UILabel.ds(ScheduleTime.shortDays[wkIndex].uppercased(), font: DS.Font.text(10, .bold), color: fg.withAlphaComponent(0.7), kern: 0.6, alignment: .center)
        let num = UILabel.ds(ScheduleTime.dayNumber(date), font: DS.Font.display(20, .heavy), color: fg, alignment: .center)
        let mon = UILabel.ds(ScheduleTime.dayShortMonth(date).components(separatedBy: " ").last ?? "", font: DS.Font.text(10), color: fg.withAlphaComponent(0.7), alignment: .center)
        let dots = UIStackView.ds(.horizontal, spacing: 2, alignment: .center)
        dots.heightAnchor.constraint(equalToConstant: 4).isActive = true
        for _ in 0..<min(count, 4) {
            let dot = UIView()
            dot.backgroundColor = fg.withAlphaComponent(0.75)
            dot.layer.cornerRadius = 2
            dot.fixSize(width: 4, height: 4)
            dots.addArrangedSubview(dot)
        }
        let col = UIStackView.ds(.vertical, spacing: 1, alignment: .center, views: [wk, num, mon, dots])
        col.setCustomSpacing(3, after: mon)
        col.isUserInteractionEnabled = false
        addSubview(col)
        NSLayoutConstraint.activate([
            col.centerXAnchor.constraint(equalTo: centerXAnchor),
            col.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        accessibilityLabel = ScheduleTime.weekdayName(date) + ", " + ScheduleTime.dayMonth(date) + (count == 0 ? ", занятий нет" : ", \(count) \(dsPlural(count, "пара", "пары", "пар"))")
        accessibilityTraits = selected ? [.button, .selected] : .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
