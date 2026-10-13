//
//  QuizAPIClient.swift
//  Опросы обратной связи: клиент /api/v1/quizzes/** бэкенда расписания.
//  Тот же сервер и токен, что у ScheduleAPIClient (schedule_server_url / schedule_api_token).
//

import Foundation

// MARK: - Модели (контракт CONTRACT.md)

struct QuizAnswerOption: Codable, Equatable {
    let id: Int
    let label: String
}

enum QuizQuestionType: String {
    case single = "SINGLE"
    case multiple = "MULTIPLE"
    case text = "TEXT"
    case rating = "RATING"
}

struct QuizQuestion: Codable {
    let id: Int
    let label: String
    let description: String?
    let type: String
    let required: Bool?
    let scale: Int?
    let answers: [QuizAnswerOption]?

    var questionType: QuizQuestionType? { QuizQuestionType(rawValue: type.uppercased()) }
    var isRequired: Bool { required ?? false }
    /// Верх шкалы оценки: по умолчанию 5, разумные границы 2…10
    var ratingScale: Int { min(max(scale ?? 5, 2), 10) }
    var options: [QuizAnswerOption] { answers ?? [] }
}

struct Quiz: Codable {
    let id: Int
    let name: String
    let description: String?
    let completionMessage: String?
    let status: String?
    let groups: [String]?
    let questions: [QuizQuestion]
    let startDate: String?
    let endDate: String?
    /// null — один раз, "monthly" — раз в месяц
    let recurrence: String?
    /// Для monthly — текущий месяц "2026-10", иначе null
    let period: String?

    /// Вопросы известных типов (неизвестные новым бэкендом типы не ломают форму)
    var supportedQuestions: [QuizQuestion] { questions.filter { $0.questionType != nil } }
}

struct QuizzesResponse: Codable {
    let quizzes: [Quiz]
}

struct QuizSubmitUnit: Codable {
    let questionId: Int
    let answerId: Int?
    let value: String?
}

struct QuizSubmitRequest: Codable {
    let quizId: Int
    let respondent: String
    let group: String?
    let answers: [QuizSubmitUnit]
}

struct QuizSubmitResponse: Codable {
    let quizId: Int?
    let message: String?
}

/// Ошибка API опросов: текст для пользователя уже готов
struct QuizAPIError: LocalizedError {
    let statusCode: Int?
    let message: String
    var errorDescription: String? { message }
    /// 409 — на опрос уже ответили (в этом месяце для monthly)
    var isAlreadyAnswered: Bool { statusCode == 409 }
}

// MARK: - Отладочные переопределения (только DEBUG)

enum SurveysDebug {
    /// Базовый URL опросов: `-surveysBaseURL http://localhost:8080` или env SURVEYS_BASE_URL
    static var baseURLOverride: URL? {
        #if DEBUG
        let raw = UserDefaults.standard.string(forKey: "surveysBaseURL")
            ?? ProcessInfo.processInfo.environment["SURVEYS_BASE_URL"]
        if let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty, let url = URL(string: raw) {
            return url
        }
        #endif
        return nil
    }

    /// Токен стенда: `-surveysToken <токен>` или env SURVEYS_TOKEN
    static var tokenOverride: String? {
        #if DEBUG
        let raw = UserDefaults.standard.string(forKey: "surveysToken")
            ?? ProcessInfo.processInfo.environment["SURVEYS_TOKEN"]
        if let raw = raw, !raw.isEmpty { return raw }
        #endif
        return nil
    }

    /// `-surveysForce` (или `-surveysForce YES`, env SURVEYS_FORCE=1): показать лист сразу, без лимитов
    static var force: Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-surveysForce") {
            // Флаг без значения или со значением YES/true/1
            let next = i + 1 < args.count ? args[i + 1].lowercased() : ""
            return next.isEmpty || next.hasPrefix("-") || ["yes", "true", "1"].contains(next)
        }
        if let env = ProcessInfo.processInfo.environment["SURVEYS_FORCE"], ["1", "yes", "true"].contains(env.lowercased()) {
            return true
        }
        #endif
        return false
    }
}

// MARK: - Клиент

