//
//  ViewController.swift
//  schedule
//
//  Created by Дмитрий Цепилов on 30.11.2024.
//

import UIKit
import SwiftSoup
import YandexMobileAds
import MyTrackerSDK

class ViewController: UIViewController {
    weak var delegate: GroupSelectionDelegate?

    /// Экран выбора в новом дизайне
    private let screen = SelectionScreenView(isTeacher: false, placeholder: "Группа, например ПИ-01")
    var onBack: (() -> Void)?
    var canGoBack = true { didSet { screen.canGoBack = canGoBack } }

    private var groups: [(name: String, url: String, level: String)] = []
    private var selectedCourse: String?
    private var selectedSpecialty: String?
    var selectedGroup: String?

    private var courses: [Int] = []
    private var isLoadingGroups = false

    // Реклама: адаптивный inline-баннер
    private var yandexAdView: AdView?
    private var lastAdWidth: CGFloat = 0

    private var apiLevels: [String] = []

    private static let allLevels = "Все специальности"

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = nil
        view.backgroundColor = DS.Color.bg

        screen.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(screen)
        screen.pinEdges(to: view)
        screen.onBack = { [weak self] in self?.onBack?() }
        screen.onQuery = { [weak self] _ in self?.renderList() }
        screen.onModeChange = { isTeacher in SettingsViewController.applyMode(isTeacher: isTeacher) }
        screen.onChip = { [weak self] group, index in self?.chipTapped(group: group, index: index) }
        screen.onSelectRow = { [weak self] row in self?.groupTapped(row.id) }

