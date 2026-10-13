//
//  SurveyManager.swift
//  Когда и кому показывать опрос: respondent, группа, лимиты (раз в сутки, «Не сейчас» на 3 дня).
//

import UIKit

final class SurveyManager {
    static let shared = SurveyManager()
    private init() {}

    private enum Keys {
        static let respondent = "surveys_respondent_id"
        static let lastCheck = "surveys_last_check_at"
        static let snoozedAt = "surveys_snoozed_at"
    }

    /// Проверять опросы не чаще раза в сутки
    private let checkInterval: TimeInterval = 24 * 60 * 60
    /// После «Не сейчас» не предлагать 3 дня
    private let snoozeInterval: TimeInterval = 3 * 24 * 60 * 60

    private var isChecking = false
    private var forceShownThisLaunch = false
    private var settingsOpenedThisLaunch = false

    // MARK: Кто отвечает

    /// `ios:<uuid установки>` — генерируется один раз и хранится в UserDefaults
    var respondent: String {
        if let override = SurveysDebug.respondentOverride { return override }
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: Keys.respondent), !saved.isEmpty { return saved }
        let id = "ios:" + UUID().uuidString.lowercased()
        defaults.set(id, forKey: Keys.respondent)
        return id
    }

    /// Выбранная группа студента; у преподавателя и без группы — nil
    var group: String? {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "isTeacherMode") { return nil }
        // В "selectedGroupURL" исторически хранится имя группы (см. ViewController / ScheduleStorage)
        guard let name = defaults.string(forKey: "selectedGroupURL")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty, !name.lowercased().hasPrefix("http") else { return nil }
        return name
    }

    // MARK: «Не сейчас»

    func snooze() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.snoozedAt)
    }

    private var isSnoozed: Bool {
        let at = UserDefaults.standard.double(forKey: Keys.snoozedAt)
        guard at > 0 else { return false }
        return Date().timeIntervalSince1970 - at < snoozeInterval
    }

    private var checkedRecently: Bool {
        let at = UserDefaults.standard.double(forKey: Keys.lastCheck)
        guard at > 0 else { return false }
        return Date().timeIntervalSince1970 - at < checkInterval
    }

    // MARK: Показ

    /// Вызывается при появлении главного экрана расписания
    func scheduleScreenDidAppear(from presenter: UIViewController) {
        #if DEBUG
        if SurveysDebug.openSettings && !settingsOpenedThisLaunch {
            settingsOpenedThisLaunch = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak presenter] in
                presenter?.navigationController?.pushViewController(SettingsViewController(), animated: true)
            }
            return
        }
        #endif
        if SurveysDebug.force && !forceShownThisLaunch {
            forceShownThisLaunch = true
            // Даём сплэшу и переходу закончиться
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak presenter] in
                guard let presenter = presenter else { return }
                self.presentSheet(quiz: nil, from: presenter, automatic: false)
            }
            return
        }
        guard !isChecking, !checkedRecently, !isSnoozed else { return }
        isChecking = true
        QuizAPIClient.shared.search(group: group, respondent: respondent) { [weak self, weak presenter] result in
            guard let self = self else { return }
            self.isChecking = false
            guard case .success(let quizzes) = result else { return } // ошибка — попробуем при следующем появлении
            if let quiz = quizzes.first {
                // Экран занят другим окном — не отмечаем проверку, предложим при следующем появлении
                guard let presenter = presenter, self.presentSheet(quiz: quiz, from: presenter, automatic: true) else { return }
            }
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.lastCheck)
        }
    }

    /// Пункт «Оставить отзыв» в настройках: загрузить и открыть текущий опрос
    func openFromSettings(from presenter: UIViewController) {
        presentSheet(quiz: nil, from: presenter, automatic: false)
    }

    /// quiz == nil — лист сам загрузит текущий опрос (и покажет «Сейчас опросов нет»)
    @discardableResult
    private func presentSheet(quiz: Quiz?, from presenter: UIViewController, automatic: Bool) -> Bool {
        let top = topViewController(from: presenter)
        // Автоматический показ не перебивает другие модальные окна и уход с экрана
        if automatic && (top !== presenter || presenter.view.window == nil) {
            return false
        }
        let vc = SurveySheetViewController(quiz: quiz, automatic: automatic)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *), let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            sheet.preferredCornerRadius = 20
        }
        nav.presentationController?.delegate = vc
        top.present(nav, animated: true)
        return true
    }

    private func topViewController(from vc: UIViewController) -> UIViewController {
        var top = vc
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
