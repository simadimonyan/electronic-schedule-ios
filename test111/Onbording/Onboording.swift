//
//  Onboording.swift
//  test111
//
//  Created by Дмитрий Цепилов on 08.12.2024.
//

import UIKit

/// Онбординг (Onboarding.dc.html): превью расписания, преимущества и выбор «Я студент / Я преподаватель».
/// Сейчас отключён в SceneDelegate — экран оставлен в новом стиле на случай включения.
class OnboardingViewController: UIViewController {

    var completionHandler: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.Color.bg

        let backdrop = BackdropView()
        view.addSubview(backdrop)
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.heightAnchor.constraint(equalToConstant: 520)
        ])

        // Логотип и подпись
        let logo = UIImageView(image: DS.Image.logo)
        logo.layer.cornerRadius = 13
        logo.clipsToBounds = true
        logo.fixSize(width: 48, height: 48)
        let brand = UIStackView.ds(.vertical, spacing: 0, views: [
            UILabel.ds("Моя Академия", font: DS.Font.display(16, .heavy)),
            UILabel.ds("Академия ИМСИТ · Краснодар", font: DS.Font.text(12.5), color: DS.Color.soft)
        ])
        let brandRow = UIStackView.ds(.horizontal, spacing: 12, alignment: .center, views: [logo, brand])

        // Превью: пример карточки текущей и следующей пары
        let sampleNow = Lesson(number: 4, time: "13:10-14:40", subject: "Этические вопросы", teacher: "Чавыкина У.Г.", room: "1-102", type: "Практика", color: .systemBlue)
        let sampleNext = Lesson(number: 5, time: "14:50-16:20", subject: "Этические вопросы", teacher: "Чавыкина У.Г.", room: "1-301", type: "Лекция", color: .systemBlue)
        let nowCard = NowCardView(lesson: sampleNow, isTeacher: false, nowMinutes: 13 * 60 + 42)
        nowCard.isUserInteractionEnabled = false
        let nextCard = LessonCardView(lesson: sampleNext, isTeacher: false)
        nextCard.isUserInteractionEnabled = false
        let back = CardView(radius: 16, shadow: .sm)
        back.alpha = 0.7
        back.transform = CGAffineTransform(rotationAngle: -2.5 * .pi / 180)
        let preview = UIView()
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.isAccessibilityElement = false
        preview.accessibilityElementsHidden = true
        [back, nowCard, nextCard].forEach { preview.addSubview($0) }
        NSLayoutConstraint.activate([
            back.topAnchor.constraint(equalTo: preview.topAnchor),
            back.leadingAnchor.constraint(equalTo: preview.leadingAnchor, constant: 22),
            back.trailingAnchor.constraint(equalTo: preview.trailingAnchor, constant: -22),
            back.heightAnchor.constraint(equalToConstant: 74),
            nowCard.topAnchor.constraint(equalTo: preview.topAnchor, constant: 22),
            nowCard.leadingAnchor.constraint(equalTo: preview.leadingAnchor),
            nowCard.trailingAnchor.constraint(equalTo: preview.trailingAnchor),
            nextCard.topAnchor.constraint(equalTo: nowCard.bottomAnchor, constant: -18),
            nextCard.leadingAnchor.constraint(equalTo: preview.leadingAnchor, constant: 14),
            nextCard.trailingAnchor.constraint(equalTo: preview.trailingAnchor, constant: -14),
            nextCard.bottomAnchor.constraint(equalTo: preview.bottomAnchor)
        ])

        // Заголовок: «ИМСИТ» — фирменным цветом
        let headline = UILabel()
        headline.numberOfLines = 0
        let font = DS.Font.display(38, .heavy)
        let text = NSMutableAttributedString(attributedString: .ds("Расписание ", font: font, color: DS.Color.fg, kern: -1.33, lineHeight: 40))
        text.append(.ds("ИМСИТ", font: font, color: DS.Color.brand, kern: -1.33, lineHeight: 40))
        text.append(.ds(" всегда под рукой", font: font, color: DS.Color.fg, kern: -1.33, lineHeight: 40))
        headline.attributedText = text
        let lead = UILabel.ds("Текущая пара, аудитория и напоминания. Работает без интернета.", font: DS.Font.text(15.5), color: DS.Color.soft, lines: 0, lineHeight: 25)

        // Преимущества — только то, что есть в приложении
        let features: [(String, String)] = [("clock", "Сейчас и дальше"), ("bell", "Напоминания"), ("icloud.and.arrow.down", "Без сети"), ("square.grid.2x2", "Виджеты")]
        let chipsRow1 = UIStackView.ds(.horizontal, spacing: 6)
        let chipsRow2 = UIStackView.ds(.horizontal, spacing: 6)
        for (i, item) in features.enumerated() {
            let chip = CardView(radius: 15, shadow: .none)
            let icon = UIImageView(image: DS.symbol(item.0, size: 12, weight: .semibold))
            icon.tintColor = DS.Color.accent
            let row = UIStackView.ds(.horizontal, spacing: 6, alignment: .center, views: [icon, UILabel.ds(item.1, font: DS.Font.text(12.5, .semibold), color: DS.Color.muted)])
            chip.addSubview(row)
            row.pinEdges(to: chip, insets: UIEdgeInsets(top: 0, left: 9, bottom: 0, right: 11))
            chip.fixSize(height: 30)
            (i < 2 ? chipsRow1 : chipsRow2).addArrangedSubview(chip)
        }
        chipsRow1.addArrangedSubview(UIView())
        chipsRow2.addArrangedSubview(UIView())
        let chips = UIStackView.ds(.vertical, spacing: 6, views: [chipsRow1, chipsRow2])

        let student = DSButton("Я студент", height: 54, fontSize: 16, icon: DS.symbol("arrow.right", size: 14, weight: .bold))
        student.iconTrailing = true
        student.onTap = { [weak self] in self?.finish(isTeacher: false) }
        let teacher = GlassCapsuleButton(title: "Я преподаватель")
        teacher.onTap = { [weak self] in self?.finish(isTeacher: true) }

        let top = UIStackView.ds(.vertical, spacing: 0, views: [brandRow, preview, headline, lead, chips])
        top.setCustomSpacing(26, after: brandRow)
        top.setCustomSpacing(26, after: preview)
        top.setCustomSpacing(12, after: headline)
        top.setCustomSpacing(16, after: lead)
        let bottom = UIStackView.ds(.vertical, spacing: 10, views: [student, teacher])

        view.addSubview(top)
        view.addSubview(bottom)
        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            top.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            top.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            bottom.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            bottom.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            bottom.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            bottom.topAnchor.constraint(greaterThanOrEqualTo: top.bottomAnchor, constant: 16)
        ])
    }

    private func finish(isTeacher: Bool) {
        // Режим сохраняется так же, как в настройках (до создания главного экрана)
        UserDefaults.standard.set(isTeacher, forKey: "isTeacherMode")
        finishOnboarding()
    }

    @objc func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        completionHandler?()
    }
}

/// Стеклянная кнопка-капсула (вторичное действие на онбординге)
private final class GlassCapsuleButton: DSTapControl {
    init(title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 54).isActive = true
        let glass = GlassView(interactive: true)
        glass.isCapsule = true
        glass.isUserInteractionEnabled = false
        addSubview(glass)
        glass.pinEdges(to: self)
        let label = UILabel.ds(title, font: DS.Font.text(16, .semibold), alignment: .center)
        glass.contentView.addSubview(label)
        label.pinEdges(to: glass.contentView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// Расширение для UIColor, чтобы использовать hex-код
extension UIColor {
    convenience init(hex: String) {
        var hexFormatted = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).uppercased()
        if hexFormatted.hasPrefix("#") {
            hexFormatted = String(hexFormatted.dropFirst())
        }
        assert(hexFormatted.count == 6, "Invalid hex code used.")
        var rgbValue: UInt64 = 0
        Scanner(string: hexFormatted).scanHexInt64(&rgbValue)
        let red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgbValue & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
