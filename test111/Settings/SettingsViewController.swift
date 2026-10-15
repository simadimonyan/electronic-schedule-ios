//
//  SettingsViewController.swift
//  raspisanie1
//
//  Created by Дмитрий Цепилов on 01.12.2024.
//

import UIKit
import MyTrackerSDK

class SettingsViewController: UIViewController {

    /// Открыть выбор группы/преподавателя (кнопка «Сменить» в карточке профиля)
    var onOpenSelection: (() -> Void)?

    // Скролл-контейнер для всех настроек
    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsVerticalScrollIndicator = false
        scroll.alwaysBounceVertical = true
        scroll.contentInsetAdjustmentBehavior = .never
        return scroll
    }()

    private let backdrop = BackdropView()
    private let stack = UIStackView.ds(.vertical)
    private var stackTop: NSLayoutConstraint!
    private let backButton = GlassIconButton(symbol: "chevron.left")

    let showFullScheduleSwitch = UISwitch()
    let removeGroupSelectionSwitch = UISwitch()
    let notificationsSwitch = UISwitch()
    let syncWeekSwitch = UISwitch()
    let changeWeekSegmentedControl = DSSegmentedControl(items: ["1", "2"], mono: true)
    let modeSegmentedControl = DSSegmentedControl(items: ["Студент", "Преподаватель"])

    private var showFullScheduleRow: DSListRow!
    private var changeWeekRow: DSListRow!
    private var notificationTimeRow: DSListRow!
    private let notificationTimeStepper = MinutesStepper()
    private let profileCard = UIView()
    private var themeCards: [ThemeCard] = []
    private let footerLabel = UILabel()

    private var isPushed: Bool {
        guard let nav = navigationController else { return false }
        return nav.viewControllers.count > 1 && nav.viewControllers.last === self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.Color.bg

        view.addSubview(backdrop)
        backdrop.showsGrid = false
        backdrop.showsSky = false
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.heightAnchor.constraint(equalToConstant: 300)
        ])

        view.addSubview(scrollView)
        scrollView.pinEdges(to: view)
        scrollView.addSubview(stack)
        stackTop = stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 66)
        NSLayoutConstraint.activate([
            stackTop,
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: DS.Inset.side),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -DS.Inset.side),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -DS.Inset.bottomForNav)
        ])

        backButton.accessibilityLabel = "Назад"
        backButton.onTap = { [weak self] in self?.backButtonTapped() }
        view.addSubview(backButton)
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DS.Inset.side)
        ])
        backButton.isHidden = true

        [showFullScheduleSwitch, removeGroupSelectionSwitch, notificationsSwitch, syncWeekSwitch].forEach {
            $0.onTintColor = DS.Color.brand
        }
        showFullScheduleSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        removeGroupSelectionSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        notificationsSwitch.addTarget(self, action: #selector(notificationsSwitchChanged), for: .valueChanged)
        syncWeekSwitch.addTarget(self, action: #selector(syncWeekSwitchChanged), for: .valueChanged)
        changeWeekSegmentedControl.addTarget(self, action: #selector(changeWeek), for: .valueChanged)
        modeSegmentedControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        notificationTimeStepper.onChange = { [weak self] minutes in self?.notificationTimeChanged(minutes) }

        buildContent()

        // Загрузка состояния переключателей из UserDefaults
        let isFullScheduleEnabled = UserDefaults.standard.bool(forKey: "showFullSchedule")
        showFullScheduleSwitch.isOn = isFullScheduleEnabled

        applyCorrespondenceFullWeekAvailability()

        let isGroupSelectionRemoved = UserDefaults.standard.bool(forKey: "removeGroupSelection")
        removeGroupSelectionSwitch.isOn = isGroupSelectionRemoved

        // Загрузка настроек уведомлений
        let notificationManager = NotificationManager.shared
        notificationsSwitch.isOn = notificationManager.isNotificationsEnabled
        notificationTimeStepper.minutes = notificationManager.notificationTimeMinutes
        updateNotificationTimeVisibility(animated: false)

        // Отладочная информация
        notificationManager.debugNotifications()
        notificationManager.checkNotificationPermissions { _ in }

        // Загрузка настройки синхронизации недели
        let isSyncEnabled = UserDefaults.standard.bool(forKey: "syncWeekEnabled")
        syncWeekSwitch.isOn = isSyncEnabled
        changeWeekSegmentedControl.selectedIndex = UserDefaults.standard.bool(forKey: "isOddWeek") ? 0 : 1
        modeSegmentedControl.selectedIndex = UserDefaults.standard.bool(forKey: "isTeacherMode") ? 1 : 0
        applySyncWeekUIState(isEnabled: isSyncEnabled)
        if isSyncEnabled {
            syncWeekWithServer(applyOnlyUI: false)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(selectionDidChange), name: Notification.Name("reloadSchedule"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(selectionDidChange), name: Notification.Name("modeChanged"), object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Актуализируем доступность "Показать всю неделю" при каждом открытии настроек.
        applyCorrespondenceFullWeekAvailability()
        refreshProfileCard()
        modeSegmentedControl.selectedIndex = UserDefaults.standard.bool(forKey: "isTeacherMode") ? 1 : 0
        changeWeekSegmentedControl.selectedIndex = UserDefaults.standard.bool(forKey: "isOddWeek") ? 0 : 1
        refreshThemeCards()
        backButton.isHidden = !isPushed
        if isPushed {
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }
        let top = max(view.safeAreaInsets.top, 20)
        stackTop.constant = isPushed ? top + 60 : top + 12
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        let top = max(view.safeAreaInsets.top, 20)
        stackTop.constant = isPushed ? top + 60 : top + 12
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        #if DEBUG
        // Демонстрация опросов: прокрутить к «Оставить отзыв»
        if SurveysDebug.openSettings, let row = feedbackRow {
            let rect = row.convert(row.bounds, to: scrollView).insetBy(dx: 0, dy: -20)
            scrollView.scrollRectToVisible(rect, animated: true)
        }
        #endif
    }

    private var feedbackRow: DSListRow?

    // MARK: - Вёрстка

    private func buildContent() {
        stack.addArrangedSubview(UILabel.display("Настройки", size: 36))
        stack.setCustomSpacing(16, after: stack.arrangedSubviews.last!)

        // Карточка «Моё расписание»
        stack.addArrangedSubview(profileCard)
        refreshProfileCard()

        // Режим приложения
        addSection("Режим приложения", rows: [
            accessoryRow(symbol: "person", title: "Я", accessory: modeSegmentedControl)
        ])

        // Расписание
        let syncRow = accessoryRow(symbol: "arrow.triangle.2.circlepath", title: "Определять неделю", subtitle: "Чётность приходит с сервера ИМСИТ", accessory: syncWeekSwitch)
        changeWeekRow = accessoryRow(symbol: "calendar", title: "Текущая неделя", accessory: changeWeekSegmentedControl)
        showFullScheduleRow = accessoryRow(symbol: "tablecells", title: "Открывать сразу неделю", subtitle: "Вместо экрана «Сегодня»", accessory: showFullScheduleSwitch)
        let removeRow = accessoryRow(symbol: "magnifyingglass", title: "Убрать выбор группы", subtitle: "Скрыть поиск группы в нижней панели", accessory: removeGroupSelectionSwitch)
        addSection("Расписание", rows: [syncRow, changeWeekRow, showFullScheduleRow, removeRow])

        // Уведомления
        let notificationsRow = accessoryRow(symbol: "bell", title: "Уведомления о парах", accessory: notificationsSwitch)
        notificationTimeRow = accessoryRow(symbol: "clock", title: "Напоминать за", accessory: notificationTimeStepper)
        addSection("Уведомления", rows: [notificationsRow, notificationTimeRow])

        // Ещё
        let widgetsRow = DSListRow(symbol: "square.grid.2x2", title: "Виджеты", value: "2 размера", chevron: true)
        widgetsRow.onTap = { [weak self] in self?.showWidgets() }
        let feedback = DSListRow(symbol: "bubble.left.and.bubble.right", title: "Оставить отзыв", chevron: true)
        feedback.onTap = { [weak self] in self?.showFeedback() }
        feedbackRow = feedback
        let telegramRow = DSListRow(symbol: "paperplane", title: "Telegram-канал", externalLink: true)
        telegramRow.onTap = { [weak self] in self?.openTelegram() }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let aboutRow = DSListRow(symbol: "info.circle", title: "О приложении", value: version.isEmpty ? nil : "v" + version, chevron: true)
        aboutRow.onTap = { [weak self] in self?.showAbout() }
        addSection("Ещё", rows: [widgetsRow, feedback, telegramRow, aboutRow])

        // Оформление
        addTitle("Оформление")
        let themes = UIStackView.ds(.horizontal, spacing: 8)
        themes.distribution = .fillEqually
        for theme in [AppTheme.light, .dark, .system] {
            let card = ThemeCard(theme: theme)
            card.onTap = { [weak self] in self?.themeTapped(theme) }
            themeCards.append(card)
            themes.addArrangedSubview(card)
        }
        stack.addArrangedSubview(themes)
        refreshThemeCards()

        // Подвал
        footerLabel.numberOfLines = 0
        let text = NSMutableAttributedString(attributedString: .ds("По всем проблемам и предложениям пишите разработчику ", font: DS.Font.text(12), color: DS.Color.faint, lineHeight: 18, alignment: .center))
        text.append(.ds("@tsep1lov", font: DS.Font.text(12, .semibold), color: DS.Color.accent, lineHeight: 18, alignment: .center))
        text.append(.ds("\nМоя Академия " + (version.isEmpty ? "" : version + " ") + "· Академия ИМСИТ", font: DS.Font.text(12), color: DS.Color.faint, lineHeight: 18, alignment: .center))
        footerLabel.attributedText = text
        stack.setCustomSpacing(20, after: themes)
        stack.addArrangedSubview(footerLabel)
    }

    private func addTitle(_ title: String) {
        let caption = dsSectionTitle(title)
        if let last = stack.arrangedSubviews.last { stack.setCustomSpacing(24, after: last) }
        stack.addArrangedSubview(caption)
        stack.setCustomSpacing(8, after: caption)
    }

    private func addSection(_ title: String, rows: [DSListRow]) {
        addTitle(title)
        stack.addArrangedSubview(DSListGroup(rows: rows))
    }

    private func accessoryRow(symbol: String, title: String, subtitle: String? = nil, accessory: UIView) -> DSListRow {
        let row = DSListRow(symbol: symbol, title: title, subtitle: subtitle)
        row.setAccessory(accessory)
        return row
    }

    private func refreshProfileCard() {
        profileCard.subviews.forEach { $0.removeFromSuperview() }
        let defaults = UserDefaults.standard
        let isTeacher = defaults.bool(forKey: "isTeacherMode")
        let name = isTeacher ? (defaults.string(forKey: "selectedTeacherURL") ?? "") : (defaults.string(forKey: "selectedGroupURL") ?? "")
        let sub: String
        if isTeacher {
            sub = "Преподаватель"
        } else {
            sub = [defaults.string(forKey: "selectedGroupLevel"), defaults.string(forKey: "selectedCourse")]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        }

        let card = CardView(radius: DS.Radius.hero, shadow: .sm)
        let avatar = UIImageView(image: UIImage(named: isTeacher ? "IlloTeacher" : "IlloWelcome"))
        avatar.contentMode = .scaleAspectFill
        avatar.backgroundColor = DS.Color.accentSoft
        avatar.layer.cornerRadius = 28
        avatar.clipsToBounds = true
        avatar.fixSize(width: 56, height: 56)
        let eyebrow = UILabel.eyebrow("Моё расписание", size: 9.5)
        let title = UILabel.ds(name.isEmpty ? (isTeacher ? "Преподаватель не выбран" : "Группа не выбрана") : name, font: DS.Font.display(18, .heavy), kern: -0.45, lines: 2)
        var texts: [UIView] = [eyebrow, title]
        if !sub.isEmpty { texts.append(UILabel.ds(sub, font: DS.Font.text(12.5), color: DS.Color.soft, lines: 2)) }
        let col = UIStackView.ds(.vertical, spacing: 2, views: texts)
        col.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        var rowViews: [UIView] = [avatar, col]
        let locked = UserDefaults.standard.bool(forKey: "removeGroupSelection") && !isTeacher && !name.isEmpty
        if onOpenSelection != nil && !locked {
            let change = DSButton(name.isEmpty ? "Выбрать" : "Сменить", style: .outlineAccent, height: 32, fontSize: 12.5)
            change.setContentHuggingPriority(.required, for: .horizontal)
            change.setContentCompressionResistancePriority(.required, for: .horizontal)
            change.onTap = { [weak self] in self?.onOpenSelection?() }
            rowViews.append(change)
        }
        let row = UIStackView.ds(.horizontal, spacing: 14, alignment: .center, views: rowViews)
        card.addSubview(row)
        row.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))
        profileCard.addSubview(card)
        card.pinEdges(to: profileCard)
    }

    @objc private func selectionDidChange() {
        DispatchQueue.main.async {
            self.refreshProfileCard()
            self.modeSegmentedControl.selectedIndex = UserDefaults.standard.bool(forKey: "isTeacherMode") ? 1 : 0
            self.changeWeekSegmentedControl.selectedIndex = UserDefaults.standard.bool(forKey: "isOddWeek") ? 0 : 1
        }
    }

    // MARK: - Неделя

    @objc func changeWeek() {
        // Если синхронизация включена — запрещаем ручную смену
        if UserDefaults.standard.bool(forKey: "syncWeekEnabled") {
            // Возвращаем выбранный индекс к текущему значению
            let isOdd = UserDefaults.standard.bool(forKey: "isOddWeek")
            changeWeekSegmentedControl.selectedIndex = isOdd ? 0 : 1
            return
        }
        // Переключаем неделю
        let currentWeek = UserDefaults.standard.bool(forKey: "isOddWeek")
        let newWeek = !currentWeek
        UserDefaults.standard.set(newWeek, forKey: "isOddWeek")

        // Трекинг события
        if newWeek {
            MRMyTracker.trackEvent(name: "Переключить расписание на первую неделю")
        } else {
            MRMyTracker.trackEvent(name: "Переключить расписание на вторую неделю")
        }

        // Обновляем состояние сегментного контрола
        changeWeekSegmentedControl.selectedIndex = newWeek ? 0 : 1

        // Отправляем нотификацию для обновления расписания
        NotificationCenter.default.post(name: Notification.Name("reloadSchedule"), object: nil)
    }

    // MARK: - Режим

    @objc func modeChanged(_ sender: DSSegmentedControl) {
        Self.applyMode(isTeacher: sender.selectedIndex == 1)
    }

    /// Смена режима «Студент / Преподаватель» — из настроек и с экрана выбора
    static func applyMode(isTeacher isTeacherMode: Bool) {
        guard UserDefaults.standard.bool(forKey: "isTeacherMode") != isTeacherMode else { return }
        UserDefaults.standard.set(isTeacherMode, forKey: "isTeacherMode")

        // Трекинг события
        if isTeacherMode {
            MRMyTracker.trackEvent(name: "Включить режим преподавателя")
        } else {
            MRMyTracker.trackEvent(name: "Включить режим студента")
        }

        // Удаляем уведомления при смене режима
        let notificationManager = NotificationManager.shared
        notificationManager.removeAllNotifications()
        print("🗑️ Уведомления удалены при смене режима на \(isTeacherMode ? "преподавателя" : "студента")")

        // Отправляем нотификацию для обновления режима
        NotificationCenter.default.post(name: Notification.Name("modeChanged"), object: nil)
    }

    @objc func switchChanged(_ sender: UISwitch) {
        if sender == showFullScheduleSwitch {
            // Save the switch state to UserDefaults
            UserDefaults.standard.set(sender.isOn, forKey: "showFullSchedule")

            // Трекинг события
            if sender.isOn {
                MRMyTracker.trackEvent(name: "Включить расписание на неделю")
            } else {
                MRMyTracker.trackEvent(name: "Выключить расписание на неделю")
            }
        } else if sender == removeGroupSelectionSwitch {
            // Save the switch state to UserDefaults
            UserDefaults.standard.set(sender.isOn, forKey: "removeGroupSelection")

            // Трекинг события
            if sender.isOn {
                MRMyTracker.trackEvent(name: "Выключить видимость навигации")
            } else {
                MRMyTracker.trackEvent(name: "Включить видимость навигации")
            }

            // Update the tab bar access in MainViewController
            if let mainVC = self.navigationController?.viewControllers.first as? MainViewController {
                mainVC.updateTabBarAccess(isGroupSelectionRemoved: sender.isOn)
            }
            refreshProfileCard()
        }
    }

    @objc func backButtonTapped() {
        MRMyTracker.trackEvent(name: "Выйти из экрана настроек")
        self.navigationController?.popViewController(animated: true)
    }

    @objc private func showFeedback() {
        MRMyTracker.trackEvent(name: "Открыть опрос из настроек")
        SurveyManager.shared.openFromSettings(from: self)
    }

    @objc private func showAbout() {
        MRMyTracker.trackEvent(name: "Открыть вкладку о приложении")
        let vc = AboutViewController()
        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            present(vc, animated: true)
        }
    }

    private func showWidgets() {
        let vc = WidgetInfoViewController()
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    private func openTelegram() {
        guard let url = URL(string: "https://t.me/+oIslJtlz52cxYzZi") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    // MARK: - Уведомления

    private func updateNotificationTimeVisibility(animated: Bool = true) {
        let isEnabled = notificationsSwitch.isOn
        // Строка «Напоминать за» видна только при включённых уведомлениях
        let changes = {
            self.notificationTimeRow.isHidden = !isEnabled
            self.notificationTimeRow.alpha = isEnabled ? 1 : 0
        }
        if animated {
            UIView.animate(withDuration: 0.25) {
                changes()
                self.view.layoutIfNeeded()
            }
        } else {
            changes()
        }
    }

    private func getMinutesText(_ minutes: Int) -> String {
        let lastDigit = minutes % 10
        let lastTwoDigits = minutes % 100

        if lastTwoDigits >= 11 && lastTwoDigits <= 19 {
            return "минут"
        }

        switch lastDigit {
        case 1:
            return "минута"
        case 2, 3, 4:
            return "минуты"
        default:
            return "минут"
        }
    }

    @objc func notificationsSwitchChanged(_ sender: UISwitch) {
        let notificationManager = NotificationManager.shared
        notificationManager.isNotificationsEnabled = sender.isOn

        // Трекинг события
        if sender.isOn {
            MRMyTracker.trackEvent(name: "Включить уведомления расписания")
        } else {
            MRMyTracker.trackEvent(name: "Выключить уведомления расписания")
        }

        if sender.isOn {
            // Запрашиваем разрешение на уведомления
            notificationManager.requestNotificationPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.updateNotificationTimeVisibility()
                        // Немедленно перепланируем уведомления
                        self.rescheduleNotifications()
                    } else {
                        sender.isOn = false
                        notificationManager.isNotificationsEnabled = false
                        let alert = UIAlertController(title: "Разрешение не получено", message: "Для работы уведомлений необходимо разрешить их в настройках", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        } else {
            // Удаляем все уведомления
            notificationManager.removeAllNotifications()
            updateNotificationTimeVisibility()
        }
    }

    private func notificationTimeChanged(_ minutes: Int) {
        let notificationManager = NotificationManager.shared
        notificationManager.notificationTimeMinutes = minutes

        // Перепланируем уведомления с новым временем
        rescheduleNotifications()
    }

    private func rescheduleNotifications() {
        let notificationManager = NotificationManager.shared

        // Проверяем режим: уведомления только для студентов
        let isTeacherMode = UserDefaults.standard.bool(forKey: "isTeacherMode")
        if isTeacherMode {
            print("ℹ️ Режим преподавателя: уведомления не планируются")
            return
        }

        // Проверяем, есть ли сохраненное расписание
        let hasSchedule = UserDefaults.standard.string(forKey: "selectedGroupURL") != nil

        guard hasSchedule else {
            print("ℹ️ Нет сохраненного расписания для перепланирования уведомлений")
            return
        }

        // Пытаемся найти сохраненное расписание в UserDefaults
        if let scheduleData = UserDefaults.standard.data(forKey: "savedSchedule"),
           let schedule = try? JSONDecoder().decode([DaySchedule].self, from: scheduleData) {
            // Перепланируем уведомления с сохраненным расписанием (только для студентов)
            notificationManager.scheduleNotifications(for: schedule, isTeacherMode: false)
            print("✅ Уведомления перепланированы с сохраненным расписанием")
        } else {
            // Если нет сохраненного расписания, удаляем старые уведомления
            notificationManager.removeAllNotifications()
            print("🔄 Уведомления будут перепланированы при следующем открытии расписания")
        }
    }

    // MARK: - Sync Week
    @objc private func syncWeekSwitchChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: "syncWeekEnabled")

        // Трекинг события
        if sender.isOn {
            MRMyTracker.trackEvent(name: "Включить синхронизацию недели")
        } else {
            MRMyTracker.trackEvent(name: "Выключить синхронизацию недели")
        }

        applySyncWeekUIState(isEnabled: sender.isOn)
        if sender.isOn {
            syncWeekWithServer(applyOnlyUI: false)
        }
    }

    private func applySyncWeekUIState(isEnabled: Bool) {
        changeWeekSegmentedControl.isEnabled = !isEnabled
        changeWeekRow?.alpha = isEnabled ? 0.45 : 1
    }

    // MARK: - Theme

    private func themeTapped(_ theme: AppTheme) {
        guard ThemeManager.current != theme else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        ThemeManager.current = theme
        refreshThemeCards()
    }

    private func refreshThemeCards() {
        themeCards.forEach { $0.isOn = $0.theme == ThemeManager.current }
    }

    private func applyCorrespondenceFullWeekAvailability() {
        // Заочная группа определяется либо по уровню, либо по флагу активного режима сессии.
        let selectedLevel = UserDefaults.standard.string(forKey: "selectedGroupLevel") ?? ""
        let isCorrespondenceByLevel = selectedLevel.lowercased().contains("заочн")
        let isCorrespondenceModeActive = UserDefaults.standard.bool(forKey: "correspondenceModeActive")
        let isCorrespondence = isCorrespondenceByLevel || isCorrespondenceModeActive

        if isCorrespondence {
            showFullScheduleSwitch.setOn(false, animated: false)
            showFullScheduleSwitch.isEnabled = false
            showFullScheduleRow?.alpha = 0.45
            UserDefaults.standard.set(false, forKey: "showFullSchedule")

            // Для заочки смена недели тоже неактуальна (расписание по датам/сессии)
            changeWeekSegmentedControl.isEnabled = false
            changeWeekRow?.alpha = 0.45
        } else {
            showFullScheduleSwitch.isEnabled = true
            showFullScheduleRow?.alpha = 1
            showFullScheduleSwitch.isOn = UserDefaults.standard.bool(forKey: "showFullSchedule")

            // Возвращаем доступность смены недели только если синхронизация недели выключена
            let syncEnabled = UserDefaults.standard.bool(forKey: "syncWeekEnabled")
            changeWeekSegmentedControl.isEnabled = !syncEnabled
            changeWeekRow?.alpha = syncEnabled ? 0.45 : 1
        }
    }

    private func syncWeekWithServer(applyOnlyUI: Bool) {
        ScheduleRepository.shared.getWeekCount { result in
            switch result {
            case .success(let week):
                let isOdd = (week == 1)
                UserDefaults.standard.set(isOdd, forKey: "isOddWeek")
                DispatchQueue.main.async {
                    self.changeWeekSegmentedControl.selectedIndex = isOdd ? 0 : 1
                }
                if !applyOnlyUI {
                    NotificationCenter.default.post(name: Notification.Name("reloadSchedule"), object: nil)
                }
            case .failure:
                break
            }
        }
    }
}

// MARK: - Степпер минут

/// «− 10 мин +» — время напоминания перед парой (1…30 мин)
private final class MinutesStepper: UIView {
    var onChange: ((Int) -> Void)?
    var minutes: Int = 5 { didSet { refresh() } }
    private let label = UILabel()
    private let steps = [1, 5, 10, 15, 20, 25, 30]

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        let card = CardView(radius: 15, shadow: .none)
        card.borderColor = DS.Color.borderStrong
        addSubview(card)
        card.pinEdges(to: self)
        let minus = makeButton("−") { [weak self] in self?.step(-1) }
        let plus = makeButton("+") { [weak self] in self?.step(1) }
        minus.accessibilityLabel = "Меньше"
        plus.accessibilityLabel = "Больше"
        label.textAlignment = .center
        label.widthAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        let row = UIStackView.ds(.horizontal, spacing: 0, alignment: .center, views: [minus, label, plus])
        addSubview(row)
        row.pinEdges(to: self)
        heightAnchor.constraint(equalToConstant: 30).isActive = true
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func makeButton(_ title: String, action: @escaping () -> Void) -> DSTapControl {
        let button = DSTapControl()
        button.fixSize(width: 34, height: 30)
        let l = UILabel.ds(title, font: DS.Font.text(18), color: DS.Color.muted, alignment: .center)
        button.addSubview(l)
        l.pinEdges(to: button)
        button.onTap = action
        return button
    }

    private func step(_ direction: Int) {
        let next: Int?
        if direction > 0 {
            next = steps.first { $0 > minutes }
        } else {
            next = steps.last { $0 < minutes }
        }
        guard let value = next else { return }
        minutes = value
        UISelectionFeedbackGenerator().selectionChanged()
        onChange?(value)
    }

    private func refresh() {
        label.setDS("\(minutes) мин", font: DS.Font.mono(12.5, .semibold), alignment: .center)
        accessibilityValue = "\(minutes) мин"
    }
}

// MARK: - Карточка темы

private final class ThemeCard: DSTapControl {
    let theme: AppTheme
    private let card = CardView(radius: 16, shadow: .xs)
    private let radio = UIView()
    private let preview = UIView()
    private let previewGradient = CAGradientLayer()
    private let split = UIView()

    var isOn = false { didSet { refresh() } }

    init(theme: AppTheme) {
        self.theme = theme
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        card.isUserInteractionEnabled = false
        addSubview(card)
        card.pinEdges(to: self)

        let light = UIColor(rgb: 0xF8FAFC), dark = UIColor(rgb: 0x0A0F1E)
        preview.layer.cornerRadius = 11
        preview.clipsToBounds = true
        preview.layer.borderWidth = 1
        preview.backgroundColor = theme == .dark ? dark : light
        preview.fixSize(height: 78)
        if theme == .system {
            split.backgroundColor = dark
            split.translatesAutoresizingMaskIntoConstraints = false
            preview.addSubview(split)
            NSLayoutConstraint.activate([
                split.topAnchor.constraint(equalTo: preview.topAnchor),
                split.bottomAnchor.constraint(equalTo: preview.bottomAnchor),
                split.trailingAnchor.constraint(equalTo: preview.trailingAnchor),
                split.widthAnchor.constraint(equalTo: preview.widthAnchor, multiplier: 0.5)
            ])
        }
        let bar = UIView()
        bar.layer.cornerRadius = 7
        bar.clipsToBounds = true
        previewGradient.colors = [DS.Color.brand.cgColor, DS.Color.brandSky.cgColor]
        previewGradient.startPoint = CGPoint(x: 0, y: 0)
        previewGradient.endPoint = CGPoint(x: 1, y: 1)
        bar.layer.addSublayer(previewGradient)
        let cardColor: UIColor = theme == .light ? .white : (theme == .dark ? UIColor(rgb: 0x131A2E) : UIColor(rgb: 0x94A3B8, alpha: 0.45))
        let line1 = UIView(), line2 = UIView()
        [line1, line2].forEach { $0.backgroundColor = cardColor; $0.layer.cornerRadius = 4 }
        [bar, line1, line2].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; preview.addSubview($0) }
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: preview.topAnchor, constant: 9),
            bar.leadingAnchor.constraint(equalTo: preview.leadingAnchor, constant: 8),
            bar.trailingAnchor.constraint(equalTo: preview.trailingAnchor, constant: -8),
            bar.heightAnchor.constraint(equalToConstant: 22),
            line1.topAnchor.constraint(equalTo: preview.topAnchor, constant: 37),
            line1.leadingAnchor.constraint(equalTo: preview.leadingAnchor, constant: 8),
            line1.trailingAnchor.constraint(equalTo: preview.trailingAnchor, constant: -22),
            line1.heightAnchor.constraint(equalToConstant: 13),
            line2.topAnchor.constraint(equalTo: preview.topAnchor, constant: 55),
            line2.leadingAnchor.constraint(equalTo: preview.leadingAnchor, constant: 8),
            line2.trailingAnchor.constraint(equalTo: preview.trailingAnchor, constant: -34),
            line2.heightAnchor.constraint(equalToConstant: 13)
        ])
        self.bar = bar

        let title: String
        switch theme {
        case .light: title = "Светлая"
        case .dark: title = "Тёмная"
        case .system: title = "Авто"
        }
        let label = UILabel.ds(title, font: DS.Font.text(13, .semibold))
        radio.layer.cornerRadius = 9
        radio.fixSize(width: 18, height: 18)
        let bottom = UIStackView.ds(.horizontal, spacing: 4, alignment: .center, views: [label, UIView(), radio])
        let bottomWrap = UIView()
        bottomWrap.addSubview(bottom)
        bottom.pinEdges(to: bottomWrap, insets: UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4))
        let col = UIStackView.ds(.vertical, spacing: 8, views: [preview, bottomWrap])
        col.isUserInteractionEnabled = false
        addSubview(col)
        col.pinEdges(to: self, insets: UIEdgeInsets(top: 6, left: 6, bottom: 10, right: 6))
        accessibilityLabel = "Тема: " + title
        refresh()
    }

    private weak var bar: UIView?

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewGradient.frame = bar?.bounds ?? .zero
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refresh()
    }

    private func refresh() {
        card.borderColor = isOn ? DS.Color.brand : DS.Color.border
        card.borderWidth = isOn ? 2 : 1
        if isOn {
            card.layer.shadowColor = DS.Color.brand.cgColor
            card.layer.shadowOpacity = 0.14
            card.layer.shadowRadius = 3
            card.layer.shadowOffset = .zero
        } else {
            card.shadow = .xs
        }
        radio.layer.borderWidth = isOn ? 5 : 1.5
        radio.layer.borderColor = (isOn ? DS.Color.brand : DS.Color.borderStrong).resolvedColor(with: traitCollection).cgColor
        preview.layer.borderColor = DS.Color.border.resolvedColor(with: traitCollection).cgColor
        accessibilityTraits = isOn ? [.button, .selected] : .button
    }
}
