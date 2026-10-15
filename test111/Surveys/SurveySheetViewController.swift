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
    private let submitButton = DSButton("Отправить", height: 50, fontSize: 15)
    private let laterButton = DSButton("Не сейчас", style: .secondary, height: 50, fontSize: 14.5)
    private let header = UIView()
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
        view.backgroundColor = DS.Color.bg
        title = "Пара вопросов о приложении"
        navigationController?.setNavigationBarHidden(true, animated: false)

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
        // Шапка листа: надзаголовок и круглая кнопка «Закрыть»
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)
        let eyebrow = EyebrowPill("Опрос", size: 10)
        let close = DSTapControl()
        close.backgroundColor = DS.Color.sunk
        close.layer.cornerRadius = 20
        close.fixSize(width: 40, height: 40)
        let xmark = UIImageView(image: DS.symbol("xmark", size: 14, weight: .bold))
        xmark.tintColor = DS.Color.fg
        xmark.contentMode = .center
        close.addSubview(xmark)
        xmark.pinEdges(to: close)
        close.accessibilityLabel = "Закрыть"
        close.onTap = { [weak self] in self?.closeTapped() }
        header.addSubview(eyebrow)
        header.addSubview(close)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            header.heightAnchor.constraint(equalToConstant: 40),
            eyebrow.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            eyebrow.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            close.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            close.centerYAnchor.constraint(equalTo: header.centerYAnchor)
        ])

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        // Нижняя панель: «Не сейчас» + «Отправить»
        bottomBar.axis = .horizontal
        bottomBar.spacing = 8
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.isLayoutMarginsRelativeArrangement = true
        bottomBar.layoutMargins = UIEdgeInsets(top: 10, left: 22, bottom: 10, right: 22)
        bottomBar.backgroundColor = DS.Color.bg
        let barLine = UIView()
        barLine.backgroundColor = DS.Color.border
        barLine.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(barLine)
        NSLayoutConstraint.activate([
            barLine.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            barLine.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            barLine.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            barLine.heightAnchor.constraint(equalToConstant: 1)
        ])
        view.addSubview(bottomBar)

        submitButton.onTap = { [weak self] in self?.submitTapped() }
        activity.color = .white
        activity.hidesWhenStopped = true
        activity.translatesAutoresizingMaskIntoConstraints = false
        submitButton.addSubview(activity)
        NSLayoutConstraint.activate([
            activity.centerXAnchor.constraint(equalTo: submitButton.centerXAnchor),
            activity.centerYAnchor.constraint(equalTo: submitButton.centerYAnchor)
        ])

        laterButton.onTap = { [weak self] in self?.laterTapped() }
        laterButton.setContentHuggingPriority(.required, for: .horizontal)
        laterButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 128).isActive = true

        bottomBar.addArrangedSubview(laterButton)
        bottomBar.addArrangedSubview(submitButton)

        bottomBarBottom = bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -22),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBarBottom
        ])
    }

    private func styleSubmitButton(title: String = "Отправить") {
        submitButton.title = title
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
            stack.addArrangedSubview(messageBlock(icon: "IlloAllDone", title: "Сейчас опросов нет", text: "Спасибо, что заглянули! Когда появится новый опрос, мы предложим его здесь.", accessory: nil))
            setSubmit(title: "Понятно", enabled: true)
            laterButton.isHidden = true

        case .failed(let message):
            stack.addArrangedSubview(messageBlock(icon: "IlloUnavailable", title: "Не удалось загрузить опрос", text: message, accessory: nil))
            setSubmit(title: "Повторить", enabled: true)

        case .form(let quiz):
            self.quiz = quiz
            buildForm(quiz)
            updateSubmitState()
            #if DEBUG
            if SurveysDebug.demoFill && !demoApplied {
                demoApplied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.applyDemoAnswers(quiz) }
            }
            #endif

        case .done(let message):
            finished = true
            stack.addArrangedSubview(messageBlock(icon: "IlloSuccess", title: message, text: nil, accessory: nil))
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
        name.numberOfLines = 0
        name.setDS(quiz.name, font: DS.Font.display(25, .heavy), kern: -0.6, lineHeight: 29)
        header.addArrangedSubview(name)
        if let description = quiz.description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
            let label = UILabel()
            label.numberOfLines = 0
            label.setDS(description, font: DS.Font.text(13.5), color: DS.Color.soft, lineHeight: 20)
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
        let text = NSMutableAttributedString(string: "* ", attributes: [.foregroundColor: DS.Color.redFg, .font: DS.Font.text(12.5, .semibold)])
        text.append(NSAttributedString(string: "— обязательный вопрос", attributes: [.foregroundColor: DS.Color.faint, .font: DS.Font.text(12.5)]))
        return text
    }

    /// Карточка вопроса в стиле карточек настроек
    private func card(for question: QuizQuestion) -> UIView {
        let card = UIView()

        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])

        let title = UILabel()
        title.numberOfLines = 0
        let titleText = NSMutableAttributedString(string: question.label, attributes: [.font: DS.Font.text(14.5, .semibold), .foregroundColor: DS.Color.fg])
        if question.isRequired {
            titleText.append(NSAttributedString(string: " *", attributes: [.font: DS.Font.text(14.5, .semibold), .foregroundColor: DS.Color.redFg]))
        } else {
            titleText.append(NSAttributedString(string: " · необязательно", attributes: [.font: DS.Font.text(12.5), .foregroundColor: DS.Color.faint]))
        }
        title.attributedText = titleText
        content.addArrangedSubview(title)

        if let description = question.description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
            let label = UILabel()
            label.numberOfLines = 0
            label.setDS(description, font: DS.Font.text(13), color: DS.Color.soft, lineHeight: 19)
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
            button.titleLabel?.font = DS.Font.display(21, .heavy)
            button.layer.cornerRadius = 16
            button.layer.borderWidth = 1
            button.heightAnchor.constraint(equalToConstant: 58).isActive = true
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
                button.backgroundColor = isOn ? DS.Color.brand : DS.Color.surface
                button.layer.borderColor = isOn ? UIColor.clear.cgColor : DS.Color.borderStrong.resolvedColor(with: button.traitCollection).cgColor
                button.setTitleColor(isOn ? .white : DS.Color.fg, for: .normal)
                button.layer.shadowColor = DS.Color.brand.cgColor
                button.layer.shadowOpacity = isOn ? 0.3 : 0
                button.layer.shadowRadius = 9
                button.layer.shadowOffset = CGSize(width: 0, height: 6)
                button.accessibilityTraits = isOn ? [.button, .selected] : .button
            }
        }
        refreshers[question.id] = refresh
        refresh()
        guard question.ratingScale == 5 else { return row }
        // Подписи шкалы: «Плохо … Отлично»
        let words = ["Плохо", "Так себе", "Нормально", "Хорошо", "Отлично"]
        let low = UILabel.ds("Плохо", font: DS.Font.text(12), color: DS.Color.faint)
        let high = UILabel.ds("Отлично", font: DS.Font.text(12), color: DS.Color.faint)
        let word = UILabel.ds("", font: DS.Font.text(12, .semibold), color: DS.Color.accent, alignment: .center)
        let legend = UIStackView.ds(.horizontal, spacing: 4, alignment: .center, views: [low, word, high])
        legend.distribution = .equalCentering
        let previous = refreshers[question.id]
        refreshers[question.id] = { [weak self] in
            previous?()
            let value = self?.ratingAnswers[question.id]
            word.setDS(value.map { words[$0 - 1] } ?? "", font: DS.Font.text(12, .semibold), color: DS.Color.accent, alignment: .center)
        }
        let wrap = UIStackView.ds(.vertical, spacing: 8, views: [row])
        let legendWrap = UIView()
        legendWrap.addSubview(legend)
        legend.pinEdges(to: legendWrap, insets: UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4))
        wrap.addArrangedSubview(legendWrap)
        return wrap
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
            button.titleLabel?.font = DS.Font.text(14.5, .medium)
            button.titleLabel?.numberOfLines = 0
            button.setTitle(option.label, for: .normal)
            button.setTitleColor(DS.Color.fg, for: .normal)
            button.layer.cornerRadius = 12
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
                button.tintColor = isOn ? DS.Color.accent : DS.Color.faint
                button.backgroundColor = isOn ? DS.Color.accentSoft : DS.Color.surface
                button.layer.borderWidth = isOn ? 1.5 : 1
                button.layer.borderColor = (isOn ? DS.Color.accentBorder : DS.Color.borderStrong).resolvedColor(with: button.traitCollection).cgColor
                button.accessibilityTraits = isOn ? [.button, .selected] : .button
            }
        }
        refreshers[question.id] = refresh
        refresh()
        if multiple {
            let hint = UILabel()
            hint.text = "Можно выбрать несколько"
            hint.font = DS.Font.text(12)
            hint.textColor = DS.Color.faint
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
        textView.font = DS.Font.text(14)
        textView.textColor = DS.Color.fg
        textView.tintColor = DS.Color.accent
        textView.backgroundColor = DS.Color.surface
        textView.layer.cornerRadius = 12
        textView.layer.borderWidth = 1.5
        textView.layer.borderColor = DS.Color.borderStrong.resolvedColor(with: traitCollection).cgColor
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 9, bottom: 10, right: 9)
        textView.isScrollEnabled = false
        textView.delegate = self
        textView.text = textAnswers[question.id]
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 78).isActive = true

        let placeholder = UILabel()
        placeholder.text = question.isRequired ? "Напишите пару слов" : "Необязательно — пару слов, если хочется"
        placeholder.font = DS.Font.text(14)
        placeholder.textColor = DS.Color.faint
        placeholder.numberOfLines = 0
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.topAnchor.constraint(equalTo: textView.topAnchor, constant: 10),
            placeholder.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 14),
            placeholder.widthAnchor.constraint(equalTo: textView.widthAnchor, constant: -26)
        ])
        textView.placeholderLabel = placeholder

        let counter = UILabel()
        counter.font = DS.Font.mono(10.5)
        counter.textColor = DS.Color.faint
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

    // MARK: Демонстрация (только DEBUG)

    private var demoApplied = false

    #if DEBUG
    /// Максимальная оценка, первые варианты, примерные тексты; лист в large
    private func applyDemoAnswers(_ quiz: Quiz) {
        let samples = ["Удобно, что расписание открывается сразу, без интернета",
                       "Иногда виджет обновляется с задержкой"]
        var textIndex = 0
        for question in quiz.supportedQuestions {
            switch question.questionType {
            case .rating?: ratingAnswers[question.id] = question.ratingScale
            case .single?: if let first = question.options.first { singleAnswers[question.id] = first.id }
            case .multiple?: if let first = question.options.first { multipleAnswers[question.id] = [first.id] }
            case .text?:
                textAnswers[question.id] = samples[min(textIndex, samples.count - 1)]
                textIndex += 1
            case nil: break
            }
        }
        // Перерисовываем форму с ответами
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        refreshers.removeAll()
        buildForm(quiz)
        updateSubmitState()
        if #available(iOS 15.0, *), let sheet = navigationController?.sheetPresentationController {
            sheet.animateChanges { sheet.selectedDetentIdentifier = .large }
        }
        // Кнопка «Отправить» закреплена внизу листа и всегда видна — прокручивать не нужно
        if SurveysDebug.demoSubmit {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in self?.submitTapped() }
        }
    }
    #endif

    // MARK: Вспомогательное

    private func messageBlock(icon: String?, title: String, text: String?, accessory: UIView?) -> UIView {
        let box = UIStackView()
        box.axis = .vertical
        box.alignment = .center
        box.spacing = 8
        box.isLayoutMarginsRelativeArrangement = true
        box.layoutMargins = UIEdgeInsets(top: 0, left: 8, bottom: 16, right: 8)
        if let accessory = accessory { box.addArrangedSubview(accessory) }
        if let icon = icon {
            // Иллюстрация состояния из Assets
            let image = UIImageView(image: UIImage(named: icon))
            image.contentMode = .scaleAspectFit
            image.fixSize(width: 140, height: 140)
            box.addArrangedSubview(image)
        }
        let titleLabel = UILabel.display(title, size: 22, alignment: .center)
        box.addArrangedSubview(titleLabel)
        if let text = text {
            box.addArrangedSubview(UILabel.ds(text, font: DS.Font.text(14), color: DS.Color.soft, lines: 0, lineHeight: 21, alignment: .center))
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
        counterLabel?.textColor = count >= limit ? DS.Color.redFg : DS.Color.faint
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
