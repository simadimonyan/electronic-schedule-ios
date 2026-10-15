//
//  UpdateAvailableViewController.swift
//  test111
//
//  Created by Assistant on 20.01.2025.
//

import UIKit

final class UpdateAvailableViewController: UIViewController {
    
    private let appStoreVersion: String
    private let trackViewUrl: String?
    private let trackId: Int?
    
    init(appStoreVersion: String, trackViewUrl: String?, trackId: Int?) {
        self.appStoreVersion = appStoreVersion
        self.trackViewUrl = trackViewUrl
        self.trackId = trackId
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = DS.Color.bg

        let image = UIImageView(image: UIImage(named: "IlloUpdate"))
        image.contentMode = .scaleAspectFit
        image.fixSize(width: 132, height: 132)
        let badge = EyebrowPill("Версия \(appStoreVersion)", size: 10, showsDot: false)
        let title = UILabel.display("Доступно обновление", size: 24, alignment: .center)
        let message = UILabel.ds("Обновите приложение, чтобы расписание загружалось без ошибок и появились новые функции.", font: DS.Font.text(14), color: DS.Color.soft, lines: 0, lineHeight: 21, alignment: .center)

        // Текущая → новая версия
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let versions = UIStackView.ds(.horizontal, spacing: 10, alignment: .center, views: [
            UILabel.ds("v\(currentVersion)", font: DS.Font.mono(13), color: DS.Color.soft),
            UIImageView(image: DS.symbol("arrow.right", size: 12, weight: .semibold)),
            UILabel.ds("v\(appStoreVersion)", font: DS.Font.mono(13, .bold), color: DS.Color.accent)
        ])
        (versions.arrangedSubviews[1] as? UIImageView)?.tintColor = DS.Color.faint

        let updateButton = DSButton("Обновить в App Store")
        updateButton.onTap = { [weak self] in self?.updateTapped() }
        let laterButton = DSButton("Позже", style: .ghost, height: 40, fontSize: 14)
        laterButton.onTap = { [weak self] in self?.laterTapped() }

        let col = UIStackView.ds(.vertical, spacing: 0, alignment: .center, views: [image, badge, title, message, versions, updateButton, laterButton])
        col.setCustomSpacing(8, after: badge)
        col.setCustomSpacing(6, after: title)
        col.setCustomSpacing(14, after: message)
        col.setCustomSpacing(20, after: versions)
        col.setCustomSpacing(8, after: updateButton)
        view.addSubview(col)
        NSLayoutConstraint.activate([
            col.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            col.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            col.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            updateButton.widthAnchor.constraint(equalTo: col.widthAnchor),
            laterButton.widthAnchor.constraint(equalTo: col.widthAnchor)
        ])

        // Нижний лист
        modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            if let sheet = sheetPresentationController {
                if #available(iOS 16.0, *) {
                    sheet.detents = [
                        .custom(resolver: { _ in
                            return 470
                        })
                    ]
                } else {
                    sheet.detents = [.medium(), .large()]
                }
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = DS.Radius.sheet
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            }
        }
    }

    @objc private func updateTapped() {
        // Пытаемся открыть trackViewUrl (самый надежный способ)
        if let urlString = trackViewUrl, let url = URL(string: urlString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else if let trackId = trackId {
            // Fallback: используем trackId для прямого открытия страницы приложения
            if let url = URL(string: "https://apps.apple.com/ru/app/id\(trackId)") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        dismiss(animated: true)
    }
    
    @objc private func laterTapped() {
        dismiss(animated: true)
    }
}
