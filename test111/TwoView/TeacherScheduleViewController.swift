//
//  TeacherScheduleViewController.swift
//  schedule
//
//  Created by Дмитрий Цепилов on 30.11.2024.
//

import UIKit
import SwiftSoup
import UserNotifications
import MyTrackerSDK
#if canImport(WidgetKit)
import WidgetKit
#endif

class TeacherScheduleViewController: UIViewController {

    /// Экран расписания в новом дизайне (вместо таблицы)
    let board = ScheduleBoardView()
    var schedule: [DaySchedule] = [] // Сюда будет сохраняться расписание для отображения
    var fullSchedule: [DaySchedule] = [] // Хранит полное расписание на неделю
    var selectedTeacherURL: String? {
        didSet { if oldValue != selectedTeacherURL { selectedDayIndex = nil } }
    }

    /// Вкладка «Неделя» (true) или «Сегодня» (false); nil — как в настройке «Показать всю неделю»
    var displayWeek: Bool? {
        didSet { if oldValue != displayWeek { updateTableViewBasedOnSettings(animated: true) } }
    }
    /// Выбранный в полосе день (Пн = 0); nil — сегодня
    private var selectedDayIndex: Int?
    /// Последняя загрузка не удалась, показываем кеш
    private var isOffline = false
    /// Идёт первая загрузка, данных ещё нет
    private var isLoading = false
    private var didShowError = false

    // Переходы, которыми управляет MainViewController
    var onSelectGroup: (() -> Void)?
    var onOpenWeek: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.Color.bg

        board.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(board)
        board.pinEdges(to: view)

        board.onSelectGroup = { [weak self] in self?.onSelectGroup?() }
        board.onOpenWeek = { [weak self] in self?.onOpenWeek?() }
        board.onRetry = { [weak self] in
            self?.isOffline = false
            self?.loadTimetableData()
        }
        board.onSelectDay = { [weak self] index in
            guard let self = self else { return }
            self.selectedDayIndex = index
            self.renderBoard(animated: true)
        }
        board.onParity = { [weak self] parity in self?.changeWeekParity(to: parity) }

        requestNotificationPermission()
        listScheduledNotifications()

        // Регистрируемся на нотификацию для обновления расписания
        NotificationCenter.default.addObserver(self, selector: #selector(reloadSchedule), name: Notification.Name("reloadSchedule"), object: nil)
        
        // Регистрируемся на нотификацию для смены режима
        NotificationCenter.default.addObserver(self, selector: #selector(handleModeChange), name: Notification.Name("modeChanged"), object: nil)

        renderBoard(animated: false)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func reloadSchedule() {
        // Очищаем расписание перед загрузкой, чтобы избежать обращения к старым индексам
        schedule = []
        loadTimetableData()
        // updateTableViewBasedOnSettings() будет вызван внутри loadTimetableData() после загрузки данных
    }
    
    @objc func handleModeChange() {
        // При смене режима очищаем расписание, чтобы избежать показа данных из другого режима
        fullSchedule = []
        schedule = []
        print("🔄 TeacherScheduleViewController: Очищено расписание при смене режима")
    }

    func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else {
                print("Notification permission denied.")
            }
        }
    }

    func scheduleNotifications(for schedule: [DaySchedule]) {
        // Делегируем в NotificationManager для планирования на 7 дней
        NotificationManager.shared.scheduleNotifications(for: fullSchedule, isTeacherMode: true)
    }

