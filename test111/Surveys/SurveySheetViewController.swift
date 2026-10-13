//
//  SurveySheetViewController.swift
//  Нижний лист «Пара вопросов о приложении»: форма опроса, загрузка, ошибка, успех.
//

import UIKit

final class SurveySheetViewController: UIViewController, UIAdaptivePresentationControllerDelegate {

    private enum State {
        case loading
        case empty
        case failed(String)
        case form(Quiz)
        case done(String)
    }

    private var quiz: Quiz?
    /// Показан сам (по таймеру), а не из настроек: закрытие свайпом = «Не сейчас»
    private let automatic: Bool
    private var isSubmitting = false
    private var finished = false

    // Ответы: questionId → значение
    private var ratingAnswers: [Int: Int] = [:]
    private var singleAnswers: [Int: Int] = [:]
    private var multipleAnswers: [Int: Set<Int>] = [:]
    private var textAnswers: [Int: String] = [:]

    private let textLimit = 2000

    // MARK: Вью

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let bottomBar = UIStackView()
    private let submitButton = UIButton(type: .system)
    private let laterButton = UIButton(type: .system)
    private let activity = UIActivityIndicatorView(style: .medium)
    private var bottomBarBottom: NSLayoutConstraint!

    /// Обновление вида вариантов при выборе
    private var refreshers: [Int: () -> Void] = [:]

