//
//  ScheduleWidgetExtension.swift
//  ScheduleWidgetExtension
//
//  Created for Widget Extension
//

import WidgetKit
import SwiftUI
import UIKit

// MARK: - UIColor Extension for Widget
extension UIColor {
    convenience init(hex: String) {
        var hexFormatted = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).uppercased()

        if hexFormatted.hasPrefix("#") {
            hexFormatted = String(hexFormatted.dropFirst())
        }

        var rgbValue: UInt64 = 0
        Scanner(string: hexFormatted).scanHexInt64(&rgbValue)

        let red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgbValue & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

struct ScheduleWidgetExtension: Widget {
    let kind: String = "ScheduleWidgetExtension"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
            ScheduleWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackgroundView() }
        }
        .configurationDisplayName("Следующая пара")
        .description("Показывает следующую пару из вашего расписания")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(
            date: Date(),
            currentLesson: Lesson(
                number: 1,
                time: "08:00-09:30",
                subject: "Математика",
                teacher: "Иванов И.И.",
                room: "101",
                type: "Лекция",
                color: .systemBlue,
                eiosLink: nil
            ),
            nextLesson: Lesson(
                number: 2,
                time: "09:40-11:10",
                subject: "Программирование",
                teacher: "Петров П.П.",
                room: "205",
                type: "Практика",
                color: .systemGreen,
                eiosLink: nil
            ),
            dayName: "Понедельник",
            isWeekend: false,
            currentLessonProgress: 0.5,
            isNextLessonInAnotherDay: false,
            nextLessonDayName: nil,
            isTomorrowWeekend: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> ()) {
        let entry = getNextLesson(for: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> ()) {
        var entries: [ScheduleEntry] = []
        let calendar = Calendar.current
        let nowRaw = Date()
        // Нормализуем до минуты (без секунд), иначе в 18:00:00 может показываться entry от 17:59:30 → «95%»
        let now = calendar.date(bySettingHour: calendar.component(.hour, from: nowRaw),
                                minute: calendar.component(.minute, from: nowRaw),
                                second: 0,
                                of: nowRaw) ?? nowRaw
        
        // Создаём entries на каждую минуту следующего часа для плавного обновления прогресса
        for minuteOffset in 0..<60 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: now)!
            let entry = getNextLesson(for: entryDate)
            entries.append(entry)
        }
        
        // Следующее обновление через час
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }

    private func getNextLesson(for date: Date = Date()) -> ScheduleEntry {
        print("📅 Widget: getNextLesson() called at \(date)")
        
        // Загружаем расписание из общего хранилища
        let schedule = ScheduleStorage.loadSchedule()
        
        guard let schedule = schedule else {
            print("⚠️ Widget: No schedule available, returning empty entry")
            return ScheduleEntry(
                date: date,
                currentLesson: nil,
                nextLesson: nil,
                dayName: nil,
                isWeekend: false,
                currentLessonProgress: nil,
                isNextLessonInAnotherDay: false,
                nextLessonDayName: nil,
                isTomorrowWeekend: false
            )
        }
        
        print("📅 Widget: Processing schedule with \(schedule.count) days")
        
        let calendar = Calendar.current
        let now = date
        
        // Для заочного/сессионного расписания (есть isoDate) используем календарные даты,
        // а не индекс дня недели, иначе для данных на несколько недель время/день могут определяться неверно.
        if schedule.contains(where: { $0.isoDate != nil }) {
            if let sessionEntry = getSessionScheduleEntry(schedule: schedule, now: now, calendar: calendar) {
                return sessionEntry
            }
        }
        let currentWeekday = calendar.component(.weekday, from: now)
        
        // Преобразуем день недели: 1=воскресенье, 2=понедельник, ..., 7=суббота
        // В нашем расписании: 0=понедельник, 1=вторник, ..., 6=воскресенье
        let scheduleIndex: Int
        if currentWeekday == 1 { // Воскресенье
            scheduleIndex = 6
        } else {
            scheduleIndex = currentWeekday - 2 // Понедельник = 0
        }
        
        // Проверяем, является ли сегодня выходным днем
        if scheduleIndex < schedule.count {
            let todaySchedule = schedule[scheduleIndex]
            // Проверяем, есть ли только placeholder уроки (выходной день)
            let isTodayWeekend = !todaySchedule.lessons.isEmpty && 
                                 todaySchedule.lessons.allSatisfy { 
                                     $0.subject == "Сегодня выходной. Наслаждайтесь отдыхом!" 
                                 }
            
            if isTodayWeekend {
                return ScheduleEntry(
                    date: date,
                    currentLesson: nil,
                    nextLesson: nil,
                    dayName: todaySchedule.day,
                    isWeekend: true,
                    currentLessonProgress: nil,
                    isNextLessonInAnotherDay: false,
                    nextLessonDayName: nil,
                    isTomorrowWeekend: false
                )
            }
        }
        
        // Получаем текущее время
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentTimeMinutes = hour * 60 + minute
        
        print("🔎 Widget: Searching for current and next lessons. Schedule index today = \(scheduleIndex)")
        
        // Сначала ищем текущую пару сегодня
        var currentLesson: Lesson?
        var currentProgress: Double?
        
        if scheduleIndex < schedule.count {
            let todaySchedule = schedule[scheduleIndex]
            
            for lesson in todaySchedule.lessons {
                // Пропускаем placeholder уроки
                if lesson.subject == "Сегодня выходной. Наслаждайтесь отдыхом!" {
                    continue
                }
                
                // Парсим время начала и конца пары
                if let (startMinutes, endMinutes) = parseFullLessonTime(lesson.time) {
                    // Проверяем, идет ли пара сейчас
                    if currentTimeMinutes >= startMinutes && currentTimeMinutes < endMinutes {
                        currentLesson = lesson
                        // Вычисляем прогресс (от 0.0 до 1.0)
                        let duration = Double(endMinutes - startMinutes)
                        let elapsed = Double(currentTimeMinutes - startMinutes)
                        currentProgress = min(1.0, max(0.0, elapsed / duration))
                        print("✅ Widget: Current lesson found -> '\(lesson.subject)' progress: \(String(format: "%.1f%%", currentProgress! * 100))")
                        break
                    }
                }
            }
        }
        
        // Теперь ищем следующую пару
        var nextLesson: Lesson?
        var isNextInAnotherDay = false
        var nextLessonDayName: String?
        var daysUntilNextLesson: Int = 0
        
        // Сначала проверяем оставшиеся дни текущей недели
        for dayOffset in 0..<7 {
            let dayIndex = (scheduleIndex + dayOffset) % 7
            guard dayIndex < schedule.count else { continue }
            
            let daySchedule = schedule[dayIndex]
            let isToday = dayOffset == 0
            
            for lesson in daySchedule.lessons {
                // Пропускаем placeholder уроки
                if lesson.subject == "Сегодня выходной. Наслаждайтесь отдыхом!" {
                    continue
                }
                
                // Пропускаем текущую пару
                if let current = currentLesson, lesson.number == current.number && isToday {
                    continue
                }
                
                // Парсим время начала пары
                if let lessonTime = parseLessonTime(lesson.time) {
                    let lessonStartMinutes = lessonTime.hour * 60 + lessonTime.minute
                    
                    // Если это сегодня и пара еще не началась, или это будущий день
                    if (isToday && lessonStartMinutes > currentTimeMinutes) || !isToday {
                        nextLesson = lesson
                        isNextInAnotherDay = !isToday
                        daysUntilNextLesson = dayOffset
                        
                        // Определяем название дня: если завтра - "Завтра", иначе - день недели
                        if dayOffset == 1 {
                            nextLessonDayName = "Завтра"
                    } else {
                            nextLessonDayName = daySchedule.day
                        }
                        
                        print("✅ Widget: Next lesson found -> '\(lesson.subject)' at \(lesson.time) (another day: \(isNextInAnotherDay), day: \(daySchedule.day), days: \(dayOffset))")
                        break
                    }
                }
            }
            
            if nextLesson != nil {
                break
            }
        }
        
        // Если не нашли на текущей неделе, ищем на следующей неделе
        if nextLesson == nil {
            // Вычисляем количество дней до следующего понедельника
            // Если сегодня понедельник (0), то до следующего понедельника 7 дней
            // Если сегодня вторник (1), то до следующего понедельника 6 дней
            // И так далее: daysUntilNextMonday = 7 - scheduleIndex
            let daysUntilNextMonday = 7 - scheduleIndex
            
            for weekOffset in 1..<3 { // Проверяем до 2 недель вперед
                for dayOffset in 0..<7 {
                    let dayIndex = dayOffset // На следующей неделе начинаем с понедельника
                    guard dayIndex < schedule.count else { continue }
                    
                    let daySchedule = schedule[dayIndex]
                    
                    for lesson in daySchedule.lessons {
                        // Пропускаем placeholder уроки
                        if lesson.subject == "Сегодня выходной. Наслаждайтесь отдыхом!" {
                            continue
                        }
                        
                        // Парсим время начала пары
                        if let lessonTime = parseLessonTime(lesson.time) {
                            nextLesson = lesson
                            isNextInAnotherDay = true
                            // Правильно вычисляем дни: дни до следующего понедельника + дни на следующей неделе
                            daysUntilNextLesson = daysUntilNextMonday + (weekOffset - 1) * 7 + dayOffset
                            
                            // Определяем название дня: если завтра - "Завтра", иначе - день недели
                            if daysUntilNextLesson == 1 {
                                nextLessonDayName = "Завтра"
                } else {
                                nextLessonDayName = daySchedule.day
                            }
                            
                            print("✅ Widget: Next lesson found on next week -> '\(lesson.subject)' at \(lesson.time) (day: \(daySchedule.day), days: \(daysUntilNextLesson))")
                            break
                        }
                    }
                    
                    if nextLesson != nil {
                        break
                    }
                }
                
                if nextLesson != nil {
                    break
                }
            }
        }
        
        // Проверяем, выходной ли завтра (если следующая пара не завтра)
        var isTomorrowWeekend = false
        if nextLesson != nil && isNextInAnotherDay && daysUntilNextLesson > 1 {
            // Проверяем завтрашний день
            let tomorrowIndex = (scheduleIndex + 1) % 7
            if tomorrowIndex < schedule.count {
                let tomorrowSchedule = schedule[tomorrowIndex]
                // Проверяем, есть ли только placeholder уроки (выходной день)
                isTomorrowWeekend = tomorrowSchedule.lessons.isEmpty || 
                                    tomorrowSchedule.lessons.allSatisfy { 
                                        $0.subject == "Сегодня выходной. Наслаждайтесь отдыхом!" 
                                    }
            }
        }
        
        // Возвращаем результат
        return ScheduleEntry(
            date: date,
            currentLesson: currentLesson,
            nextLesson: nextLesson,
            dayName: scheduleIndex < schedule.count ? schedule[scheduleIndex].day : nil,
            isWeekend: false,
            currentLessonProgress: currentProgress,
            isNextLessonInAnotherDay: isNextInAnotherDay,
            nextLessonDayName: nextLessonDayName,
            isTomorrowWeekend: isTomorrowWeekend
        )
    }
    
    private func getSessionScheduleEntry(schedule: [DaySchedule], now: Date, calendar: Calendar) -> ScheduleEntry? {
        let iso = Self.isoDateFormatter
        let startToday = calendar.startOfDay(for: now)
        let todayISO = iso.string(from: startToday)
        
        // Ищем расписание на сегодня по календарной дате
        let todaySchedule = schedule.first { $0.isoDate == todayISO }
        
        let isTodayWeekend: Bool = {
            guard let day = todaySchedule else { return true }
            return day.lessons.isEmpty || day.lessons.allSatisfy { $0.subject == "Сегодня выходной. Наслаждайтесь отдыхом!" }
        }()
        
        // Собираем все занятия с реальными календарными datetime
        var timedLessons: [(lesson: Lesson, dayName: String, start: Date, end: Date)] = []
        for day in schedule {
            guard let isoDate = day.isoDate,
                  let dayDate = iso.date(from: isoDate) else { continue }
            let dayStart = calendar.startOfDay(for: dayDate)
            for lesson in day.lessons {
                if lesson.subject == "Сегодня выходной. Наслаждайтесь отдыхом!" { continue }
                guard let (startMin, endMin) = parseFullLessonTime(lesson.time),
                      let startDate = calendar.date(byAdding: .minute, value: startMin, to: dayStart),
                      let endDate = calendar.date(byAdding: .minute, value: endMin, to: dayStart) else { continue }
                timedLessons.append((lesson: lesson, dayName: day.day, start: startDate, end: endDate))
            }
        }
        timedLessons.sort { $0.start < $1.start }
        
        var currentLesson: Lesson?
        var currentProgress: Double?
        if let current = timedLessons.first(where: { $0.start <= now && now < $0.end }) {
            currentLesson = current.lesson
            let duration = current.end.timeIntervalSince(current.start)
            let elapsed = now.timeIntervalSince(current.start)
            if duration > 0 {
                currentProgress = min(1.0, max(0.0, elapsed / duration))
            }
        }
        
        let next = timedLessons.first(where: { $0.start > now })
        let nextLesson = next?.lesson
        let isNextInAnotherDay = next.map { !calendar.isDate($0.start, inSameDayAs: now) } ?? false
        let nextLessonDayName: String? = {
            guard let n = next else { return nil }
            let days = calendar.dateComponents([.day], from: startToday, to: calendar.startOfDay(for: n.start)).day ?? 0
            if days == 1 { return "Завтра" }
            return n.dayName
        }()
        
        // Проверяем, выходной ли завтра (для UI бейджа)
        var isTomorrowWeekend = false
        if let n = next {
            let days = calendar.dateComponents([.day], from: startToday, to: calendar.startOfDay(for: n.start)).day ?? 0
            if days > 1, let tomorrow = calendar.date(byAdding: .day, value: 1, to: startToday) {
                let tomorrowISO = iso.string(from: tomorrow)
                let tomorrowSchedule = schedule.first { $0.isoDate == tomorrowISO }
                isTomorrowWeekend = tomorrowSchedule == nil || (tomorrowSchedule?.lessons.isEmpty ?? true) ||
                (tomorrowSchedule?.lessons.allSatisfy { $0.subject == "Сегодня выходной. Наслаждайтесь отдыхом!" } ?? true)
            }
        }
        
        return ScheduleEntry(
            date: now,
            currentLesson: currentLesson,
            nextLesson: nextLesson,
            dayName: todaySchedule?.day,
            isWeekend: isTodayWeekend,
            currentLessonProgress: currentProgress,
            isNextLessonInAnotherDay: isNextInAnotherDay,
            nextLessonDayName: nextLessonDayName,
            isTomorrowWeekend: isTomorrowWeekend
        )
    }
    
    private func parseFullLessonTime(_ timeString: String) -> (start: Int, end: Int)? {
        // Форматы времени: "08:00-09:30", "08.00-09.30"
        var raw = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
        raw = raw.replacingOccurrences(of: ".", with: ":")
        
        let separators: [Character] = ["-", "–", "—", "―"]
        guard let separatorChar = separators.first(where: { raw.contains($0) }),
              let separatorIndex = raw.firstIndex(of: separatorChar) else {
            return nil
        }
        
        let startStr = String(raw[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let endStr = String(raw[raw.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        let startComponents = startStr.split(separator: ":")
        let endComponents = endStr.split(separator: ":")
        
        guard startComponents.count == 2, endComponents.count == 2,
              let startHour = Int(startComponents[0]),
              let startMinute = Int(startComponents[1]),
              let endHour = Int(endComponents[0]),
              let endMinute = Int(endComponents[1]) else {
            return nil
        }
        
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        
        return (startMinutes, endMinutes)
    }
    
    private func parseLessonTime(_ timeString: String) -> (hour: Int, minute: Int)? {
        // Форматы времени: "08:00-09:30", "08.00-09.30", "08:00 – 09:30", "08:00"
        let separators: [Character] = ["-", "–", "—", "―"]
        var raw = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return nil }
        
        // Заменяем точки на двоеточия, так как в расписании время приходит вида "13.10-14.40"
        raw = raw.replacingOccurrences(of: ".", with: ":")
        
        // Находим первую часть времени до разделителя
        if let separatorChar = separators.first(where: { raw.contains($0) }) {
            if let separatorIndex = raw.firstIndex(of: separatorChar) {
                raw = String(raw[..<separatorIndex])
            }
        }
        
        // Убираем лишние слова/символы (например, "08:00 " или "08:00 ")
        raw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Извлекаем цифры времени
        let components = raw.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0].trimmingCharacters(in: .whitespaces)),
              let minute = Int(components[1].trimmingCharacters(in: .whitespaces)) else {
            print("⚠️ Widget: Failed to parse time string '\(timeString)' -> '\(raw)'")
            return nil
        }
        
        return (hour: hour, minute: minute)
    }
    
    private static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

struct ScheduleEntry: TimelineEntry {
    let date: Date
    let currentLesson: Lesson?
    let nextLesson: Lesson?
    let dayName: String?
    let isWeekend: Bool
    let currentLessonProgress: Double? // Прогресс текущей пары (0.0 - 1.0)
    let isNextLessonInAnotherDay: Bool // Следующая пара в другой день
    let nextLessonDayName: String? // Название дня следующей пары
    let isTomorrowWeekend: Bool // Завтра выходной (нет пар)
}

struct ScheduleWidgetEntryView: View {
    var entry: ScheduleProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemMedium:
            TimelineWidgetView(entry: entry, isMedium: true)
        default:
            TimelineWidgetView(entry: entry, isMedium: false)
        }
    }
}

