//
//  AboutViewController.swift
//
//  Created by Assistant on 20.10.2025.
//

import UIKit
import MyTrackerSDK

final class AboutViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stack = UIStackView.ds(.vertical)
    private let backButton = GlassIconButton(symbol: "chevron.left")
    private var stackTop: NSLayoutConstraint!

    private var isPushed: Bool {
        (navigationController?.viewControllers.count ?? 0) > 1
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        MRMyTracker.trackEvent(name: "Открыть вкладку авторское право")
        view.backgroundColor = DS.Color.bg

        let backdrop = BackdropView()
        backdrop.showsSky = false
        view.addSubview(backdrop)
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.heightAnchor.constraint(equalToConstant: 420)
        ])

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)
        scrollView.pinEdges(to: view)
        scrollView.addSubview(stack)
        stackTop = stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 120)
        NSLayoutConstraint.activate([
            stackTop,
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: DS.Inset.side),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -DS.Inset.side),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -48)
        ])

        buildContent()

        backButton.accessibilityLabel = "Назад"
        backButton.onTap = { [weak self] in self?.close() }
        view.addSubview(backButton)
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DS.Inset.side)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        backButton.setSymbol(isPushed ? "chevron.left" : "xmark", pointSize: isPushed ? 17 : 15)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        stackTop.constant = max(view.safeAreaInsets.top, 20) + 66
    }

    private func close() {
        if isPushed {
            navigationController?.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func buildContent() {
        // Логотип, название, версия
        let logo = UIImageView(image: DS.Image.logo)
        logo.layer.cornerRadius = 24
        logo.clipsToBounds = true
        logo.fixSize(width: 92, height: 92)
        let logoWrap = UIView()
        logoWrap.translatesAutoresizingMaskIntoConstraints = false
        logoWrap.layer.shadowColor = DS.Color.brand.cgColor
        logoWrap.layer.shadowOpacity = 0.55
        logoWrap.layer.shadowRadius = 20
        logoWrap.layer.shadowOffset = CGSize(width: 0, height: 16)
        logoWrap.addSubview(logo)
        logo.pinEdges(to: logoWrap)

        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Моя Академия"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let title = UILabel.display(name, size: 28, alignment: .center)
        let versionLabel = UILabel.ds("v\(version)" + (build.isEmpty ? "" : " · build \(build)"), font: DS.Font.mono(12), color: DS.Color.soft, alignment: .center)

        let head = UIStackView.ds(.vertical, spacing: 0, alignment: .center, views: [logoWrap, title, versionLabel])
        head.setCustomSpacing(16, after: logoWrap)
        head.setCustomSpacing(8, after: title)
        stack.addArrangedSubview(head)

        // Что нового
        add(title: "Что нового", spacing: 28)
        let news: [(String, String, String)] = [
            ("sparkles", "Новый дизайн", "В стиле сайта Академии, светлая и тёмная тема."),
            ("square.grid.2x2", "Виджеты", "Текущая и следующая пара на экране «Домой»."),
            ("icloud.and.arrow.down", "Работа без сети", "Расписание сохраняется на телефоне."),
            ("bubble.left.and.bubble.right", "Опросы", "Расскажите, что улучшить, — читаем каждый ответ.")
        ]
        let newsGroup = DSListGroup()
        for (i, item) in news.enumerated() {
            let row = DSListRow(symbol: item.0, title: item.1, subtitle: item.2)
            row.pressScale = 1
            row.showsSeparator = i > 0
            newsGroup.add(row)
        }
        stack.addArrangedSubview(newsGroup)

        // Связь
        add(title: "Связь", spacing: 24)
        let telegram = DSListRow(symbol: "paperplane", title: "Telegram-канал", externalLink: true)
        telegram.onTap = { [weak self] in self?.openTelegram() }
        stack.addArrangedSubview(DSListGroup(rows: [telegram]))

        // Примечание
        let note = CardView(radius: DS.Radius.card, shadow: .none)
        note.fill = .clear
        note.dashed = true
        note.borderColor = DS.Color.borderStrong
        let noteLabel = UILabel.ds("Расписание загружается с сервера Академии ИМСИТ и хранится на устройстве, поэтому открывается и без интернета.", font: DS.Font.text(13.5), color: DS.Color.muted, lines: 0, lineHeight: 20)
        note.addSubview(noteLabel)
        noteLabel.pinEdges(to: note, insets: UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))
        stack.setCustomSpacing(24, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(note)

        let copyright = UILabel.ds("© 2024–2026 · Академия ИМСИТ, Краснодар", font: DS.Font.text(12), color: DS.Color.faint, alignment: .center)
        stack.setCustomSpacing(20, after: note)
        stack.addArrangedSubview(copyright)
    }

    private func add(title: String, spacing: CGFloat) {
        if let last = stack.arrangedSubviews.last { stack.setCustomSpacing(spacing, after: last) }
        let caption = dsSectionTitle(title)
        stack.addArrangedSubview(caption)
        stack.setCustomSpacing(8, after: caption)
    }

    @objc private func openTelegram() {
        guard let url = URL(string: "https://t.me/+oIslJtlz52cxYzZi") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
