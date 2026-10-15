//
//  TeacherViewController.swift
//  schedule
//
//  Created by Дмитрий Цепилов on 30.11.2024.
//

import UIKit
import SwiftSoup
import YandexMobileAds
import MyTrackerSDK

class TeacherViewController: UIViewController {
    weak var delegate: TeacherSelectionDelegate?

    /// Экран выбора в новом дизайне
    private let screen = SelectionScreenView(isTeacher: true, placeholder: "Фамилия преподавателя")
    var onBack: (() -> Void)?
    var canGoBack = true { didSet { screen.canGoBack = canGoBack } }

    private var teachers: [Teacher] = []
    private var allTeachers: [Teacher] = []
    private var selectedDepartment: String?
    var selectedTeacher: String?
    private var isLoadingTeachers = true

    // Реклама: адаптивный inline-баннер
    private var yandexAdView: AdView?
    private var lastAdWidth: CGFloat = 0

    private var teachersByDepartment: [String: [String]] = [:]
    private let teacherParser = TeacherParser.shared

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
        screen.onSelectRow = { [weak self] row in self?.teacherTapped(row.id) }
        
        loadSavedSelection()

        loadTeachersFromJSON()
        loadAllTeachers() // Загружаем всех преподавателей для поиска
        
        // Тестируем парсер (можно убрать в продакшене)
        #if DEBUG
        TeacherParserSimpleTest.testWithMockHTML()
        TeacherParserConsoleTest.runTest()
        #endif

        // Настраиваем адаптивный баннер под списком, если разрешена реклама
        if AdManager.shared.shouldShowAds() {
            setupAdaptiveAdBanner()
        }
        