    init(quiz: Quiz?, automatic: Bool) {
        self.quiz = quiz
        self.automatic = automatic
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Пара вопросов о приложении"
        navigationItem.largeTitleDisplayMode = .never
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemGroupedBackground
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.font: UIFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: UIColor.label]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeTapped))

        setupLayout()

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        if let quiz = quiz {
            render(.form(quiz))
        } else {
            loadCurrentQuiz()
        }
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        // Нижняя панель: «Отправить» + «Не сейчас»
        bottomBar.axis = .vertical
        bottomBar.spacing = 4
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.isLayoutMarginsRelativeArrangement = true
        bottomBar.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 8, right: 16)
        bottomBar.backgroundColor = .systemGroupedBackground
        view.addSubview(bottomBar)

        styleSubmitButton()
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        submitButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        activity.color = .white
        activity.hidesWhenStopped = true
        activity.translatesAutoresizingMaskIntoConstraints = false
        submitButton.addSubview(activity)
        NSLayoutConstraint.activate([
            activity.centerXAnchor.constraint(equalTo: submitButton.centerXAnchor),
            activity.centerYAnchor.constraint(equalTo: submitButton.centerYAnchor)
        ])

        laterButton.setTitle("Не сейчас", for: .normal)
        laterButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        laterButton.setTitleColor(.secondaryLabel, for: .normal)
        laterButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        laterButton.addTarget(self, action: #selector(laterTapped), for: .touchUpInside)

        bottomBar.addArrangedSubview(submitButton)
        bottomBar.addArrangedSubview(laterButton)

        bottomBarBottom = bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBarBottom
        ])
    }

    private func styleSubmitButton(title: String = "Отправить") {
        submitButton.setTitle(title, for: .normal)
        submitButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        submitButton.layer.cornerRadius = 12
        submitButton.tintColor = .white
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.setTitleColor(UIColor.white.withAlphaComponent(0.8), for: .disabled)
    }

    // MARK: Состояния

    private func render(_ state: State) {
        currentState = state
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        refreshers.removeAll()
        laterButton.isHidden = false
        submitButton.isHidden = false
        activity.stopAnimating()

        switch state {
        case .loading:
            let spinner = UIActivityIndicatorView(style: .large)
            spinner.startAnimating()
            stack.addArrangedSubview(messageBlock(icon: nil, title: "Загружаем опрос…", text: nil, accessory: spinner))
            submitButton.isHidden = true
            laterButton.isHidden = true

        case .empty:
            stack.addArrangedSubview(messageBlock(icon: "tray", title: "Сейчас опросов нет", text: "Спасибо, что заглянули! Когда появится новый опрос, мы предложим его здесь.", accessory: nil))
            setSubmit(title: "Закрыть", enabled: true)
            laterButton.isHidden = true

        case .failed(let message):
            stack.addArrangedSubview(messageBlock(icon: "wifi.exclamationmark", title: "Не удалось загрузить опрос", text: message, accessory: nil))
            setSubmit(title: "Повторить", enabled: true)

        case .form(let quiz):
            self.quiz = quiz
            buildForm(quiz)
            updateSubmitState()

        case .done(let message):
            finished = true
            stack.addArrangedSubview(messageBlock(icon: "checkmark.circle.fill", title: message, text: nil, accessory: nil))
            setSubmit(title: "Готово", enabled: true)
            laterButton.isHidden = true
            if #available(iOS 15.0, *), let sheet = navigationController?.sheetPresentationController {
                sheet.animateChanges { sheet.selectedDetentIdentifier = .medium }
            }
        }
    }

    private var currentState: State = .loading

    private func setSubmit(title: String, enabled: Bool) {
        styleSubmitButton(title: title)
        submitButton.isEnabled = enabled
        submitButton.backgroundColor = enabled ? .systemBlue : .systemGray3
    }

    private func loadCurrentQuiz() {
        render(.loading)
        let manager = SurveyManager.shared
        QuizAPIClient.shared.search(group: manager.group, respondent: manager.respondent) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let quizzes):
                if let first = quizzes.first { self.render(.form(first)) } else { self.render(.empty) }
            case .failure(let error):
                self.render(.failed(error.localizedDescription))
            }
        }
    }

    // MARK: Форма

    private func buildForm(_ quiz: Quiz) {
        let header = UIStackView()
        header.axis = .vertical
        header.spacing = 6
        let name = UILabel()
        name.text = quiz.name
        name.font = .systemFont(ofSize: 22, weight: .bold)
        name.textColor = .label
        name.numberOfLines = 0
        header.addArrangedSubview(name)
        if let description = quiz.description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
            let label = UILabel()
            label.text = description
            label.font = .systemFont(ofSize: 15)
            label.textColor = .secondaryLabel
            label.numberOfLines = 0
            header.addArrangedSubview(label)
        }
        if quiz.supportedQuestions.contains(where: { $0.isRequired }) {
            let hint = UILabel()
            hint.attributedText = requiredHint()
            hint.numberOfLines = 0
            header.addArrangedSubview(hint)
        }
        stack.addArrangedSubview(header)

        for question in quiz.supportedQuestions {
            stack.addArrangedSubview(card(for: question))
        }
    }

    private func requiredHint() -> NSAttributedString {
        let text = NSMutableAttributedString(string: "* ", attributes: [.foregroundColor: UIColor.systemRed, .font: UIFont.systemFont(ofSize: 13, weight: .semibold)])
        text.append(NSAttributedString(string: "— обязательный вопрос", attributes: [.foregroundColor: UIColor.secondaryLabel, .font: UIFont.systemFont(ofSize: 13)]))
        return text
    }

    /// Карточка вопроса в стиле карточек настроек
    private func card(for question: QuizQuestion) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 12
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 4

        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 10
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        let title = UILabel()
        title.numberOfLines = 0
        let titleText = NSMutableAttributedString(string: question.label, attributes: [.font: UIFont.systemFont(ofSize: 16, weight: .semibold), .foregroundColor: UIColor.label])
        if question.isRequired {
            titleText.append(NSAttributedString(string: " *", attributes: [.font: UIFont.systemFont(ofSize: 16, weight: .semibold), .foregroundColor: UIColor.systemRed]))
        }
        title.attributedText = titleText
        content.addArrangedSubview(title)

        if let description = question.description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
            let label = UILabel()
            label.text = description
            label.font = .systemFont(ofSize: 14)
            label.textColor = .secondaryLabel
            label.numberOfLines = 0
            content.addArrangedSubview(label)
        }

        switch question.questionType {
        case .rating?: content.addArrangedSubview(ratingRow(for: question))
        case .single?: content.addArrangedSubview(optionsList(for: question, multiple: false))
        case .multiple?: content.addArrangedSubview(optionsList(for: question, multiple: true))
        case .text?: content.addArrangedSubview(textInput(for: question))
        case nil: break
        }
        return card
    }

    // RATING: ряд кнопок 1…scale
    private func ratingRow(for question: QuizQuestion) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 8
        var buttons: [SurveyActionButton] = []
        for value in 1...question.ratingScale {
            let button = SurveyActionButton(type: .system)
            button.setTitle("\(value)", for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
            button.layer.cornerRadius = 12
            button.heightAnchor.constraint(equalToConstant: 48).isActive = true
            button.accessibilityLabel = "Оценка \(value) из \(question.ratingScale)"
            button.onTap = { [weak self] in
                self?.ratingAnswers[question.id] = value
                self?.refreshers[question.id]?()
                self?.updateSubmitState()
                UISelectionFeedbackGenerator().selectionChanged()
            }
            buttons.append(button)
            row.addArrangedSubview(button)
        }
        let refresh = { [weak self] in
            let selected = self?.ratingAnswers[question.id]
            for (index, button) in buttons.enumerated() {
                let isOn = selected == index + 1
                button.backgroundColor = isOn ? .systemBlue : .tertiarySystemFill
                button.setTitleColor(isOn ? .white : .label, for: .normal)
                button.accessibilityTraits = isOn ? [.button, .selected] : .button
            }
        }
        refreshers[question.id] = refresh
        refresh()
        return row
    }

    // SINGLE / MULTIPLE: список вариантов
    private func optionsList(for question: QuizQuestion, multiple: Bool) -> UIView {
        let list = UIStackView()
        list.axis = .vertical
        list.spacing = 8
        var rows: [(QuizAnswerOption, SurveyActionButton)] = []
        for option in question.options {
            let button = SurveyActionButton(type: .system)
            button.contentHorizontalAlignment = .leading
            button.titleLabel?.font = .systemFont(ofSize: 16)
            button.titleLabel?.numberOfLines = 0
            button.setTitle(option.label, for: .normal)
            button.setTitleColor(.label, for: .normal)
            button.layer.cornerRadius = 10
            button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: -10)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 46).isActive = true
            button.onTap = { [weak self] in
                guard let self = self else { return }
                if multiple {
                    var set = self.multipleAnswers[question.id] ?? []
                    if set.contains(option.id) { set.remove(option.id) } else { set.insert(option.id) }
                    self.multipleAnswers[question.id] = set
                } else {
                    self.singleAnswers[question.id] = option.id
                }
                self.refreshers[question.id]?()
                self.updateSubmitState()
                UISelectionFeedbackGenerator().selectionChanged()
            }
            rows.append((option, button))
            list.addArrangedSubview(button)
        }
        let refresh = { [weak self] in
            guard let self = self else { return }
            for (option, button) in rows {
                let isOn = multiple
                    ? (self.multipleAnswers[question.id]?.contains(option.id) ?? false)
                    : self.singleAnswers[question.id] == option.id
                let symbol: String
                if multiple { symbol = isOn ? "checkmark.square.fill" : "square" }
                else { symbol = isOn ? "largecircle.fill.circle" : "circle" }
                button.setImage(UIImage(systemName: symbol), for: .normal)
                button.tintColor = isOn ? .systemBlue : .tertiaryLabel
                button.backgroundColor = isOn ? UIColor.systemBlue.withAlphaComponent(0.12) : .tertiarySystemFill
                button.layer.borderWidth = isOn ? 1.5 : 0
                button.layer.borderColor = UIColor.systemBlue.cgColor
                button.accessibilityTraits = isOn ? [.button, .selected] : .button
            }
        }
        refreshers[question.id] = refresh
        refresh()
        if multiple {
            let hint = UILabel()
            hint.text = "Можно выбрать несколько"
            hint.font = .systemFont(ofSize: 13)
            hint.textColor = .secondaryLabel
            list.addArrangedSubview(hint)
        }
        return list
    }

    // TEXT: поле с плейсхолдером и счётчиком
    private func textInput(for question: QuizQuestion) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 4

        let textView = SurveyTextView()
        textView.questionId = question.id
        textView.font = .systemFont(ofSize: 16)
        textView.textColor = .label
        textView.backgroundColor = .tertiarySystemFill
        textView.layer.cornerRadius = 10
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        textView.isScrollEnabled = false
        textView.delegate = self
        textView.text = textAnswers[question.id]
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true

        let placeholder = UILabel()
        placeholder.text = question.isRequired ? "Напишите пару слов" : "Необязательно — пару слов, если хочется"
        placeholder.font = .systemFont(ofSize: 16)
        placeholder.textColor = .placeholderText
        placeholder.numberOfLines = 0
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.topAnchor.constraint(equalTo: textView.topAnchor, constant: 12),
            placeholder.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 13),
            placeholder.widthAnchor.constraint(equalTo: textView.widthAnchor, constant: -26)
        ])
        textView.placeholderLabel = placeholder

        let counter = UILabel()
        counter.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        counter.textColor = .tertiaryLabel
        counter.textAlignment = .right
        textView.counterLabel = counter
        textView.limit = textLimit
        textView.refreshDecorations()

        container.addArrangedSubview(textView)
        container.addArrangedSubview(counter)
        return container
    }

    // MARK: Валидация и отправка

    private func isAnswered(_ question: QuizQuestion) -> Bool {
        switch question.questionType {
        case .rating?: return ratingAnswers[question.id] != nil
        case .single?: return singleAnswers[question.id] != nil
        case .multiple?: return !(multipleAnswers[question.id]?.isEmpty ?? true)
        case .text?: return !(textAnswers[question.id]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        case nil: return true
        }
    }

    private var canSubmit: Bool {
        guard let quiz = quiz else { return false }
        return quiz.supportedQuestions.filter { $0.isRequired }.allSatisfy(isAnswered)
    }

    private func updateSubmitState() {
        guard case .form = currentState else { return }
        setSubmit(title: isSubmitting ? "" : "Отправить", enabled: canSubmit && !isSubmitting)
    }

    private func buildAnswers(for quiz: Quiz) -> [QuizSubmitUnit] {
        var units: [QuizSubmitUnit] = []
        for question in quiz.supportedQuestions {
            switch question.questionType {
            case .rating?:
                if let value = ratingAnswers[question.id] { units.append(QuizSubmitUnit(questionId: question.id, answerId: nil, value: String(value))) }
            case .single?:
                if let id = singleAnswers[question.id] { units.append(QuizSubmitUnit(questionId: question.id, answerId: id, value: nil)) }
            case .multiple?:
                // По строке на каждый выбранный вариант, в порядке вариантов
                let selected = multipleAnswers[question.id] ?? []
                for option in question.options where selected.contains(option.id) {
                    units.append(QuizSubmitUnit(questionId: question.id, answerId: option.id, value: nil))
                }
            case .text?:
                let text = (textAnswers[question.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { units.append(QuizSubmitUnit(questionId: question.id, answerId: nil, value: String(text.prefix(textLimit)))) }
            case nil:
                break
            }
        }
        return units
    }

    @objc private func submitTapped() {
        switch currentState {
        case .empty, .done:
            dismiss(animated: true)
        case .failed:
            if let quiz = quiz { render(.form(quiz)) } else { loadCurrentQuiz() }
        case .loading:
            break
        case .form(let quiz):
            guard canSubmit, !isSubmitting else { return }
            view.endEditing(true)
            isSubmitting = true
            updateSubmitState()
            activity.startAnimating()
            let manager = SurveyManager.shared
            let request = QuizSubmitRequest(quizId: quiz.id, respondent: manager.respondent, group: manager.group, answers: buildAnswers(for: quiz))
            QuizAPIClient.shared.submit(request) { [weak self] result in
                guard let self = self else { return }
                self.isSubmitting = false
                self.activity.stopAnimating()
                switch result {
                case .success(let response):
                    let message = [response.message, quiz.completionMessage]
                        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .first { !$0.isEmpty } ?? "Спасибо за отзыв!"
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    self.render(.done(message))
                case .failure(let error):
                    self.updateSubmitState()
                    let alreadyAnswered = (error as? QuizAPIError)?.isAlreadyAnswered ?? false
                    let alert = UIAlertController(title: alreadyAnswered ? "Опрос уже пройден" : "Не получилось отправить",
                                                  message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                        if alreadyAnswered { self?.finished = true; self?.dismiss(animated: true) }
                    })
                    self.present(alert, animated: true)
                }
            }
        }
    }

    @objc private func laterTapped() {
        SurveyManager.shared.snooze()
        dismiss(animated: true)
    }

    @objc private func closeTapped() {
        if automatic && !finished { SurveyManager.shared.snooze() }
        dismiss(animated: true)
    }

    // Закрытие свайпом вниз из автопоказа считаем «Не сейчас»
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        if automatic && !finished { SurveyManager.shared.snooze() }
    }

    // MARK: Клавиатура

    @objc private func keyboardWillChange(_ note: Notification) {
        guard let window = view.window,
              let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let keyboardInView = view.convert(frame, from: window.screen.coordinateSpace)
        let safeBottom = view.bounds.maxY - view.safeAreaInsets.bottom
        let overlap = note.name == UIResponder.keyboardWillHideNotification ? 0 : max(0, safeBottom - keyboardInView.minY)
        bottomBarBottom.constant = -overlap
        let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
        if overlap > 0 { scrollToFirstResponder() }
    }

    private func scrollToFirstResponder() {
        guard let responder = stack.firstResponderView() else { return }
        let rect = responder.convert(responder.bounds, to: scrollView).insetBy(dx: 0, dy: -16)
        DispatchQueue.main.async { self.scrollView.scrollRectToVisible(rect, animated: true) }
    }

    // MARK: Вспомогательное

    private func messageBlock(icon: String?, title: String, text: String?, accessory: UIView?) -> UIView {
        let box = UIStackView()
        box.axis = .vertical
        box.alignment = .center
        box.spacing = 12
        box.isLayoutMarginsRelativeArrangement = true
        box.layoutMargins = UIEdgeInsets(top: 32, left: 8, bottom: 16, right: 8)
        if let accessory = accessory { box.addArrangedSubview(accessory) }
        if let icon = icon {
            let image = UIImageView(image: UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 44, weight: .regular)))
            image.tintColor = icon.hasPrefix("checkmark") ? .systemGreen : .systemBlue
            box.addArrangedSubview(image)
        }
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        box.addArrangedSubview(titleLabel)
        if let text = text {
            let label = UILabel()
            label.text = text
            label.font = .systemFont(ofSize: 15)
            label.textColor = .secondaryLabel
            label.textAlignment = .center
            label.numberOfLines = 0
            box.addArrangedSubview(label)
        }
        return box
    }
}