    func listScheduledNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            if requests.isEmpty {
                print("Запланированные уведомления: Пусто")
            } else {
                print("Запланированные уведомления:")
                for request in requests {
                    print("ID: \(request.identifier), Контент: \(request.content.body)")
                }
            }
        }
    }

    @objc func openSettings() {
        let settingsViewController = SettingsViewController()
        navigationController?.pushViewController(settingsViewController, animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Проверяем соответствие режима: если мы в режиме студента, но кеш содержит данные преподавателя (или наоборот),
        // нужно очистить fullSchedule и загрузить правильные данные
        let currentIsTeacherMode = UserDefaults.standard.bool(forKey: "isTeacherMode")
        if !currentIsTeacherMode {
            // Если мы в режиме студента, но открыт контроллер преподавателя - очищаем расписание
            fullSchedule = []
            schedule = []
            print("⚠️ TeacherScheduleViewController: Очищено расписание - текущий режим студента")
            updateTableViewBasedOnSettings()
            self.navigationController?.setNavigationBarHidden(true, animated: animated)
            return
        }
        
        // Режим преподавателя - всегда проверяем кеш, даже если fullSchedule не пустой
        // Это гарантирует, что мы используем правильные данные для текущего режима и преподавателя
        if let cached = ScheduleStorage.loadSchedule(), !cached.isEmpty {
            // Если кеш найден и соответствует текущему режиму и преподавателю, используем его
            print("📦 Teacher: используем закешированное расписание из ScheduleStorage")
            fullSchedule = cached
        } else if fullSchedule.isEmpty {
            // Если кеш не найден и fullSchedule пустой, пробуем загрузить с сервера
            // Но только если выбран преподаватель
            if let teacherName = selectedTeacherURL, !teacherName.isEmpty {
                loadTimetableData()
                return
            }
        }
        // Если fullSchedule не пустой, но кеш не найден - это может быть старые данные в памяти
        // В этом случае оставляем как есть, но лучше было бы очистить
        
        updateTableViewBasedOnSettings()
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    func loadTimetableData() {
        // Теперь selectedTeacherURL содержит ФИО преподавателя
        guard let teacherName = selectedTeacherURL, !teacherName.isEmpty else {
            print("Не выбран преподаватель")
            // Пробуем загрузить из кеша перед показом ошибки
            if let cached = ScheduleStorage.loadSchedule(), !cached.isEmpty {
                print("📦 Загружаем расписание преподавателя из кеша при отсутствии выбранного преподавателя")
                fullSchedule = cached
                updateTableViewBasedOnSettings()
                return
            }
            showError()
            return
        }
        
        // Сначала пробуем загрузить из кеша (если есть)
        if let cached = ScheduleStorage.loadSchedule(), !cached.isEmpty {
            print("📦 Загружаем расписание преподавателя из кеша перед запросом к серверу")
            fullSchedule = cached
            updateTableViewBasedOnSettings()
        }
        
        // Данных нет — показываем заглушку загрузки
        setLoading(fullSchedule.isEmpty)

        let isSyncEnabled = UserDefaults.standard.bool(forKey: "syncWeekEnabled")
        if isSyncEnabled {
            ScheduleRepository.shared.getWeekCount { result in
                switch result {
                case .success(let week):
                    let isOdd = (week == 1)
                    UserDefaults.standard.set(isOdd, forKey: "isOddWeek")
                    ScheduleRepository.shared.getTeacherSchedule(teacher: teacherName, weekCount: week) { result in
                        switch result {
                        case .success(let items):
                            let weekSchedule = self.mapAPIScheduleToWeek(items)
                            DispatchQueue.main.async {
                                self.isOffline = false
                                self.fullSchedule = weekSchedule
                                self.updateTableViewBasedOnSettings()
                            }
                        case .failure:
                            // При ошибке сети не показываем ошибку, если есть кеш
                            if self.fullSchedule.isEmpty {
                                self.showError()
                            } else {
                                self.showOfflineCache()
                            }
                        }
                    }
                case .failure:
                    let isOdd = UserDefaults.standard.bool(forKey: "isOddWeek")
                    let weekLocal = isOdd ? 1 : 2
                    ScheduleRepository.shared.getTeacherSchedule(teacher: teacherName, weekCount: weekLocal) { result in
                        switch result {
                        case .success(let items):
                            let weekSchedule = self.mapAPIScheduleToWeek(items)
                            DispatchQueue.main.async {
                                self.isOffline = false
                                self.fullSchedule = weekSchedule
                                self.updateTableViewBasedOnSettings()
                            }
                        case .failure:
                            // При ошибке сети не показываем ошибку, если есть кеш
                            if self.fullSchedule.isEmpty {
                                self.showError()
                            } else {
                                self.showOfflineCache()
                            }
                        }
                    }
                }
            }
        } else {
            let isOdd = UserDefaults.standard.bool(forKey: "isOddWeek")
            let week = isOdd ? 1 : 2
            ScheduleRepository.shared.getTeacherSchedule(teacher: teacherName, weekCount: week) { result in
                switch result {
                case .success(let items):
                    let weekSchedule = self.mapAPIScheduleToWeek(items)
                    DispatchQueue.main.async {
                        self.isOffline = false
                        self.fullSchedule = weekSchedule
                        self.updateTableViewBasedOnSettings()
                    }
                case .failure:
                    // При ошибке сети не показываем ошибку, если есть кеш
                    if self.fullSchedule.isEmpty {
                        self.showError()
                    } else {
                        self.showOfflineCache()
                    }
                }
            }
        }
    }

    func showError() {
        DispatchQueue.main.async {
            self.isLoading = false
            self.didShowError = true
            self.renderBoard(animated: false)
        }
    }

    /// Сеть недоступна, но расписание есть в кеше — показываем его с плашкой «Нет подключения»
    private func showOfflineCache() {
        DispatchQueue.main.async {
            self.isLoading = false
            self.isOffline = true
            self.renderBoard(animated: false)
        }
    }

    private func setLoading(_ loading: Bool) {
        DispatchQueue.main.async {
            guard self.isLoading != loading else { return }
            self.isLoading = loading
            if loading { self.didShowError = false }
            self.renderBoard(animated: false)
        }
    }

    private var isWeekDisplay: Bool {
        displayWeek ?? UserDefaults.standard.bool(forKey: "showFullSchedule")
    }

    func updateTableViewBasedOnSettings(animated: Bool = false) {
        let isFullScheduleEnabled = isWeekDisplay
        if isFullScheduleEnabled {
            schedule = fullSchedule // Показываем расписание на всю неделю
            MRMyTracker.trackEvent(name: "Открыть расписание преподавателя на неделю")
        } else {
            updateTableForToday() // Показываем расписание на текущий день
            MRMyTracker.trackEvent(name: "Открыть расписание преподавателя на сегодня")
        }

        DispatchQueue.main.async {
            // Убедитесь, что текст отображается, если расписание пустое
            if self.fullSchedule.isEmpty {
                if !self.isLoading { self.didShowError = true }
                self.renderBoard(animated: animated)
            } else {
                self.isLoading = false
                self.didShowError = false
                self.renderBoard(animated: animated)
                
                // Планируем уведомления для загруженного расписания
                self.scheduleNotifications()
            }
        }
    }

    /// Собирает состояние экрана из данных контроллера
    private func renderBoard(animated: Bool) {
        guard isViewLoaded else { return }
        var input = ScheduleBoardView.Input()
        let teacher = selectedTeacherURL ?? UserDefaults.standard.string(forKey: "selectedTeacherURL") ?? ""
        input.who = teacher
        input.isTeacher = true
        input.hasSelection = !teacher.isEmpty
        input.days = fullSchedule
        input.offline = isOffline
        input.mode = isWeekDisplay ? .week : .day
        input.selectedDay = selectedDayIndex ?? ScheduleTime.weekdayIndex(of: Date())
        input.parity = UserDefaults.standard.bool(forKey: "isOddWeek") ? 1 : 2
        input.parityLocked = UserDefaults.standard.bool(forKey: "syncWeekEnabled")
        if fullSchedule.isEmpty {
            input.phase = (isLoading && !didShowError) ? .loading : (didShowError || !input.hasSelection ? .error : .loading)
        } else {
            input.phase = .content
        }
        board.render(input, animated: animated)
    }

    /// Сбросить выбор дня на сегодня и прокрутить наверх (повторное нажатие на вкладку)
    func resetToToday() {
        selectedDayIndex = nil
        board.scrollToTop()
        renderBoard(animated: true)
    }

    /// Смена чётности недели — то же, что переключатель «Сменить неделю» в настройках
    private func changeWeekParity(to parity: Int) {
        guard !UserDefaults.standard.bool(forKey: "syncWeekEnabled") else { return }
        let isOdd = parity == 1
        guard UserDefaults.standard.bool(forKey: "isOddWeek") != isOdd else { return }
        UserDefaults.standard.set(isOdd, forKey: "isOddWeek")
        MRMyTracker.trackEvent(name: isOdd ? "Переключить расписание на первую неделю" : "Переключить расписание на вторую неделю")
        NotificationCenter.default.post(name: Notification.Name("reloadSchedule"), object: nil)
    }
    
    private func scheduleNotifications() {
        let notificationManager = NotificationManager.shared
        let isTeacherMode = UserDefaults.standard.bool(forKey: "isTeacherMode")
        
        // Сохраняем расписание для виджета (даже для преподавателей)
        // Используем ScheduleStorage для сохранения (поддерживает App Group)
        // Передаем метаданные для правильного кеширования
        ScheduleStorage.saveSchedule(fullSchedule, isTeacherMode: isTeacherMode, selectedGroup: nil, selectedTeacher: selectedTeacherURL)
#if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
#endif
        
        // Уведомления не планируются для преподавателей
        print("ℹ️ Режим преподавателя: уведомления не планируются")
    }

    func parseLessonDate(_ time: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"

        // Извлечение времени начала из диапазона (до символа "-")
        guard let startTime = time.split(separator: "-").first else {
            print("Неверный формат времени: \(time)")
            return nil
        }

        // Преобразование времени начала в Date
        guard let timeComponents = dateFormatter.date(from: String(startTime)) else {
            print("Не удалось преобразовать время: \(startTime)")
            return nil
        }

        let calendar = Calendar.current
        let today = Date()
        let components = calendar.dateComponents([.year, .month, .day], from: today)
        var dateComponents = DateComponents()
        dateComponents.year = components.year
        dateComponents.month = components.month
        dateComponents.day = components.day
        dateComponents.hour = calendar.component(.hour, from: timeComponents)
        dateComponents.minute = calendar.component(.minute, from: timeComponents)

        let resultDate = calendar.date(from: dateComponents)
        if resultDate == nil {
            print("Ошибка при создании даты для времени: \(startTime)")
        }
        return resultDate
    }

    // Строит дату занятия на конкретный день, устанавливая время начала пары из строки вида "HH:mm-HH:mm"
    func dateBySettingStartTime(for date: Date, from time: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"

        guard let startTimeString = time.split(separator: "-").first else {
            print("Неверный формат времени: \(time)")
            return nil
        }

        guard let startTime = dateFormatter.date(from: String(startTimeString)) else {
            print("Не удалось преобразовать время: \(startTimeString)")
            return nil
        }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        var dateComponents = DateComponents()
        dateComponents.year = components.year
        dateComponents.month = components.month
        dateComponents.day = components.day
        dateComponents.hour = calendar.component(.hour, from: startTime)
        dateComponents.minute = calendar.component(.minute, from: startTime)

        return calendar.date(from: dateComponents)
    }

    func updateTableForToday() {
        if let todaysSchedule = getTodaysSchedule() {
            schedule = [todaysSchedule]

            // Планируем централизованно на 7 дней
            self.scheduleNotifications()
        } else {
            print("No schedule found for today.")
        }

    }

    func getTodaysSchedule() -> DaySchedule? {
        let calendar = Calendar.current
        let today = Date()

        // Получаем номер дня недели (1 - воскресенье, 2 - понедельник и т.д.)
        let weekday = calendar.component(.weekday, from: today)
        print("Current weekday: \(weekday)")

        // Вычисляем даты недели
        let weekDates = calculateWeekDates()
        print("Week dates: \(weekDates)")

        // Если воскресенье, возвращаем фиктивное расписание с датой
        if weekday == 1 {
            let sundayDate = weekDates.last ?? "Неизвестная дата" // Берем последнюю дату из массива
            return DaySchedule(
                day: "Воскресенье",
                date: sundayDate,
                lessons: [Lesson(
                    number: 0,
                    time: "",
                    subject: "Сегодня выходной. Наслаждайтесь отдыхом!",
                    teacher: "", room: "", type: "",
                    color: .systemGray
                )]
            )
        }

        // Возвращаем расписание для текущего дня
        if weekday > 1 && weekday <= fullSchedule.count + 1 {
            return fullSchedule[weekday - 2] // Индекс в расписании должен быть на 1 меньше
        }

        return nil
    }

    func calculateWeekDates() -> [String] {
        let calendar = Calendar.current
        let today = Date()

        // Определяем день недели (1 - воскресенье, 2 - понедельник и т.д.)
        let weekday = calendar.component(.weekday, from: today)

        // Смещение от сегодняшнего дня до понедельника
        let daysToMonday = weekday == 1 ? -6 : 2 - weekday

        // Понедельник текущей недели
        guard let startOfWeek = calendar.date(byAdding: .day, value: daysToMonday, to: today) else {
            fatalError("Unable to calculate start of week")
        }

        // Форматтер для вывода даты
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.dateFormat = "d MMMM" // Пример: "18 ноября"

        // Генерируем даты недели с понедельника по воскресенье
        var weekDates: [String] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                weekDates.append(dateFormatter.string(from: date))
            }
        }

        return weekDates
    }

    func processHTML(_ htmlString: String) { }

    func parseWeek(document: Document, lessonNumbersSelector: String, lessonTimesSelector: String, daySelectors: [String]) -> [DaySchedule] {
        var parsedSchedule: [DaySchedule] = []
        let daysOfWeek = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]
        let weekDates = calculateWeekDates()

        do {
            let lessonNumbers = try document.select(lessonNumbersSelector).select("td").map { try $0.text() }
            let lessonTimes = try document.select(lessonTimesSelector).select("td").map { try $0.text() }

            let timeSlots = [
                (start: "08:00", end: "09:30"),  // Пара 1
                (start: "09:40", end: "11:10"),  // Пара 2
                (start: "11:30", end: "13:00"),  // Пара 3
                (start: "13:10", end: "14:40"),  // Пара 4
                (start: "14:50", end: "16:20"),  // Пара 5
                (start: "16:30", end: "18:00"),  // Пара 6
                (start: "18:10", end: "19:40")   // Пара 7
            ]

            for (index, daySelector) in daySelectors.enumerated() {
                let lessonsForDay = try document.select(daySelector).select("td").map { try $0.text() }

                var dailyLessons: [Lesson] = []

                for (i, lessonData) in lessonsForDay.enumerated() {
                    let cleanedData = lessonData.trimmingCharacters(in: .whitespacesAndNewlines)

                    // Фильтруем пустые строки и ненужные заголовки
                    if cleanedData.isEmpty { continue }
                    
                    // Проверяем, содержит ли урок только тире или похожие символы
                    let trimmedData = cleanedData.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedData == "-" || trimmedData == "—" || trimmedData == "–" || 
                       trimmedData.hasPrefix("-") || trimmedData.hasPrefix("—") || trimmedData.hasPrefix("–") ||
                       trimmedData.hasSuffix("-") || trimmedData.hasSuffix("—") || trimmedData.hasSuffix("–") {
                        continue
                    }
                    
                    let invalidPatterns = ["№1", "Время", "Кабинет неизвестен", "Пнд", "Втр", "Срд", "Чтв", "Птн", "Сбт", ""]
                    if invalidPatterns.contains(where: { cleanedData.contains($0) }) {
                        continue
                    }

                    let parsedLesson = parseLesson(cleanedData)

                    // Пропускаем уроки с пустыми предметами
                    if parsedLesson.subject.isEmpty { continue }

                    // Если времени для текущей пары нет, пропускаем эту пару
                    guard i < lessonTimes.count else { continue }
                    let lessonTime = lessonTimes[i]
                    let lessonNumber = getLessonNumber(for: lessonTime, timeSlots: timeSlots)

                    let lesson = Lesson(
                        number: lessonNumber,
                        time: lessonTime,
                        subject: parsedLesson.subject,
                        teacher: parsedLesson.teacher,
                        room: parsedLesson.room,
                        type: parsedLesson.type,
                        color: getColor(for: lessonNumber)
                    )
                    dailyLessons.append(lesson)
                }

                if !dailyLessons.isEmpty {
                    let daySchedule = DaySchedule(
                        day: daysOfWeek[index],
                        date: weekDates[index],
                        lessons: dailyLessons
                    )
                    parsedSchedule.append(daySchedule)
                } else {
                    // Если в дне нет уроков, добавляем день выходного
                    let daySchedule = DaySchedule(
                        day: daysOfWeek[index],
                        date: weekDates[index],
                        lessons: [Lesson(
                            number: 0,
                            time: "",
                            subject: "Сегодня выходной. Наслаждайтесь отдыхом!",
                            teacher: "",
                            room: "",
                            type: "",
                            color: .systemGray
                        )]
                    )
                    parsedSchedule.append(daySchedule)
                }
            }
        } catch {
            print("Error parsing week: \(error)")
        }

        return parsedSchedule
    }

    // MARK: - Mapping REST → UI-модели
    private func mapAPIScheduleToWeek(_ items: [APIScheduleItem]) -> [DaySchedule] {
        let daysOrder: [String] = ["Понедельник","Вторник","Среда","Четверг","Пятница","Суббота","Воскресенье"]
        let weekDates = calculateWeekDates()
        var byDay: [String: [APIScheduleItem]] = [:]
        for item in items { byDay[item.dayWeek, default: []].append(item) }
        var result: [DaySchedule] = []
        for (idx, day) in daysOrder.enumerated() {
            let dayItems = byDay[day] ?? []
            if dayItems.isEmpty {
                let placeholder = DaySchedule(
                    day: day,
                    date: weekDates[idx],
                    lessons: [Lesson(
                        number: 0,
                        time: "",
                        subject: "Сегодня выходной. Наслаждайтесь отдыхом!",
                        teacher: "",
                        room: "",
                        type: "",
                        color: .systemGray,
                        eiosLink: nil
                    )]
                )
                result.append(placeholder)
                continue
            }
            
            // Группируем занятия по времени для объединения групп (нормализуем «13.10» → «13:10»)
            let groupedByTime = Dictionary(grouping: dayItems) { APIScheduleItem.normalizeDottedTimePeriod($0.timePeriod) }
            
            // Сортируем временные слоты по времени начала, чтобы пары шли по порядку
            let sortedTimePeriods = groupedByTime.keys.sorted { lhs, rhs in
                guard let leftDate = startTimeDate(from: lhs),
                      let rightDate = startTimeDate(from: rhs) else {
                    // Если не удаётся распарсить время, оставляем относительный порядок строк
                    return lhs < rhs
                }
                return leftDate < rightDate
            }
            
            let lessons: [Lesson] = sortedTimePeriods.enumerated().compactMap { (index, timePeriod) in
                guard let itemsAtTime = groupedByTime[timePeriod], !itemsAtTime.isEmpty else {
                    return nil
                }
                
                let number = index + 1
                
                // Объединяем группы через запятую
                let groupNames = itemsAtTime.map { $0.group.name }.joined(separator: ", ")
                
                // Берем данные из первого элемента (они должны быть одинаковыми для одного времени)
                guard let firstItem = itemsAtTime.first else { return nil }
                
                // Объединяем аудитории, но если они одинаковые - показываем только один раз
                let rooms = itemsAtTime.compactMap { $0.auditory }.filter { !$0.isEmpty }
                let room = Set(rooms).joined(separator: ", ")
                
                return Lesson(
                    number: number,
                    time: timePeriod,
                    subject: firstItem.lessonName,
                    teacher: groupNames,
                    room: room,
                    type: firstItem.lessonType,
                    color: getColor(for: number),
                    eiosLink: firstItem.eiosLink
                )
            }
            result.append(DaySchedule(day: day, date: weekDates[idx], lessons: lessons))
        }
        return result
    }
    
    /// Возвращает дату, построенную только из времени начала интервала вида "HH:mm-HH:mm" (API может отдать "13.10-14.40").
    private func startTimeDate(from timePeriod: String) -> Date? {
        let normalized = APIScheduleItem.normalizeDottedTimePeriod(timePeriod)
        let components = normalized.split(separator: "-")
        guard let startComponent = components.first else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ru_RU")

        return formatter.date(from: String(startComponent))
    }

    // Функция для получения номера пары по времени
    func getLessonNumber(for time: String, timeSlots: [(start: String, end: String)]) -> Int {
        // Мы больше не используем сравнение с точным временем, а просто проверяем, какой интервал подходит
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"

        for (index, slot) in timeSlots.enumerated() {
            // Сравниваем с заданными интервалами
            if time.contains(slot.start) || time.contains(slot.end) {
                return index + 1 // Нумерация с 1
            }
        }

        return 0 // Если не попадает в интервал, возвращаем 0 (ошибка)
    }

    func parseLesson(_ lessonData: String) -> (subject: String, teacher: String, room: String, type: String) {
        // Регулярное выражение для кабинета (например, "1-109" или "с/зал")
        let regexForRoom = #"[0-9]+-[0-9]+[а-яА-Я]?|с/зал"#

        // Найти кабинет
        let roomMatch = lessonData.range(of: regexForRoom, options: .regularExpression)
        var room = roomMatch != nil ? String(lessonData[roomMatch!]) : "Кабинет неизвестен"

        // Убрать кабинет из строки
        var cleanedData = lessonData
        if let roomRange = roomMatch {
            cleanedData.removeSubrange(roomRange)
        }

        // Удаляем лишние пробелы и невидимые символы
        cleanedData = cleanedData.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanedData = cleanedData.replacingOccurrences(of: "\u{00A0}", with: " ") // Удаляем неразрывные пробелы

        // Убираем "пр." из названия предмета
        cleanedData = cleanedData.replacingOccurrences(of: "пр.", with: "")

        // Проверяем, есть ли "лаб." в начале строки
        var type = "Практика"
        if cleanedData.hasPrefix("лаб.") {
            type = "Лаборатория" // Устанавливаем тип занятия как "Лаборатория"
            cleanedData = cleanedData.replacingOccurrences(of: "лаб.", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        } else if cleanedData.contains("л.") {
            type = "Лекция"
            cleanedData = cleanedData.replacingOccurrences(of: "л.", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Попытка извлечь преподавателя в конце строки
        let teacherRegex = #"[А-ЯЁ][а-яё]+\s[А-ЯЁ]\.[А-ЯЁ]\."#
        var teacher = ""
        if let teacherRange = cleanedData.range(of: teacherRegex, options: .regularExpression) {
            teacher = String(cleanedData[teacherRange])
            cleanedData = cleanedData.replacingOccurrences(of: teacher, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Удаляем лишнюю точку, если она осталась в конце строки
        if cleanedData.hasSuffix(".") {
            cleanedData = String(cleanedData.dropLast())
        }

        // Проверяем, что предмет не является тире или пустой строкой
        let finalData = cleanedData.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalData.isEmpty || 
           finalData == "-" || finalData == "—" || finalData == "–" ||
           finalData.hasPrefix("-") || finalData.hasPrefix("—") || finalData.hasPrefix("–") ||
           finalData.hasSuffix("-") || finalData.hasSuffix("—") || finalData.hasSuffix("–") ||
           finalData.count <= 2 { // Если предмет слишком короткий (например, только тире)
            return (subject: "", teacher: "", room: "", type: "")
        }

        return (subject: cleanedData, teacher: teacher, room: room, type: type)
    }


    // Генерация цвета для урока
    func getColor(for number: Int) -> UIColor {
        let colors: [UIColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemTeal, .systemBlue, .systemPurple, .systemGray]
        return colors[number % colors.count]
    }
}
