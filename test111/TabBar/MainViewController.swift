//
//  MainViewController.swift
//  schedule
//
//  Created by Дмитрий Цепилов on 30.11.2024.
//

import UIKit
import MyTrackerSDK

protocol GroupSelectionDelegate: AnyObject {
    func didSelectGroup(withURL url: String)
}

protocol TeacherSelectionDelegate: AnyObject {
    func didSelectTeacher(withURL url: String)
}

class MainViewController: UIViewController, GroupSelectionDelegate, TeacherSelectionDelegate {
    var firstVC: ViewController!
    var secondVC: TwoViewController!
    var teacherFirstVC: TeacherViewController!
    var teacherSecondVC: TeacherScheduleViewController!
    var settingsVC: SettingsViewController!

    /// Что сейчас на экране: вкладки нижней панели или выбор группы/преподавателя
    private enum Page: Equatable { case today, week, settings, select }

    private var isTeacherMode: Bool = false
    private var currentAnimationVC: ModeSwitchAnimationViewController?
    private var page: Page = .today
    private var isGroupSelectionRemoved = false

    private let navBar = FloatingNavBar()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.Color.bg

        // Инициализация контроллеров для режима студента
        firstVC = ViewController()
        secondVC = TwoViewController()

        // Инициализация контроллеров для режима преподавателя
        teacherFirstVC = TeacherViewController()
        teacherSecondVC = TeacherScheduleViewController()

        settingsVC = SettingsViewController()

        // Установка делегатов
        firstVC.delegate = self
        teacherFirstVC.delegate = self

        for child in [secondVC, teacherSecondVC, settingsVC, firstVC, teacherFirstVC] as [UIViewController] {
            addChild(child)
            view.addSubview(child.view)
            child.view.frame = view.bounds
            child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            child.didMove(toParent: self)
            child.view.isHidden = true
        }

        // Переходы со страниц расписания
        secondVC.onSelectGroup = { [weak self] in self?.show(.select) }
        secondVC.onOpenWeek = { [weak self] in self?.show(.week) }
        secondVC.onOpenDay = { [weak self] in self?.show(.today) }
        teacherSecondVC.onSelectGroup = { [weak self] in self?.show(.select) }
        teacherSecondVC.onOpenWeek = { [weak self] in self?.show(.week) }
        settingsVC.onOpenSelection = { [weak self] in self?.show(.select) }
        firstVC.onBack = { [weak self] in self?.closeSelection() }
        teacherFirstVC.onBack = { [weak self] in self?.closeSelection() }