// MARK: - Текстовые ответы

extension SurveySheetViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let current = textView.text ?? ""
        guard let swiftRange = Range(range, in: current) else { return false }
        let updated = current.replacingCharacters(in: swiftRange, with: text)
        if updated.count <= textLimit { return true }
        // Вставка длинного текста — обрезаем до лимита
        let allowed = max(0, textLimit - (current.count - current[swiftRange].count))
        if allowed > 0 {
            textView.text = current.replacingCharacters(in: swiftRange, with: String(text.prefix(allowed)))
            textViewDidChange(textView)
        }
        return false
    }

    func textViewDidChange(_ textView: UITextView) {
        guard let view = textView as? SurveyTextView else { return }
        textAnswers[view.questionId] = textView.text
        view.refreshDecorations()
        updateSubmitState()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        if #available(iOS 15.0, *), let sheet = navigationController?.sheetPresentationController {
            sheet.animateChanges { sheet.selectedDetentIdentifier = .large }
        }
        scrollToFirstResponder()
    }
}

/// Кнопка с замыканием (UIAction доступен только с iOS 14)
private final class SurveyActionButton: UIButton {
    var onTap: (() -> Void)? {
        didSet { addTarget(self, action: #selector(handleTap), for: .touchUpInside) }
    }
    @objc private func handleTap() { onTap?() }
}

/// UITextView с плейсхолдером и счётчиком символов
private final class SurveyTextView: UITextView {
    var questionId = 0
    var limit = 2000
    weak var placeholderLabel: UILabel?
    weak var counterLabel: UILabel?

    func refreshDecorations() {
        placeholderLabel?.isHidden = !(text ?? "").isEmpty
        let count = (text ?? "").count
        counterLabel?.text = "\(count) / \(limit)"
        counterLabel?.textColor = count >= limit ? .systemRed : .tertiaryLabel
    }
}

private extension UIView {
    func firstResponderView() -> UIView? {
        if isFirstResponder { return self }
        for sub in subviews {
            if let found = sub.firstResponderView() { return found }
        }
        return nil
    }
}