// MARK: - Новый дизайн (Widget.dc.html): таймлайн «сейчас → следующая»

/// Палитра виджета: светлая и тёмная (look light / dark)
private struct WidgetPalette {
    let fg: Color
    let soft: Color
    let track: Color
    let accent: Color
    let nodeBg: Color
    let mute: Color
    let rail: [Color]

    static func of(_ scheme: ColorScheme) -> WidgetPalette {
        if scheme == .dark {
            return WidgetPalette(fg: Color(hex6: 0xF1F5F9), soft: Color(hex6: 0xA3AEC2), track: Color(hex6: 0x94A3B8).opacity(0.22),
                                 accent: Color(hex6: 0x60A5FA), nodeBg: Color(hex6: 0x1B2540), mute: Color(hex6: 0x475569),
                                 rail: [Color(hex6: 0x3B82F6), Color(hex6: 0x38BDF8)])
        }
        return WidgetPalette(fg: Color(hex6: 0x0F172A), soft: Color(hex6: 0x64748B), track: Color(hex6: 0xE2E8F0),
                             accent: Color(hex6: 0x1A4FDB), nodeBg: .white, mute: Color(hex6: 0xCBD5E1),
                             rail: [Color(hex6: 0x1A4FDB), Color(hex6: 0x0EA5E9)])
    }
}