        // Подписываемся на уведомление об изменении темы
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: Notification.Name("themeChanged"),
            object: nil
        )

        // Настраиваем адаптивный баннер под списком, если разрешена реклама
        if AdManager.shared.shouldShowAds() {
            setupAdaptiveAdBanner()
        }

        loadSavedSelection()
        loadCourses()
        preloadFiltersFromAPI()
        renderChips()
        renderList()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        screen.setMode(isTeacher: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Трекинг события просмотра рекламы (независимо от того, включена реклама или нет)
        MRMyTracker.trackEvent(name: "Просмотр рекламы")
        refreshAdBannerIfNeeded()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // Обновляем баннер при смене системной темы (если выбрана системная тема)
        if ThemeManager.current == .system,
           traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            refreshAdBannerIfNeeded()
        }
    }

    // MARK: - Фильтры: уровень образования и курс

    private func loadCourses() {
        ScheduleRepository.shared.courses { result in
            switch result {
            case .success(let courseInts):
                DispatchQueue.main.async {
                    self.courses = courseInts.sorted()
                    // Курс ещё не выбирали — подставляем первый, чтобы сразу показать группы
                    if self.selectedCourse == nil, let first = self.courses.first {
                        self.selectedCourse = "\(first) курс"
                        if self.selectedSpecialty == nil { self.selectedSpecialty = Self.allLevels }
                        self.updateGroups()
                    }
                    self.renderChips()
                }
            case .failure:
                // Если не удалось загрузить, но есть выбранное ранее значение — оставляем его
                DispatchQueue.main.async {
                    if self.selectedCourse == nil {
                        let message = "Не удалось загрузить курсы. Проверьте соединение."
                        self.showErrorAlert(message: message)
                    }
                    self.renderChips()
                }
            }
        }
    }

    private var levelItems: [String] {
        let levels = apiLevels.isEmpty ? ["СПО", "Бакалавриат", "Специалитет", "Магистратура"] : apiLevels
        return ["Все уровни"] + levels
    }

    private var courseItems: [String] {
        var items = courses.map { "\($0) курс" }
        if items.isEmpty, let saved = selectedCourse { items = [saved] }
        return items
    }

    private func renderChips() {
        let levels = levelItems
        let levelIndex: Int? = {
            guard let spec = selectedSpecialty else { return nil }
            if spec == Self.allLevels { return 0 }
            return levels.firstIndex(of: spec)
        }()
        let courseList = courseItems
        screen.setChipGroups([
            .init(title: "Уровень образования", items: levels, selected: levelIndex, style: .filter),
            .init(title: "Курс", items: courseList, selected: selectedCourse.flatMap { courseList.firstIndex(of: $0) }, style: .course)
        ])
    }

    private func chipTapped(group: Int, index: Int) {
        if group == 0 {
            let levels = levelItems
            guard index < levels.count else { return }
            // Сохраняем буквальное значение, чтобы корректно отображалось после перезапуска
            let selected = index == 0 ? Self.allLevels : levels[index]
            selectedSpecialty = selected
            updateGroups()
            didSelectSpecialty(selected)
        } else {
            let items = courseItems
            guard index < items.count else { return }
            selectedCourse = items[index]
            if selectedSpecialty == nil { selectedSpecialty = Self.allLevels }
            updateGroups()
            didSelectCourse(items[index])
        }
        renderChips()
    }

    private func updateGroups() {
        guard let course = selectedCourse else {
            groups = []
            renderList()
            return
        }

        // Новая загрузка через API: course -> Int, specialty -> level
        let courseNumber: Int = Int(course.components(separatedBy: " ").first ?? "") ?? 1
        // Для "Все специальности" не передаем уровень (nil)
        let levelParam: String? = (selectedSpecialty == Self.allLevels) ? nil : selectedSpecialty
        isLoadingGroups = true
        renderList()
        ScheduleRepository.shared.searchGroups(course: courseNumber, level: levelParam) { [weak self] result in
            switch result {
            case .success(let apiGroups):
                DispatchQueue.main.async {
                    // Маппинг в старый формат только для UI выбора
                    self?.groups = apiGroups.map { ($0.name, $0.name, $0.level) }
                    self?.isLoadingGroups = false
                    self?.renderList()
                }
            case .failure:
                DispatchQueue.main.async {
                    // При офлайне не затираем выбранную группу; просто оставляем текущее значение
                    self?.groups = []
                    self?.isLoadingGroups = false
                    self?.renderList()
                }
            }
        }
    }

    // MARK: - Список групп

    private func renderList() {
        let query = screen.query.trimmingCharacters(in: .whitespaces).lowercased()
        let current = selectedGroup ?? UserDefaults.standard.string(forKey: "selectedGroupURL")
        let filtered = groups.filter { query.isEmpty || $0.name.lowercased().contains(query) }

        // Группировка по уровню образования, в порядке появления
        var order: [String] = []
        var byLevel: [String: [(name: String, url: String, level: String)]] = [:]
        for group in filtered {
            let key = group.level.isEmpty ? "Группы" : group.level
            if byLevel[key] == nil { order.append(key) }
            byLevel[key, default: []].append(group)
        }
        let sections: [SelectionScreenView.Section] = order.map { key in
            let items = byLevel[key] ?? []
            return .init(title: key, count: "\(items.count) гр.", rows: items.map { group in
                .init(id: group.name,
                      title: group.name,
                      subtitle: [selectedCourse, group.level].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "),
                      badge: Self.badge(for: group.name),
                      isSelected: group.name == current)
            })
        }

        if isLoadingGroups && filtered.isEmpty {
            screen.setSections([], emptyTitle: "Загружаем группы…", emptyText: nil)
        } else if selectedCourse == nil {
            screen.setSections([], emptyTitle: "Выберите курс", emptyText: "Группы появятся после выбора курса и уровня образования")
        } else {
            screen.setSections(sections, emptyTitle: "Ничего не нашли", emptyText: query.isEmpty ? "Для этого курса групп нет — попробуйте другой уровень" : "Попробуйте «ПИ-01» или другой курс")
        }
    }

    /// «24-Бк-ПИ-01» → «ПИ», «26-ЗГД-01» → «ЗГ»
    private static func badge(for name: String) -> String {
        // Берём буквенную часть шифра (направление), а не год или номер
        let parts = name.split(separator: "-").map(String.init)
        let letters = parts.filter { part in part.contains { $0.isLetter } }
        if let code = letters.last { return String(code.prefix(2)).uppercased() }
        return String(name.prefix(2)).uppercased()
    }

    private func groupTapped(_ name: String) {
        guard let group = groups.first(where: { $0.name == name }) else { return }
        print("Выбрано: \(selectedCourse ?? "") -> \(selectedSpecialty ?? "") -> \(group.name)")
        print("Ссылка на расписание: \(group.url)")
        didSelectGroup(group.name, level: group.level)
        renderList()
        saveSelection()
    }

    func didSelectCourse(_ course: String) {
        selectedCourse = course
        MRMyTracker.trackEvent(name: "Выбрать курс")
    }

    func didSelectSpecialty(_ specialty: String) {
        selectedSpecialty = specialty
        MRMyTracker.trackEvent(name: "Выбрать уровень образования")
    }

    func didSelectGroup(_ group: String, level: String? = nil) {
        selectedGroup = group
        if let level = level {
            UserDefaults.standard.set(level, forKey: "selectedGroupLevel")
        }
        MRMyTracker.trackEvent(name: "Выбрать группу")
    }

    @objc func saveSelection() {
        let defaults = UserDefaults.standard
        defaults.set(selectedCourse, forKey: "selectedCourse")
        defaults.set(selectedSpecialty, forKey: "selectedSpecialty")
        defaults.set(selectedGroup, forKey: "selectedGroup")

        if let selectedGroup = selectedGroup {
            // Сохраняем имя группы вместо URL
            defaults.set(selectedGroup, forKey: "selectedGroupURL")
            if let g = groups.first(where: { $0.name == selectedGroup }) {
                defaults.set(g.level, forKey: "selectedGroupLevel")
            } else if let spec = selectedSpecialty, spec != Self.allLevels {
                defaults.set(spec, forKey: "selectedGroupLevel")
            }
            delegate?.didSelectGroup(withURL: selectedGroup)
            MRMyTracker.trackEvent(name: "Собрать или загрузить расписание")

            let isTeacherMode = UserDefaults.standard.bool(forKey: "isTeacherMode")
            if !isTeacherMode {
                NotificationManager.shared.removeAllNotifications()
            }
        }
    }


    func loadSavedSelection() {
        let defaults = UserDefaults.standard
        selectedSpecialty = defaults.string(forKey: "selectedSpecialty")
        selectedCourse = defaults.string(forKey: "selectedCourse")
        selectedGroup = defaults.string(forKey: "selectedGroup")
        print("Загружено: \(selectedSpecialty ?? "Нет специальности"), \(selectedCourse ?? "Нет курса"), \(selectedGroup ?? "Нет группы")")

        updateGroups()
    }

    func simulateUserSelection(specialty: String?, course: String?, group: String?) {
        selectedSpecialty = specialty
        selectedCourse = course
        selectedGroup = group
    }

    private func preloadFiltersFromAPI() {
        fetchLevels { [weak self] result in
            switch result {
            case .success(let levels):
                DispatchQueue.main.async {
                    self?.apiLevels = levels
                    self?.renderChips()
                }
            case .failure(let error):
                print("Ошибка загрузки уровней: \(error.localizedDescription)")
            }
        }
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Ошибка загрузки", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Повторить", style: .default) { [weak self] _ in
            self?.loadCourses()
            self?.preloadFiltersFromAPI()
            self?.updateGroups()
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Yandex Ads

    @objc private func themeDidChange() {
        // Обновляем баннер при изменении темы
        refreshAdBannerIfNeeded()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Явное обновление баннера – можно вызывать при появлении экрана
    /// или при переключении вкладок, чтобы всегда получать свежий баннер.
    func refreshAdBannerIfNeeded() {
        guard AdManager.shared.shouldShowAds() else { return }

        if let adView = yandexAdView {
            loadAdWithTheme(adView: adView)
        } else {
            setupAdaptiveAdBanner()
        }
    }

    /// Определяет текущую тему приложения
    private func getCurrentTheme() -> AdTheme {
        let isDarkMode: Bool
        switch ThemeManager.current {
        case .light:
            isDarkMode = false
        case .dark:
            isDarkMode = true
        case .system:
            if #available(iOS 13.0, *) {
                isDarkMode = traitCollection.userInterfaceStyle == .dark
            } else {
                isDarkMode = false
            }
        }
        return isDarkMode ? .dark : .light
    }

    /// Загружает рекламу с учетом текущей темы
    private func loadAdWithTheme(adView: AdView) {
        let adRequest = MutableAdRequest()
        adRequest.adTheme = getCurrentTheme()
        adView.loadAd(with: adRequest)
    }

    private func setupAdaptiveAdBanner() {
        // Создаем контейнер баннера, если еще не создан
        guard yandexAdView == nil else { return }

        // Делаем баннер шире: оставляем небольшие отступы по краям
        let availableWidth = (view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width) - 32
        let adSize = BannerAdSize.inlineSize(withWidth: availableWidth, maxHeight: 100)
        let adView = AdView(adUnitID: "R-M-14326663-2", adSize: adSize)
        adView.delegate = self
        adView.translatesAutoresizingMaskIntoConstraints = false
        adView.backgroundColor = .clear
        adView.widthAnchor.constraint(equalToConstant: availableWidth).isActive = true

        // Баннер — под списком групп
        screen.adView = adView
        self.yandexAdView = adView
        self.lastAdWidth = availableWidth
        loadAdWithTheme(adView: adView)
        renderList()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Пересоздаем баннер при изменении доступной ширины
        let targetWidth = view.bounds.width - 32
        if yandexAdView != nil, abs(targetWidth - lastAdWidth) > 0.5 {
            yandexAdView?.removeFromSuperview()
            yandexAdView = nil
            screen.adView = nil
            setupAdaptiveAdBanner()
        }
    }
}

extension UIColor {
    func darker(by percentage: CGFloat = 30.0) -> UIColor? {
        return self.adjust(by: -1 * abs(percentage) )
    }

    func adjust(by percentage: CGFloat = 30.0) -> UIColor? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return UIColor(red: min(red + percentage/100, 1.0),
                          green: min(green + percentage/100, 1.0),
                          blue: min(blue + percentage/100, 1.0),
                          alpha: alpha)
        } else {
            return nil
        }
    }
}

// MARK: - YandexMobileAds AdViewDelegate
extension ViewController: AdViewDelegate {
    func adViewDidLoad(_ adView: AdView) {
        // Реклама загружена
    }

    func adViewDidFailLoading(_ adView: AdView, error: Error) {
        // Ошибка загрузки рекламы
        print("Yandex Ad failed: \(error.localizedDescription)")
    }
}
