//
//  AppDelegate.swift
//  test111
//
//  Created by Дмитрий Цепилов on 02.12.2024.
//

import UIKit
import UserNotifications
import MyTrackerSDK
// Remote Config bootstrap


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    // Для iOS 13+ окно управляется через SceneDelegate
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Инициализация MyTracker
        let trackerConfig = MRMyTracker.trackerConfig()
        MRMyTracker.setupTracker("38724970655771308499")
        
        // Warm-up Remote Config
        RemoteConfigService.shared.start(appID: "c27a358e-55bb-42c0-b46f-be02a75b1033")
        
        // Настройка уведомлений
        setupNotifications()
        
        // Настройка Background Fetch
        setupBackgroundFetch(application)
        
        // Установка токена API (если ещё не задан) и проверка наличия
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: "schedule_api_token"), !existing.isEmpty {
            // уже есть валидный токен в кеше
        } else {
            // РЕЗЕРВ: ставим дефолтный токен, чтобы приложение работало до прихода RC
            defaults.set("SwzrtTV34nPZdTnTM73Gw/lOas2729/rpy4pJyupMy6QkxC1BfFqyZL2sUdNV0U8", forKey: "schedule_api_token")
        }
        if let token = defaults.string(forKey: "schedule_api_token"), !token.isEmpty {
            let masked = token.count <= 6 ? String(repeating: "*", count: token.count) : String(token.prefix(3)) + String(repeating: "*", count: max(0, token.count - 6)) + String(token.suffix(3))
            print("🔑 API токен найден (schedule_api_token): \(masked)")
        } else {
            print("⚠️ API токен не найден. Ожидаем Remote Config 'ScheduleServiceAccessToken'.")
        }
        
        // Пытаемся сразу подтянуть значения из RC и перезаписать токен, когда он появится
        RemoteConfigService.shared.refreshNow { adsEnabled, tokenExists in
            print("RC обновлён: ads=\(adsEnabled), tokenExists=\(tokenExists)")
        }
        
        // Проверка обновлений (с небольшой задержкой, чтобы не мешать запуску)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            AppUpdateChecker.shared.checkForUpdate()
        }
        
        return true
    }
    
    private func setupNotifications() {
        let notificationManager = NotificationManager.shared
        notificationManager.setupDefaultSettings()
        
        #if DEBUG
        // Демонстрация опросов: системный запрос поверх листа мешает снимкам экрана
        if SurveysDebug.isDemoLaunch { return }
        #endif

        // Запрашиваем разрешение на уведомления при первом запуске
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                notificationManager.requestNotificationPermission { _ in }
            }
        }
    }
    
    private func setupBackgroundFetch(_ application: UIApplication) {
        // Регистрируем Background Fetch с минимальным интервалом
        // iOS будет вызывать его в оптимальное время, но мы добавим логику для понедельника утра
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        
        // Также можно попробовать установить более частый интервал для понедельника
        // Но iOS может ограничить частоту выполнения
        print("🔄 Background Fetch настроен для выполнения в понедельник утром")
    }
    
    // Background Fetch обработчик
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        let notificationManager = NotificationManager.shared
        
        // Проверяем, включены ли уведомления
        guard notificationManager.isNotificationsEnabled else {
            completionHandler(.noData)
            return
        }
        
        // Проверяем, есть ли сохраненное расписание
        let isTeacherMode = UserDefaults.standard.bool(forKey: "isTeacherMode")
        let hasSchedule = isTeacherMode ? 
            UserDefaults.standard.string(forKey: "selectedTeacherURL") != nil :
            UserDefaults.standard.string(forKey: "selectedGroupURL") != nil
        
        guard hasSchedule else {
            completionHandler(.noData)
            return
        }
        
        // Проверяем, понедельник ли сегодня
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let hour = calendar.component(.hour, from: today)
        let isMonday = weekday == 2 // 2 = понедельник
        let isEarlyMorning = hour >= 5 && hour <= 6 // Раннее утро: 5-6 часов
        
        if isMonday && isEarlyMorning {
            print("🔄 Background Fetch: понедельник утром (\(hour):00), обновляем уведомления на новую неделю")
            
            // Загружаем актуальное расписание и перепланируем уведомления
            loadScheduleAndRescheduleNotifications(isTeacherMode: isTeacherMode) { success in
                if success {
                    print("✅ Background Fetch: уведомления успешно обновлены")
                    completionHandler(.newData)
                } else {
                    print("❌ Background Fetch: ошибка обновления уведомлений")
                    completionHandler(.failed)
                }
            }
        } else if isMonday {
            print("ℹ️ Background Fetch: понедельник, но не утро (\(hour):00), пропускаем")
            completionHandler(.noData)
        } else {
            print("ℹ️ Background Fetch: не понедельник (день недели: \(weekday)), пропускаем обновление")
            completionHandler(.noData)
        }
    }
    
    private func loadScheduleAndRescheduleNotifications(isTeacherMode: Bool, completion: @escaping (Bool) -> Void) {
        // Получаем URL для загрузки расписания
        let urlString: String
        if isTeacherMode {
            guard let teacherURL = UserDefaults.standard.string(forKey: "selectedTeacherURL") else {
                completion(false)
                return
            }
            urlString = teacherURL
        } else {
            guard let groupURL = UserDefaults.standard.string(forKey: "selectedGroupURL") else {
                completion(false)
                return
            }
            urlString = groupURL
        }
        
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        // Загружаем расписание
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Background Fetch: ошибка загрузки расписания: \(error)")
                completion(false)
                return
            }
            
            guard let data = data else {
                print("❌ Background Fetch: нет данных")
                completion(false)
                return
            }
            
            // Пытаемся декодировать как UTF-8 или windows-1251
            let htmlString: String
            if let utf8String = String(data: data, encoding: .utf8) {
                htmlString = utf8String
            } else if let cp1251String = String(data: data, encoding: .windowsCP1251) {
                htmlString = cp1251String
            } else {
                print("❌ Background Fetch: ошибка кодировки")
                completion(false)
                return
            }
            
            // Парсим расписание
            self.parseScheduleInBackground(htmlString: htmlString, isTeacherMode: isTeacherMode) { success in
                completion(success)
            }
        }
        
        task.resume()
    }
    
    private func parseScheduleInBackground(htmlString: String, isTeacherMode: Bool, completion: @escaping (Bool) -> Void) {
        // Проверяем режим: уведомления только для студентов
        if isTeacherMode {
            print("ℹ️ Background Fetch: режим преподавателя, уведомления не планируются")
            completion(true)
            return
        }
        
        // Здесь нужно будет добавить логику парсинга HTML и создания расписания
        // Пока что используем сохраненное расписание для перепланирования
        
        if let scheduleData = UserDefaults.standard.data(forKey: "savedSchedule"),
           let schedule = try? JSONDecoder().decode([DaySchedule].self, from: scheduleData) {
            
            // Принудительно перепланируем уведомления на всю неделю (только для студентов)
            let notificationManager = NotificationManager.shared
            notificationManager.forceRescheduleNotificationsForWeek(schedule: schedule, isTeacherMode: false)
            completion(true)
        } else {
            print("❌ Background Fetch: нет сохраненного расписания")
            completion(false)
        }
    }
}