private extension Color {
    init(hex6: UInt32) {
        self.init(red: Double((hex6 >> 16) & 0xFF) / 255, green: Double((hex6 >> 8) & 0xFF) / 255, blue: Double(hex6 & 0xFF) / 255)
    }
}

struct WidgetBackgroundView: View {
    @Environment(\.colorScheme) var scheme

    var body: some View {
        if scheme == .dark {
            LinearGradient(colors: [Color(hex6: 0x1B2540), Color(hex6: 0x121A2E)], startPoint: .top, endPoint: .bottom)
        } else {
            Color.white
        }
    }
}

/// Один блок таймлайна
private struct TimelineBlock {
    enum Node { case live, next, past }
    let label: String
    let subject: String
    let who: String
    let time: String
    let room: String
    let meta: String?
    let node: Node
    let progress: Double?
}

struct TimelineWidgetView: View {
    let entry: ScheduleEntry
    let isMedium: Bool
    @Environment(\.colorScheme) var scheme

    private var palette: WidgetPalette { WidgetPalette.of(scheme) }

    var body: some View {
        let blocks = makeBlocks()
        ZStack(alignment: .topLeading) {
            // Рельс таймлайна
            LinearGradient(colors: palette.rail, startPoint: .top, endPoint: .bottom)
                .frame(width: 3)
                .frame(maxHeight: .infinity)
                .padding(.leading, isMedium ? 1 : 0)
                .padding(.vertical, -40)

            if blocks.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("НЕТ РАСПИСАНИЯ")
                        .font(.system(size: 10, weight: .bold))
                        .kerning(0.8)
                        .foregroundColor(palette.soft)
                    Text("Откройте приложение и выберите группу")
                        .font(.system(size: isMedium ? 15 : 13, weight: .heavy))
                        .foregroundColor(palette.fg)
                        .lineLimit(3)
                }
                .padding(.leading, isMedium ? 19 : 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                        if index > 0 { Spacer(minLength: 4) }
                        blockView(block, full: index == 0)
                    }
                }
                .padding(.leading, isMedium ? 19 : 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.leading, isMedium ? 1 : 0)
    }

    // MARK: Блок

    @ViewBuilder
    private func blockView(_ block: TimelineBlock, full: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                if isMedium {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(block.subject)
                            .font(.system(size: 15.5, weight: .heavy))
                            .foregroundColor(palette.fg)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(block.label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(block.node == .live ? palette.accent : palette.soft)
                            .lineLimit(1)
                            .layoutPriority(1)
                    }
                    if let meta = block.meta {
                        Text(meta)
                            .font(.system(size: 12))
                            .foregroundColor(palette.soft)
                            .lineLimit(1)
                            .padding(.top, 2)
                    } else if full {
                        if !block.who.isEmpty {
                            iconLine("person", block.who)
                                .padding(.top, 2)
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "clock").font(.system(size: 10, weight: .semibold)).foregroundColor(palette.accent)
                            Text(block.time).font(.system(size: 12, design: .monospaced)).foregroundColor(palette.soft)
                            if !block.room.isEmpty {
                                Image(systemName: "door.left.hand.open").font(.system(size: 10, weight: .semibold)).foregroundColor(palette.accent).padding(.leading, 6)
                                Text(block.room).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(palette.fg)
                            }
                        }
                        .lineLimit(1)
                        if let progress = block.progress { progressBar(progress).padding(.top, 5) }
                    } else {
                        Text([block.who, block.time, block.room].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.system(size: 12))
                            .foregroundColor(palette.soft)
                            .lineLimit(1)
                            .padding(.top, 2)
                    }
                } else {
                    Text(block.label.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .kerning(0.8)
                        .foregroundColor(block.node == .live ? palette.accent : palette.soft)
                        .lineLimit(1)
                    Text(block.subject)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(palette.fg)
                        .lineLimit(full ? 2 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                    if let meta = block.meta {
                        Text(meta)
                            .font(.system(size: 11))
                            .foregroundColor(palette.soft)
                            .lineLimit(1)
                    } else {
                        (Text(block.room).font(.system(size: 10.5, weight: .bold, design: .monospaced)).foregroundColor(palette.fg)
                         + Text(block.room.isEmpty ? block.time : " · " + block.time).font(.system(size: 10.5, design: .monospaced)).foregroundColor(palette.soft))
                            .lineLimit(1)
                    }
                    if full, let progress = block.progress { progressBar(progress).padding(.top, 3) }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            nodeView(block.node)
                .offset(x: isMedium ? -18.5 - nodeSize(block.node) / 2 : -14.5 - nodeSize(block.node) / 2,
                        y: (isMedium ? 10 : 7) - nodeSize(block.node) / 2)
        }
    }

    private func iconLine(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 10, weight: .semibold)).foregroundColor(palette.accent)
            Text(text).font(.system(size: 12)).foregroundColor(palette.soft).lineLimit(1)
        }
    }

    private func progressBar(_ value: Double) -> some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.track)
                    Capsule().fill(LinearGradient(colors: palette.rail, startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, geo.size.width * CGFloat(min(max(value, 0), 1))))
                }
            }
            .frame(height: 4)
            Text("\(Int((value * 100).rounded()))%")
                .font(.system(size: isMedium ? 10 : 9.5, design: .monospaced))
                .foregroundColor(palette.soft)
        }
    }

    private func nodeSize(_ node: TimelineBlock.Node) -> CGFloat {
        switch node {
        case .live: return 13
        case .next: return 11
        case .past: return 7
        }
    }

    @ViewBuilder
    private func nodeView(_ node: TimelineBlock.Node) -> some View {
        switch node {
        case .live:
            Circle()
                .fill(Color.white)
                .overlay(Circle().stroke(palette.accent, lineWidth: 3))
                .frame(width: 13, height: 13)
                .shadow(color: palette.accent.opacity(0.6), radius: 5)
        case .next:
            Circle()
                .fill(palette.nodeBg)
                .overlay(Circle().stroke(palette.accent, lineWidth: 2.5))
                .frame(width: 11, height: 11)
        case .past:
            Circle().fill(palette.mute).frame(width: 7, height: 7)
        }
    }

    // MARK: Данные → блоки

    private func time(_ lesson: Lesson) -> String {
        lesson.time.replacingOccurrences(of: "-", with: "–")
    }

    private func block(_ lesson: Lesson, label: String, node: TimelineBlock.Node, progress: Double?) -> TimelineBlock {
        TimelineBlock(label: label, subject: lesson.subject, who: lesson.teacher, time: time(lesson), room: lesson.room, meta: nil, node: node, progress: progress)
    }

    private func makeBlocks() -> [TimelineBlock] {
        if entry.isWeekend {
            var blocks = [TimelineBlock(label: "Сегодня", subject: "Выходной", who: "", time: "", room: "", meta: "Пар нет — отдыхайте", node: .past, progress: nil)]
            if let next = entry.nextLesson {
                blocks.append(block(next, label: entry.nextLessonDayName ?? "Следующая пара", node: .next, progress: nil))
            }
            return blocks
        }
        if entry.currentLesson == nil && entry.nextLesson == nil {
            return []
        }
        var blocks: [TimelineBlock] = []
        if let current = entry.currentLesson {
            blocks.append(block(current, label: "Сейчас идёт", node: .live, progress: entry.currentLessonProgress))
            if entry.isNextLessonInAnotherDay {
                blocks.append(TimelineBlock(label: "Затем", subject: "Пары закончились", who: "", time: "", room: "", meta: "Можно домой", node: .past, progress: nil))
            } else if let next = entry.nextLesson {
                blocks.append(block(next, label: isMedium ? "Следующая пара" : "Следующая", node: .next, progress: nil))
            }
        } else if entry.isTomorrowWeekend {
            blocks.append(TimelineBlock(label: "Завтра", subject: "Завтра пар нет", who: "", time: "", room: "", meta: "Отдыхаем", node: .past, progress: nil))
        } else if let next = entry.nextLesson {
            let label = entry.isNextLessonInAnotherDay ? (entry.nextLessonDayName ?? "Следующая пара") : (isMedium ? "Следующая пара" : "Следующая")
            blocks.append(block(next, label: label, node: .next, progress: nil))
        }
        return blocks
    }
}