        // Плавающая навигация
        view.addSubview(navBar)
        NSLayoutConstraint.activate([
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            navBar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -28)
        ])
        navBar.onSelect = { [weak self] item in self?.navTapped(item) }
        navBar.onSearch = { [weak self] in
            MRMyTracker.trackEvent(name: "Перейти на главный экран")
            self?.show(.select)
        }

        // Загружаем сохраненный режим
        loadSavedMode()

        // Проверка состояния переключателя для удаления выбора группы
        let isGroupSelectionRemoved = UserDefaults.standard.bool(forKey: "removeGroupSelection")
        updateTabBarAccess(isGroupSelectionRemoved: isGroupSelectionRemoved)

        if let selectedGroupURL = UserDefaults.standard.string(forKey: "selectedGroupURL") {
            // Теперь здесь хранится имя группы
            secondVC.selectedGroupURL = selectedGroupURL
            secondVC.loadTimetableData()
        }

        // Стартовая страница: расписание, если группа уже выбрана; «Неделя» — если включено «Показать всю неделю»
        show(hasSavedSelection ? (UserDefaults.standard.bool(forKey: "showFullSchedule") ? .week : .today) : .select, animated: false)

        // Подписываемся на нотификацию об изменении режима
        NotificationCenter.default.addObserver(self, selector: #selector(handleModeChange), name: Notification.Name("modeChanged"), object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Показываем окно с информацией о виджетах через 10 секунд после запуска
        showWidgetInfoIfNeeded()

        // Опрос обратной связи: проверка не чаще раза в сутки, с учётом «Не сейчас»
        SurveyManager.shared.scheduleScreenDidAppear(from: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    private func showWidgetInfoIfNeeded() {
        // Проверяем, было ли уже показано окно
        let hasSeenWidgetInfo = UserDefaults.standard.bool(forKey: "hasSeenWidgetInfo")

        if !hasSeenWidgetInfo {
            // Показываем через 10 секунд
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                // Проверяем еще раз, чтобы избежать показа, если пользователь уже закрыл окно
                if !UserDefaults.standard.bool(forKey: "hasSeenWidgetInfo") {
                    let widgetInfoVC = WidgetInfoViewController()
                    widgetInfoVC.modalPresentationStyle = .overFullScreen
                    widgetInfoVC.modalTransitionStyle = .crossDissolve
                    self.present(widgetInfoVC, animated: true)
                }
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private var hasSavedSelection: Bool {
        let key = isTeacherMode ? "selectedTeacherURL" : "selectedGroupURL"
        return !(UserDefaults.standard.string(forKey: key) ?? "").isEmpty
    }

    private func loadSavedMode() {
        // Проверяем, есть ли сохраненный режим, если нет - устанавливаем режим студента по умолчанию
        if UserDefaults.standard.object(forKey: "isTeacherMode") == nil {
            UserDefaults.standard.set(false, forKey: "isTeacherMode")
        }

        let savedMode = UserDefaults.standard.bool(forKey: "isTeacherMode")
        if savedMode != isTeacherMode {
            isTeacherMode = savedMode
            switchMode()
        }
    }

    @objc private func handleModeChange() {
        let newMode = UserDefaults.standard.bool(forKey: "isTeacherMode")

        // Если режим не изменился, ничего не делаем
        if newMode == isTeacherMode {
            return
        }

        // Показываем анимацию переключения режимов
        showModeSwitchAnimation {
            // Анимация завершена, ничего дополнительно не делаем
        }

        // Переключаем режим во время показа анимации (когда пользователь не видит экран)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isTeacherMode = newMode
            self.switchMode()
            // Без сохранённого выбора (или если переключали на экране выбора) — на выбор группы/преподавателя
            let stayOnSelect = self.page == .select || !self.hasSavedSelection
            self.page = .today
            self.show(stayOnSelect ? .select : .today, animated: false)
        }
    }

    // Реализация методов протоколов
    func didSelectGroup(withURL url: String) {
        if !isTeacherMode {
            // Очищаем старое расписание при смене группы
            if secondVC.selectedGroupURL != url {
                secondVC.fullSchedule = []
                secondVC.schedule = []
                UserDefaults.standard.removeObject(forKey: "correspondenceSelectedISODate")
                UserDefaults.standard.set(false, forKey: "correspondenceModeActive")
            }

            // Теперь сюда приходит имя группы
            secondVC.selectedGroupURL = url
            secondVC.loadTimetableData()

            // Переход к расписанию
            show(.today)
        }
    }

    func didSelectTeacher(withURL url: String) {
        if isTeacherMode {
            // Очищаем старое расписание при смене преподавателя
            if teacherSecondVC.selectedTeacherURL != url {
                teacherSecondVC.fullSchedule = []
                teacherSecondVC.schedule = []
            }

            teacherSecondVC.selectedTeacherURL = url
            teacherSecondVC.loadTimetableData()

            // Переход к расписанию
            show(.today)
        }
    }

    // MARK: - Навигация

    private func navTapped(_ item: FloatingNavBar.Item) {
        switch item {
        case .today:
            MRMyTracker.trackEvent(name: "Перейти на экран расписания")
            if page == .today {
                // Повторное нажатие — вернуться к сегодняшнему дню
                if isTeacherMode { teacherSecondVC.resetToToday() } else { secondVC.resetToToday() }
            }
            show(.today)
        case .week:
            MRMyTracker.trackEvent(name: "Перейти на экран расписания")
            show(.week)
        case .settings:
            show(.settings)
        }
    }

    /// «Назад» на экране выбора: к расписанию, если выбор уже есть
    private func closeSelection() {
        guard hasSavedSelection else { return }
        show(UserDefaults.standard.bool(forKey: "showFullSchedule") ? .week : .today)
    }

    private var scheduleVC: UIViewController { isTeacherMode ? teacherSecondVC : secondVC }
    private var selectVC: UIViewController { isTeacherMode ? teacherFirstVC : firstVC }

    private func controller(for page: Page) -> UIViewController {
        switch page {
        case .today, .week: return scheduleVC
        case .settings: return settingsVC
        case .select: return selectVC
        }
    }

    private func show(_ newPage: Page, animated: Bool = true) {
        if newPage == .select && isGroupSelectionRemoved && !isTeacherMode && hasSavedSelection { return }

        // Вкладки «Сегодня» и «Неделя» — один экран расписания в двух режимах
        if newPage == .today || newPage == .week {
            let week = newPage == .week
            if isTeacherMode { teacherSecondVC.displayWeek = week } else { secondVC.displayWeek = week }
        }

        let target = controller(for: newPage)
        let all: [UIViewController] = [firstVC, secondVC, teacherFirstVC, teacherSecondVC, settingsVC]
        let previous = all.first { !$0.view.isHidden }
        page = newPage

        switch newPage {
        case .today: navBar.selected = .today
        case .week: navBar.selected = .week
        case .settings: navBar.selected = .settings
        case .select: navBar.selected = nil
        }
        // На экране выбора нижняя панель не нужна (как в макете Select)
        let navHidden = newPage == .select
        firstVC.canGoBack = hasSavedSelection
        teacherFirstVC.canGoBack = hasSavedSelection

        guard previous !== target else {
            setNavHidden(navHidden, animated: animated)
            return
        }

        // Колбэки появления дочерним экранам — только когда главный экран уже на экране
        let forwardsAppearance = view.window != nil
        if forwardsAppearance {
            previous?.beginAppearanceTransition(false, animated: animated)
            target.beginAppearanceTransition(true, animated: animated)
        }
        target.view.isHidden = false
        view.bringSubviewToFront(target.view)
        view.bringSubviewToFront(navBar)

        let finish = {
            for vc in all where vc !== target { vc.view.isHidden = true }
            if forwardsAppearance {
                previous?.endAppearanceTransition()
                target.endAppearanceTransition()
            }
        }
        if animated {
            target.view.alpha = 0
            target.view.transform = CGAffineTransform(translationX: 0, y: 8)
            UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseOut], animations: {
                target.view.alpha = 1
                target.view.transform = .identity
            }, completion: { _ in finish() })
        } else {
            target.view.alpha = 1
            finish()
        }
        setNavHidden(navHidden, animated: animated)

        // При каждом переходе на выбор группы обновляем баннер
        if newPage == .select {
            if isTeacherMode {
                teacherFirstVC.refreshAdBannerIfNeeded()
            } else {
                firstVC.refreshAdBannerIfNeeded()
            }
        }
    }

    private func setNavHidden(_ hidden: Bool, animated: Bool) {
        let changes = {
            self.navBar.alpha = hidden ? 0 : 1
            self.navBar.transform = hidden ? CGAffineTransform(translationX: 0, y: 24) : .identity
        }
        navBar.isUserInteractionEnabled = !hidden
        if animated {
            UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: [.beginFromCurrentState], animations: changes)
        } else {
            changes()
        }
    }

    private func showModeSwitchAnimation(completion: @escaping () -> Void) {
        // Отменяем предыдущую анимацию, если она есть
        currentAnimationVC?.dismiss(animated: false)

        let animationVC = ModeSwitchAnimationViewController()
        animationVC.modalPresentationStyle = .overFullScreen
        animationVC.completion = completion
        currentAnimationVC = animationVC
        present(animationVC, animated: false)
    }

    private func switchMode() {
        if isTeacherMode {
            // Очищаем старое расписание студента
            secondVC.fullSchedule = []
            secondVC.schedule = []

            // Загружаем сохраненные данные преподавателя
            if let selectedTeacherURL = UserDefaults.standard.string(forKey: "selectedTeacherURL") {
                // Теперь здесь хранится ФИО преподавателя
                teacherSecondVC.selectedTeacherURL = selectedTeacherURL
                teacherSecondVC.loadTimetableData()
            }

            // При переключении в режим преподавателя обновляем баннер на первом экране
            teacherFirstVC.refreshAdBannerIfNeeded()
        } else {
            // Очищаем старое расписание преподавателя
            teacherSecondVC.fullSchedule = []
            teacherSecondVC.schedule = []

            // Загружаем сохраненные данные группы
            if let selectedGroupURL = UserDefaults.standard.string(forKey: "selectedGroupURL") {
                secondVC.selectedGroupURL = selectedGroupURL
                secondVC.loadTimetableData()
            }

            // При переключении в режим студента обновляем баннер на первом экране
            firstVC.refreshAdBannerIfNeeded()
        }
        updateTabBarAccess(isGroupSelectionRemoved: UserDefaults.standard.bool(forKey: "removeGroupSelection"))
    }

    /// «Убрать выбор группы»: прячем кнопку поиска и не даём открыть выбор из шапки
    func updateTabBarAccess(isGroupSelectionRemoved: Bool) {
        self.isGroupSelectionRemoved = isGroupSelectionRemoved
        let locked = isGroupSelectionRemoved && !isTeacherMode
        navBar.isSearchHidden = locked
        secondVC.canChangeGroup = !locked
        if locked && page == .select && hasSavedSelection {
            show(.today, animated: false)
        }
    }
}