        // Подписываемся на уведомление об изменении темы
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: Notification.Name("themeChanged"),
            object: nil
        )
        renderList()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        screen.setMode(isTeacher: true)
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

    // MARK: - Список преподавателей

    private func renderList() {
        let query = screen.query.trimmingCharacters(in: .whitespaces).lowercased()
        let source = teachers.isEmpty ? allTeachers : teachers
        let current = selectedTeacher ?? UserDefaults.standard.string(forKey: "selectedTeacher")
        let filtered = source.filter { query.isEmpty || $0.name.lowercased().contains(query) }
        // Группировка по первой букве фамилии
        var byLetter: [String: [Teacher]] = [:]
        for teacher in filtered {
            let letter = teacher.name.first.map { String($0).uppercased() } ?? "#"
            byLetter[letter, default: []].append(teacher)
        }
        let sections: [SelectionScreenView.Section] = byLetter.keys.sorted().map { letter in
            .init(title: letter, count: nil, rows: byLetter[letter]!.map { teacher in
                .init(id: teacher.name,
                      title: teacher.name,
                      subtitle: teacher.department == "Без кафедры" ? "" : teacher.department,
                      badge: ScheduleTime.initials(teacher.name),
                      isSelected: teacher.name == current)
            })
        }
        if source.isEmpty && isLoadingTeachers {
            screen.setSections([], emptyTitle: "Загружаем преподавателей…", emptyText: nil)
        } else if source.isEmpty {
            screen.setSections([], emptyTitle: "Список недоступен", emptyText: "Проверьте подключение к интернету")
        } else {
            screen.setSections(sections, emptyTitle: "Ничего не нашли", emptyText: "Попробуйте другую фамилию")
        }
    }

    private func teacherTapped(_ name: String) {
        guard let teacher = (teachers + allTeachers).first(where: { $0.name == name }) else { return }
        print("Выбрано: \(selectedDepartment ?? "") -> \(teacher.name)")
        print("Ссылка на расписание: \(teacher.url)")
        // Кафедра всегда остается "Все кафедры"
        selectedDepartment = "Все кафедры"
        didSelectTeacher(teacher.name)
        renderList()
        saveSelection()
    }

    private func updateTeachers() {
        print("🌐 Загружаем всех преподавателей (без фильтра по кафедре)")
        
        ScheduleRepository.shared.searchTeachers(department: nil) { [weak self] result in
            switch result {
            case .success(let allTeachers):
                let teachers: [Teacher] = allTeachers.map { dto in
                    Teacher(name: dto.label, department: dto.department ?? "Без кафедры", url: dto.label)
                }
                
                DispatchQueue.main.async {
                    self?.teachers = teachers
                    self?.isLoadingTeachers = false
                    self?.renderList()
                }
            case .failure(let error):
                print("❌ Ошибка загрузки всех преподавателей: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.teachers = []
                    self?.isLoadingTeachers = false
                    self?.renderList()
                }
            }
        }
    }

    func didSelectDepartment(_ department: String) {
        selectedDepartment = department
    }

    func didSelectTeacher(_ teacher: String) {
        selectedTeacher = teacher
        MRMyTracker.trackEvent(name: "Выбрать преподавателя")
    }

    @objc func saveSelection() {
        let defaults = UserDefaults.standard
        defaults.set(selectedDepartment, forKey: "selectedTeacherDepartment")
        defaults.set(selectedTeacher, forKey: "selectedTeacher")
        MRMyTracker.trackEvent(name: "Выбрать кафедру")
        MRMyTracker.trackEvent(name: "Собрать или загрузить расписание")

        print("Выбор сохранён: \(selectedDepartment ?? "Нет кафедры"), \(selectedTeacher ?? "Нет преподавателя")")

        // Ищем преподавателя в текущем списке или в общем списке
        var teacherURL: String?
        if let selectedTeacher = selectedTeacher {
            // Сначала ищем в текущем списке преподавателей
            if let teacher = teachers.first(where: { $0.name == selectedTeacher }) {
                teacherURL = teacher.url
            } else {
                // Если не найден в текущем списке, ищем в общем списке
                if let teacher = allTeachers.first(where: { $0.name == selectedTeacher }) {
                    teacherURL = teacher.url
                }
            }
        }

        if let url = teacherURL {
            defaults.set(url, forKey: "selectedTeacherURL")
            delegate?.didSelectTeacher(withURL: url)
            print("URL преподавателя: \(url)")
            
            // Удаляем старые уведомления при смене преподавателя (хотя уведомления не планируются для преподавателей)
            NotificationManager.shared.removeAllNotifications()
            print("🗑️ Удалены старые уведомления при смене преподавателя")
        } else {
            print("❌ Не удалось найти URL для преподавателя: \(selectedTeacher ?? "неизвестно")")
        }
    }

    func loadSavedSelection() {
        let defaults = UserDefaults.standard
        selectedDepartment = "Все кафедры" // Всегда "Все кафедры"
        selectedTeacher = defaults.string(forKey: "selectedTeacher")
        print("Загружено: \(selectedDepartment ?? "Нет кафедры"), \(selectedTeacher ?? "Нет преподавателя")")

        updateTeachers()
    }

    func resizeAndTintImage(named imageName: String, size: CGSize, color: UIColor) -> UIImage? {
        if let originalImage = UIImage(named: imageName) {
            let resizedImage = UIGraphicsImageRenderer(size: size).image { _ in
                originalImage.draw(in: CGRect(origin: .zero, size: size))
            }
            return resizedImage.withTintColor(color, renderingMode: .alwaysTemplate)
        }
        return nil
    }

    func simulateUserSelection(department: String?, teacher: String?) {
        selectedDepartment = department
        selectedTeacher = teacher
    }

    private func loadTeachersFromJSON() {
        // Просто загружаем всех преподавателей, группировка по кафедрам не нужна
        print("🔄 Загружаем всех преподавателей с API...")
        ScheduleRepository.shared.searchTeachers(department: nil) { [weak self] result in
            switch result {
            case .success(let allTeachers):
                print("📚 Получено преподавателей с API: \(allTeachers.count)")
                
                DispatchQueue.main.async {
                    // Просто сохраняем пустую группировку, так как фильтр кафедры отключен
                    self?.teachersByDepartment = ["Все кафедры": []]
                    print("✅ Данные о преподавателях успешно загружены с API")
                    
                }
            case .failure(let error):
                print("❌ Ошибка загрузки данных о преподавателях: \(error.localizedDescription)")
                // В случае ошибки загружаем данные из JSON как fallback
                self?.loadFallbackData()
            }
        }
    }
    
    private func loadFallbackData() {
        if let url = Bundle.main.url(forResource: "teachers", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                if let dictionary = json as? [String: [String]] {
                    self.teachersByDepartment = dictionary
                    print("Загружены fallback данные из JSON")
                }
            } catch let error {
                print("Ошибка загрузки fallback JSON: \(error.localizedDescription)")
            }
        }
    }

    private func loadAllTeachers() {
        ScheduleRepository.shared.searchTeachers(department: nil) { [weak self] result in
            switch result {
            case .success(let teachers):
                DispatchQueue.main.async {
                    let realTeachers = teachers.map { Teacher(name: $0.label, department: $0.department ?? "", url: $0.label) }
                    self?.allTeachers = realTeachers
                    print("📚 Загружено для поиска: \(realTeachers.count) преподавателей")
                    self?.renderList()
                }
            case .failure(let error):
                print("Ошибка загрузки всех преподавателей: \(error)")
            }
        }
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
        guard yandexAdView == nil else { return }

        // Делаем баннер шире: оставляем небольшие отступы по краям
        let availableWidth = (view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width) - 32
        let adSize = BannerAdSize.inlineSize(withWidth: availableWidth, maxHeight: 100)
        let adView = AdView(adUnitID: "R-M-14326663-2", adSize: adSize)
        adView.delegate = self
        adView.translatesAutoresizingMaskIntoConstraints = false
        adView.backgroundColor = .clear
        adView.widthAnchor.constraint(equalToConstant: availableWidth).isActive = true

        // Баннер — под списком преподавателей
        screen.adView = adView
        self.yandexAdView = adView
        self.lastAdWidth = availableWidth
        loadAdWithTheme(adView: adView)
        renderList()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let targetWidth = view.bounds.width - 32
        if yandexAdView != nil, abs(targetWidth - lastAdWidth) > 0.5 {
            yandexAdView?.removeFromSuperview()
            yandexAdView = nil
            screen.adView = nil
            setupAdaptiveAdBanner()
        }
    }
}

// MARK: - YandexMobileAds AdViewDelegate
extension TeacherViewController: AdViewDelegate {
    func adViewDidLoad(_ adView: AdView) {
        // Реклама загружена
    }

    func adViewDidFailLoading(_ adView: AdView, error: Error) {
        print("Yandex Ad failed: \(error.localizedDescription)")
    }
} 