final class QuizAPIClient {
    static let shared = QuizAPIClient()
    private init() {}

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    private var baseURL: URL {
        if let override = SurveysDebug.baseURLOverride { return override }
        if let urlString = UserDefaults.standard.string(forKey: "schedule_server_url"),
           !urlString.isEmpty, let url = URL(string: urlString) {
            return url
        }
        return URL(string: "https://api.myimsit.ru/schedule")!
    }

    private var authToken: String? {
        SurveysDebug.tokenOverride ?? UserDefaults.standard.string(forKey: "schedule_api_token")
    }

    private func makeRequest(path: String, method: String = "GET", queryItems: [URLQueryItem] = [], body: Data? = nil) throws -> URLRequest {
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard var components = URLComponents(url: baseURL.appendingPathComponent(cleanPath), resolvingAgainstBaseURL: false) else {
            throw QuizAPIError(statusCode: nil, message: "Неверный адрес сервера")
        }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else { throw QuizAPIError(statusCode: nil, message: "Неверный адрес сервера") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        if let token = authToken, !token.isEmpty {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            request.httpBody = body
            request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    /// Выполняет запрос, декодирует ответ; ошибки HTTP превращает в текст из тела.
    /// completion всегда вызывается на главном потоке.
    private func perform<T: Decodable>(_ request: URLRequest, as type: T.Type, completion: @escaping (Result<T, Error>) -> Void) {
        #if DEBUG
        print("📝 [Опросы] \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
        #endif
        session.dataTask(with: request) { data, response, error in
            let finish: (Result<T, Error>) -> Void = { result in DispatchQueue.main.async { completion(result) } }
            if let error = error {
                finish(.failure(QuizAPIError(statusCode: nil, message: "Нет связи с сервером. Проверьте интернет и попробуйте ещё раз.")))
                #if DEBUG
                print("📝 [Опросы] сеть: \(error.localizedDescription)")
                #endif
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let data = data ?? Data()
            guard (200..<300).contains(status) else {
                finish(.failure(QuizAPIError(statusCode: status, message: Self.errorMessage(from: data, status: status))))
                return
            }
            do {
                finish(.success(try JSONDecoder().decode(T.self, from: data)))
            } catch {
                #if DEBUG
                print("📝 [Опросы] декодирование: \(error)")
                #endif
                finish(.failure(QuizAPIError(statusCode: status, message: "Не удалось прочитать ответ сервера")))
            }
        }.resume()
    }

    /// Текст ошибки: поле message из JSON ({"status","message"}) или тело как есть
    private static func errorMessage(from data: Data, status: Int) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["message", "error", "detail"] {
                if let text = obj[key] as? String, !text.isEmpty { return text }
            }
        }
        if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty, text.count < 500, !text.hasPrefix("<") {
            return text
        }
        switch status {
        case 409: return "Вы уже прошли этот опрос"
        case 401, 403: return "Нет доступа к опросам"
        case 404: return "Опрос не найден"
        default: return "Ошибка сервера (\(status))"
        }
    }

    // MARK: API

    /// Открытые опросы для респондента (и группы, если она есть)
    func search(group: String?, respondent: String, completion: @escaping (Result<[Quiz], Error>) -> Void) {
        var items = [URLQueryItem(name: "respondent", value: respondent)]
        if let group = group, !group.isEmpty { items.append(URLQueryItem(name: "group", value: group)) }
        do {
            let request = try makeRequest(path: "/api/v1/quizzes/search", queryItems: items)
            perform(request, as: QuizzesResponse.self) { result in
                completion(result.map { $0.quizzes.filter { !$0.supportedQuestions.isEmpty } })
            }
        } catch { completion(.failure(error)) }
    }

    func quiz(id: Int, completion: @escaping (Result<Quiz, Error>) -> Void) {
        do {
            let request = try makeRequest(path: "/api/v1/quizzes/\(id)")
            perform(request, as: Quiz.self, completion: completion)
        } catch { completion(.failure(error)) }
    }

    func submit(_ submit: QuizSubmitRequest, completion: @escaping (Result<QuizSubmitResponse, Error>) -> Void) {
        do {
            let body = try JSONEncoder().encode(submit)
            let request = try makeRequest(path: "/api/v1/quizzes/submit", method: "POST", body: body)
            perform(request, as: QuizSubmitResponse.self, completion: completion)
        } catch { completion(.failure(error)) }
    }
}
