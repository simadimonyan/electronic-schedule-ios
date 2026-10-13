//
//  SettingsViewController.swift
//  raspisanie1
//
//  Created by Дмитрий Цепилов on 01.12.2024.
//

import UIKit
import MyTrackerSDK

class SettingsViewController: UIViewController {

    // Скролл-контейнер для всех настроек
    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsVerticalScrollIndicator = false
        scroll.alwaysBounceVertical = true
        return scroll
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let showFullScheduleSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        switchControl.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        return switchControl
    }()

    let removeGroupSelectionSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        switchControl.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        return switchControl
    }()

    let customCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        return view
    }()

    let customCardView2: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        return view
    }()

    let customCardView3: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        return view
    }()

    let customCardView4: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        return view
    }()

    let customCardView5: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        return view
    }()

    let customCardView6: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        return view
    }()

    let customCardView7: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        return view
    }()

    let customCardView8: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Показать всю неделю"
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()

    let removeGroupSelectionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Убрать выбор группы"
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()

    let changeWeekLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Сменить неделю"
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()

    let modeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Режим приложения"
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 0 // Разрешаем многострочный текст
        label.lineBreakMode = .byWordWrapping // Обрезаем по словам
        return label
    }()

    let notificationsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Уведомления о парах"
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()

    let syncWeekLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Синхронизировать неделю"
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()

    let aboutLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "О приложении"
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()

    // Карточка «Оставить отзыв» (опросы обратной связи)
    let feedbackCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        return view
    }()

    let feedbackLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Оставить отзыв"
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()

    let feedbackChevron: UIImageView = {
        let image = UIImageView(image: UIImage(systemName: "bubble.left.and.bubble.right"))
        image.translatesAutoresizingMaskIntoConstraints = false
        image.tintColor = .systemBlue
        image.contentMode = .scaleAspectFit
        return image
    }()

    let notificationTimeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Время уведомления"
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()

    let notificationTimeValueLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "5 минут"
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemBlue
        label.textAlignment = .right
        return label
    }()

    let notificationsSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        switchControl.addTarget(self, action: #selector(notificationsSwitchChanged), for: .valueChanged)
        return switchControl
    }()

    let notificationTimeSlider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumValue = 1
        slider.maximumValue = 30
        slider.value = 5
        slider.addTarget(self, action: #selector(notificationTimeSliderChanged), for: .valueChanged)
        return slider
    }()

    let syncWeekSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        switchControl.addTarget(self, action: #selector(syncWeekSwitchChanged), for: .valueChanged)
        return switchControl
    }()

    lazy var footerLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        self.updateFooterLabel(label)
        return label
    }()

    private func updateFooterLabel(_ label: UILabel) {
        // Создаем текст
        let text = NSMutableAttributedString(string: "По всем проблемам и предложениям пишите разработчику  ")

        // Выбираем иконку Telegram в зависимости от темы
        let telegramIconName: String
        if ThemeManager.current == .dark {
            telegramIconName = "telegram_white"
        } else if ThemeManager.current == .system {
            // Для системной темы проверяем текущую тему интерфейса
            let isDark = traitCollection.userInterfaceStyle == .dark
            telegramIconName = isDark ? "telegram_white" : "telegram"
        } else {
            telegramIconName = "telegram"
        }

        // Добавляем изображение Telegram
        if let telegramLogo = UIImage(named: telegramIconName) {
            let textAttachment = NSTextAttachment()
            textAttachment.image = telegramLogo

            // Настраиваем размер изображения
            let logoHeight: CGFloat = 16
            let logoRatio = telegramLogo.size.width / telegramLogo.size.height
            textAttachment.bounds = CGRect(x: 0, y: -4, width: logoHeight * logoRatio, height: logoHeight)

            let imageString = NSAttributedString(attachment: textAttachment)
            text.append(imageString)
        }

        // Добавляем текст с @tsepilo_v
        text.append(NSAttributedString(string: " @tsep1lov"))

        // Применяем атрибутированную строку к метке
        label.attributedText = text
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
    }

    // Высота блока с дополнительными настройками уведомлений (слайдер времени)
    private var notificationTimeHeightConstraint: NSLayoutConstraint?
    // Констрейнты положения карточки темы относительно уведомлений
    private var themeTopToNotificationsMainConstraint: NSLayoutConstraint?
    private var themeTopToNotificationTimeConstraint: NSLayoutConstraint?

    

    let changeWeekSegmentedControl: UISegmentedControl = {
        let segmentedControl = UISegmentedControl(items: ["Неделя 1", "Неделя 2"])
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.selectedSegmentIndex = UserDefaults.standard.bool(forKey: "isOddWeek") ? 0 : 1
        segmentedControl.addTarget(self, action: #selector(changeWeek), for: .valueChanged)
        return segmentedControl
    }()

    let themeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Тема"
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    let themeSegmentedControl: UISegmentedControl = {
        let segmentedControl = UISegmentedControl(items: ["Светлая", "Тёмная", "Системная"])
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        // Выставляем выбранный сегмент на основе текущей темы
        segmentedControl.selectedSegmentIndex = ThemeManager.current.rawValue
        segmentedControl.addTarget(self, action: #selector(themeChanged), for: .valueChanged)
        let font = UIFont.systemFont(ofSize: 12, weight: .medium)
        segmentedControl.setTitleTextAttributes([.font: font], for: .normal)
        segmentedControl.setTitleTextAttributes([.font: font], for: .selected)
        return segmentedControl
    }()

    let modeSegmentedControl: UISegmentedControl = {
        let segmentedControl = UISegmentedControl(items: ["Студент", "Препод."])
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.selectedSegmentIndex = UserDefaults.standard.bool(forKey: "isTeacherMode") ? 1 : 0
        segmentedControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        
        // Настраиваем размер шрифта для лучшего отображения
        let font = UIFont.systemFont(ofSize: 11, weight: .medium) // Уменьшаем размер шрифта
        segmentedControl.setTitleTextAttributes([.font: font], for: .normal)
        segmentedControl.setTitleTextAttributes([.font: font], for: .selected)
        
        return segmentedControl
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Отключаем все анимации с самого начала
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        view.backgroundColor = .systemGroupedBackground
        // Тема контролируется глобально через ThemeManager

        title = "Настройки"

        // Настройка scrollView
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        // Настройка кастомной ячейки
        contentView.addSubview(customCardView)
        customCardView.addSubview(titleLabel)
        customCardView.addSubview(showFullScheduleSwitch)

        // Настройка второй кастомной ячейки
        contentView.addSubview(customCardView2)
        customCardView2.addSubview(removeGroupSelectionLabel)
        customCardView2.addSubview(removeGroupSelectionSwitch)

        // Настройка третьей кастомной ячейки
        contentView.addSubview(customCardView3)
        customCardView3.addSubview(changeWeekLabel)
        customCardView3.addSubview(changeWeekSegmentedControl)

        // Настройка четвертой кастомной ячейки для режима
        contentView.addSubview(customCardView4)
        customCardView4.addSubview(modeLabel)
        customCardView4.addSubview(modeSegmentedControl)

        // Настройка пятой кастомной ячейки для уведомлений
        contentView.addSubview(customCardView5)
        customCardView5.addSubview(notificationsLabel)
        customCardView5.addSubview(notificationsSwitch)

        // Настройка шестой кастомной ячейки для времени уведомлений
        contentView.addSubview(customCardView6)
        customCardView6.addSubview(notificationTimeLabel)
        customCardView6.addSubview(notificationTimeValueLabel)
        customCardView6.addSubview(notificationTimeSlider)

        // Настройка седьмой кастомной ячейки для синхронизации недели
        contentView.addSubview(customCardView7)
        customCardView7.addSubview(syncWeekLabel)
        customCardView7.addSubview(syncWeekSwitch)

        // Настройка восьмой кастомной ячейки "О приложении"
        contentView.addSubview(customCardView8)
        customCardView8.addSubview(aboutLabel)
        let aboutTap = UITapGestureRecognizer(target: self, action: #selector(showAbout))
        customCardView8.addGestureRecognizer(aboutTap)

        // Карточка «Оставить отзыв» — под «О приложении»
        contentView.addSubview(feedbackCardView)
        feedbackCardView.addSubview(feedbackLabel)
        feedbackCardView.addSubview(feedbackChevron)
        let feedbackTap = UITapGestureRecognizer(target: self, action: #selector(showFeedback))
        feedbackCardView.addGestureRecognizer(feedbackTap)

        // Настройка девятой кастомной ячейки для темы
        let customCardView9: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = .secondarySystemBackground
            view.layer.cornerRadius = 12
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.shadowOpacity = 0.1
            view.layer.shadowOffset = CGSize(width: 0, height: 2)
            view.layer.shadowRadius = 4
            return view
        }()

        contentView.addSubview(customCardView9)
        customCardView9.addSubview(themeLabel)
        customCardView9.addSubview(themeSegmentedControl)

        // Добавление footerLabel внизу контента
        contentView.addSubview(footerLabel)
        

        NSLayoutConstraint.activate([
            customCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            customCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            customCardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            customCardView.heightAnchor.constraint(equalToConstant: 60),

            titleLabel.leadingAnchor.constraint(equalTo: customCardView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: customCardView.centerYAnchor),

            showFullScheduleSwitch.trailingAnchor.constraint(equalTo: customCardView.trailingAnchor, constant: -16),
            showFullScheduleSwitch.centerYAnchor.constraint(equalTo: customCardView.centerYAnchor),

            customCardView2.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            customCardView2.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            customCardView2.topAnchor.constraint(equalTo: customCardView.bottomAnchor, constant: 20),
            customCardView2.heightAnchor.constraint(equalToConstant: 60),

            removeGroupSelectionLabel.leadingAnchor.constraint(equalTo: customCardView2.leadingAnchor, constant: 16),
            removeGroupSelectionLabel.centerYAnchor.constraint(equalTo: customCardView2.centerYAnchor),

            removeGroupSelectionSwitch.trailingAnchor.constraint(equalTo: customCardView2.trailingAnchor, constant: -16),
            removeGroupSelectionSwitch.centerYAnchor.constraint(equalTo: customCardView2.centerYAnchor),

            customCardView3.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            customCardView3.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            customCardView3.topAnchor.constraint(equalTo: customCardView2.bottomAnchor, constant: 20),
            customCardView3.heightAnchor.constraint(equalToConstant: 60),

            changeWeekLabel.leadingAnchor.constraint(equalTo: customCardView3.leadingAnchor, constant: 16),
            changeWeekLabel.centerYAnchor.constraint(equalTo: customCardView3.centerYAnchor),

            changeWeekSegmentedControl.trailingAnchor.constraint(equalTo: customCardView3.trailingAnchor, constant: -16),
            changeWeekSegmentedControl.centerYAnchor.constraint(equalTo: customCardView3.centerYAnchor),

            customCardView4.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            customCardView4.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            customCardView4.topAnchor.constraint(equalTo: customCardView7.bottomAnchor, constant: 20),
            customCardView4.heightAnchor.constraint(equalToConstant: 60),

            modeLabel.leadingAnchor.constraint(equalTo: customCardView4.leadingAnchor, constant: 16),
            modeLabel.trailingAnchor.constraint(equalTo: modeSegmentedControl.leadingAnchor, constant: -16),
            modeLabel.centerYAnchor.constraint(equalTo: customCardView4.centerYAnchor),

            modeSegmentedControl.trailingAnchor.constraint(equalTo: customCardView4.trailingAnchor, constant: -16),
            modeSegmentedControl.centerYAnchor.constraint(equalTo: customCardView4.centerYAnchor),
            modeSegmentedControl.widthAnchor.constraint(equalToConstant: 200), // Увеличиваем ширину еще больше

            customCardView5.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            customCardView5.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            customCardView5.topAnchor.constraint(equalTo: customCardView4.bottomAnchor, constant: 20),
            customCardView5.heightAnchor.constraint(equalToConstant: 60),

            notificationsLabel.leadingAnchor.constraint(equalTo: customCardView5.leadingAnchor, constant: 16),
            notificationsLabel.centerYAnchor.constraint(equalTo: customCardView5.centerYAnchor),

            notificationsSwitch.trailingAnchor.constraint(equalTo: customCardView5.trailingAnchor, constant: -16),
            notificationsSwitch.centerYAnchor.constraint(equalTo: customCardView5.centerYAnchor),

            customCardView6.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            customCardView6.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            customCardView6.topAnchor.constraint(equalTo: customCardView5.bottomAnchor, constant: 20),
        ])

        // Отдельно сохраняем констрейнт высоты для анимации появления/скрытия
        notificationTimeHeightConstraint = customCardView6.heightAnchor.constraint(equalToConstant: 60)
        notificationTimeHeightConstraint?.isActive = true

        // Констрейнты для карточки темы: либо под основной карточкой уведомлений, либо под дополнительной
        themeTopToNotificationTimeConstraint = customCardView9.topAnchor.constraint(equalTo: customCardView6.bottomAnchor, constant: 20)
        themeTopToNotificationsMainConstraint = customCardView9.topAnchor.constraint(equalTo: customCardView5.bottomAnchor, constant: 20)

        // Активируем подходящий вариант в зависимости от текущего состояния переключателя
        if notificationsSwitch.isOn {
            themeTopToNotificationTimeConstraint?.isActive = true
        } else {
            themeTopToNotificationsMainConstraint?.isActive = true
        }

        NSLayoutConstraint.activate([

            notificationTimeLabel.leadingAnchor.constraint(equalTo: customCardView6.leadingAnchor, constant: 16),
            notificationTimeLabel.centerYAnchor.constraint(equalTo: customCardView6.centerYAnchor),

            notificationTimeValueLabel.trailingAnchor.constraint(equalTo: customCardView6.trailingAnchor, constant: -16),
            notificationTimeValueLabel.centerYAnchor.constraint(equalTo: customCardView6.centerYAnchor),

            notificationTimeSlider.leadingAnchor.constraint(equalTo: notificationTimeLabel.trailingAnchor, constant: 10),
            notificationTimeSlider.trailingAnchor.constraint(equalTo: notificationTimeValueLabel.leadingAnchor, constant: -10),
            notificationTimeSlider.centerYAnchor.constraint(equalTo: customCardView6.centerYAnchor),

            customCardView7.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            customCardView7.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            customCardView7.topAnchor.constraint(equalTo: customCardView3.bottomAnchor, constant: 20),
            customCardView7.heightAnchor.constraint(equalToConstant: 60),

            syncWeekLabel.leadingAnchor.constraint(equalTo: customCardView7.leadingAnchor, constant: 16),
            syncWeekLabel.centerYAnchor.constraint(equalTo: customCardView7.centerYAnchor),

            syncWeekSwitch.trailingAnchor.constraint(equalTo: customCardView7.trailingAnchor, constant: -16),
            syncWeekSwitch.centerYAnchor.constraint(equalTo: customCardView7.centerYAnchor),

            // Карточка темы сразу после уведомлений
            customCardView9.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            customCardView9.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            customCardView9.heightAnchor.constraint(equalToConstant: 60),

            themeLabel.leadingAnchor.constraint(equalTo: customCardView9.leadingAnchor, constant: 16),
            themeLabel.trailingAnchor.constraint(equalTo: themeSegmentedControl.leadingAnchor, constant: -16),
            themeLabel.centerYAnchor.constraint(equalTo: customCardView9.centerYAnchor),

            themeSegmentedControl.trailingAnchor.constraint(equalTo: customCardView9.trailingAnchor, constant: -16),
            themeSegmentedControl.centerYAnchor.constraint(equalTo: customCardView9.centerYAnchor),

            // "О приложении" ниже темы
            customCardView8.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            customCardView8.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            customCardView8.topAnchor.constraint(equalTo: customCardView9.bottomAnchor, constant: 20),
            customCardView8.heightAnchor.constraint(equalToConstant: 60),

            aboutLabel.leadingAnchor.constraint(equalTo: customCardView8.leadingAnchor, constant: 16),
            aboutLabel.centerYAnchor.constraint(equalTo: customCardView8.centerYAnchor),

            footerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            footerLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            footerLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            feedbackCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            feedbackCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            feedbackCardView.topAnchor.constraint(equalTo: customCardView8.bottomAnchor, constant: 20),
            feedbackCardView.heightAnchor.constraint(equalToConstant: 60),

            feedbackLabel.leadingAnchor.constraint(equalTo: feedbackCardView.leadingAnchor, constant: 16),
            feedbackLabel.centerYAnchor.constraint(equalTo: feedbackCardView.centerYAnchor),

            feedbackChevron.trailingAnchor.constraint(equalTo: feedbackCardView.trailingAnchor, constant: -16),
            feedbackChevron.centerYAnchor.constraint(equalTo: feedbackCardView.centerYAnchor),
            feedbackChevron.widthAnchor.constraint(equalToConstant: 24),
            feedbackChevron.heightAnchor.constraint(equalToConstant: 24),

            footerLabel.topAnchor.constraint(greaterThanOrEqualTo: feedbackCardView.bottomAnchor, constant: 24)
        ])

        // Загрузка состояния переключателей из UserDefaults
        let isFullScheduleEnabled = UserDefaults.standard.bool(forKey: "showFullSchedule")
        showFullScheduleSwitch.isOn = isFullScheduleEnabled

        applyCorrespondenceFullWeekAvailability()

        let isGroupSelectionRemoved = UserDefaults.standard.bool(forKey: "removeGroupSelection")
        removeGroupSelectionSwitch.isOn = isGroupSelectionRemoved

        // Загрузка настроек уведомлений
        let notificationManager = NotificationManager.shared
        notificationsSwitch.isOn = notificationManager.isNotificationsEnabled
        notificationTimeSlider.value = Float(notificationManager.notificationTimeMinutes)
        updateNotificationTimeLabel()
        
        // Показываем/скрываем слайдер времени в зависимости от состояния уведомлений
        updateNotificationTimeVisibility()
        
        // Отладочная информация
        notificationManager.debugNotifications()
        notificationManager.checkNotificationPermissions { _ in }

        // Настройка цветов навигации (заголовок и кнопка "Назад")
        updateNavigationBarColors()

        // Загрузка настройки синхронизации недели
        let isSyncEnabled = UserDefaults.standard.bool(forKey: "syncWeekEnabled")
        syncWeekSwitch.isOn = isSyncEnabled
        applySyncWeekUIState(isEnabled: isSyncEnabled)
        if isSyncEnabled {
            syncWeekWithServer(applyOnlyUI: false)
        }
        
        // Принудительно устанавливаем все элементы в финальные позиции без анимации
        // Это нужно сделать до того, как view появится на экране
        view.setNeedsLayout()
        view.layoutIfNeeded()
        scrollView.setNeedsLayout()
        scrollView.layoutIfNeeded()
        contentView.setNeedsLayout()
        contentView.layoutIfNeeded()
        
        // Убеждаемся, что все элементы находятся на своих местах
        // и не имеют никаких transform или смещений
        let allViews: [UIView] = [
            customCardView, customCardView2, customCardView3, customCardView4,
            customCardView5, customCardView6, customCardView7, customCardView8, feedbackCardView
        ]
        for cardView in allViews {
            cardView.transform = .identity
            if cardView != customCardView6 { // customCardView6 может иметь alpha < 1.0 если уведомления выключены
                cardView.alpha = 1.0
            }
        }
        // Обрабатываем scrollView и contentView отдельно, так как они не опциональные
        scrollView.transform = .identity
        contentView.transform = .identity
        
        CATransaction.commit()
    }

    @objc func changeWeek() {
        // Если синхронизация включена — запрещаем ручную смену
        if UserDefaults.standard.bool(forKey: "syncWeekEnabled") {
            // Возвращаем выбранный индекс к текущему значению
            let isOdd = UserDefaults.standard.bool(forKey: "isOddWeek")
            changeWeekSegmentedControl.selectedSegmentIndex = isOdd ? 0 : 1
            return
        }
        // Переключаем неделю
        let currentWeek = UserDefaults.standard.bool(forKey: "isOddWeek")
        let newWeek = !currentWeek
        UserDefaults.standard.set(newWeek, forKey: "isOddWeek")
        
        // Трекинг события
        if newWeek {
            MRMyTracker.trackEvent(name: "Переключить расписание на первую неделю")
        } else {
            MRMyTracker.trackEvent(name: "Переключить расписание на вторую неделю")
        }

        // Обновляем состояние сегментного контрола
        changeWeekSegmentedControl.selectedSegmentIndex = newWeek ? 0 : 1

        // Отправляем нотификацию для обновления расписания
        NotificationCenter.default.post(name: Notification.Name("reloadSchedule"), object: nil)
    }

    @objc func modeChanged(_ sender: UISegmentedControl) {
        let isTeacherMode = sender.selectedSegmentIndex == 1
        UserDefaults.standard.set(isTeacherMode, forKey: "isTeacherMode")
        
        // Трекинг события
        if isTeacherMode {
            MRMyTracker.trackEvent(name: "Включить режим преподавателя")
        } else {
            MRMyTracker.trackEvent(name: "Включить режим студента")
        }
        
        // Удаляем уведомления при смене режима
        let notificationManager = NotificationManager.shared
        notificationManager.removeAllNotifications()
        print("🗑️ Уведомления удалены при смене режима на \(isTeacherMode ? "преподавателя" : "студента")")
        
        // Отправляем нотификацию для обновления режима
        NotificationCenter.default.post(name: Notification.Name("modeChanged"), object: nil)
    }

    @objc func switchChanged(_ sender: UISwitch) {
        if sender == showFullScheduleSwitch {
            // Save the switch state to UserDefaults
            UserDefaults.standard.set(sender.isOn, forKey: "showFullSchedule")
            
            // Трекинг события
            if sender.isOn {
                MRMyTracker.trackEvent(name: "Включить расписание на неделю")
            } else {
                MRMyTracker.trackEvent(name: "Выключить расписание на неделю")
            }
        } else if sender == removeGroupSelectionSwitch {
            // Save the switch state to UserDefaults
            UserDefaults.standard.set(sender.isOn, forKey: "removeGroupSelection")
            
            // Трекинг события
            if sender.isOn {
                MRMyTracker.trackEvent(name: "Выключить видимость навигации")
            } else {
                MRMyTracker.trackEvent(name: "Включить видимость навигации")
            }

            // Update the tab bar access in MainViewController
            if let mainVC = self.navigationController?.viewControllers.first as? MainViewController {
                mainVC.updateTabBarAccess(isGroupSelectionRemoved: sender.isOn)
            }
        }
    }

    @objc func backButtonTapped() {
        MRMyTracker.trackEvent(name: "Выйти из экрана настроек")
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc private func showFeedback() {
        MRMyTracker.trackEvent(name: "Открыть опрос из настроек")
        SurveyManager.shared.openFromSettings(from: self)
    }

    @objc private func showAbout() {
        MRMyTracker.trackEvent(name: "Открыть вкладку о приложении")
        let vc = AboutViewController()
        present(vc, animated: true)
    }
    
    private func updateNotificationTimeLabel() {
        let minutes = Int(notificationTimeSlider.value)
        notificationTimeValueLabel.text = "\(minutes) \(getMinutesText(minutes))"
    }
    
    private func updateNotificationTimeVisibility() {
        let isEnabled = notificationsSwitch.isOn
        notificationTimeSlider.isEnabled = isEnabled
        notificationTimeValueLabel.alpha = isEnabled ? 1.0 : 0.5

        // Анимированно показываем/скрываем блок дополнительных настроек,
        // чтобы не было пустого пространства
        let targetHeight: CGFloat = isEnabled ? 60 : 0
        notificationTimeHeightConstraint?.constant = targetHeight

        // Переключаем вертикальный констрейнт для карточки темы,
        // чтобы отступ между "Уведомления" и "Тема" всегда был как у остальных блоков
        if isEnabled {
            themeTopToNotificationsMainConstraint?.isActive = false
            themeTopToNotificationTimeConstraint?.isActive = true
        } else {
            themeTopToNotificationTimeConstraint?.isActive = false
            themeTopToNotificationsMainConstraint?.isActive = true
        }

        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
            self.customCardView6.alpha = isEnabled ? 1.0 : 0.0
        }
    }
    
    private func getMinutesText(_ minutes: Int) -> String {
        let lastDigit = minutes % 10
        let lastTwoDigits = minutes % 100
        
        if lastTwoDigits >= 11 && lastTwoDigits <= 19 {
            return "минут"
        }
        
        switch lastDigit {
        case 1:
            return "минута"
        case 2, 3, 4:
            return "минуты"
        default:
            return "минут"
        }
    }
    
    @objc func notificationsSwitchChanged(_ sender: UISwitch) {
        let notificationManager = NotificationManager.shared
        notificationManager.isNotificationsEnabled = sender.isOn
        
        // Трекинг события
        if sender.isOn {
            MRMyTracker.trackEvent(name: "Включить уведомления расписания")
        } else {
            MRMyTracker.trackEvent(name: "Выключить уведомления расписания")
        }
        
        if sender.isOn {
            // Запрашиваем разрешение на уведомления
            notificationManager.requestNotificationPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.updateNotificationTimeVisibility()
                        // Немедленно перепланируем уведомления
                        self.rescheduleNotifications()
                    } else {
                        sender.isOn = false
                        notificationManager.isNotificationsEnabled = false
                        let alert = UIAlertController(title: "Разрешение не получено", message: "Для работы уведомлений необходимо разрешить их в настройках", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        } else {
            // Удаляем все уведомления
            notificationManager.removeAllNotifications()
            updateNotificationTimeVisibility()
        }
    }
    
    @objc func notificationTimeSliderChanged(_ sender: UISlider) {
        let minutes = Int(sender.value)
        let notificationManager = NotificationManager.shared
        notificationManager.notificationTimeMinutes = minutes
        
        updateNotificationTimeLabel()
        
        // Перепланируем уведомления с новым временем
        rescheduleNotifications()
    }
    
    private func rescheduleNotifications() {
        let notificationManager = NotificationManager.shared
        
        // Проверяем режим: уведомления только для студентов
        let isTeacherMode = UserDefaults.standard.bool(forKey: "isTeacherMode")
        if isTeacherMode {
            print("ℹ️ Режим преподавателя: уведомления не планируются")
            return
        }
        
        // Проверяем, есть ли сохраненное расписание
        let hasSchedule = UserDefaults.standard.string(forKey: "selectedGroupURL") != nil
        
        guard hasSchedule else {
            print("ℹ️ Нет сохраненного расписания для перепланирования уведомлений")
            return
        }
        
        // Пытаемся найти сохраненное расписание в UserDefaults
        if let scheduleData = UserDefaults.standard.data(forKey: "savedSchedule"),
           let schedule = try? JSONDecoder().decode([DaySchedule].self, from: scheduleData) {
            // Перепланируем уведомления с сохраненным расписанием (только для студентов)
            notificationManager.scheduleNotifications(for: schedule, isTeacherMode: false)
            print("✅ Уведомления перепланированы с сохраненным расписанием")
        } else {
            // Если нет сохраненного расписания, удаляем старые уведомления
            notificationManager.removeAllNotifications()
            print("🔄 Уведомления будут перепланированы при следующем открытии расписания")
        }
    }

    // MARK: - Sync Week
    @objc private func syncWeekSwitchChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: "syncWeekEnabled")
        
        // Трекинг события
        if sender.isOn {
            MRMyTracker.trackEvent(name: "Включить синхронизацию недели")
        } else {
            MRMyTracker.trackEvent(name: "Выключить синхронизацию недели")
        }
        
        applySyncWeekUIState(isEnabled: sender.isOn)
        if sender.isOn {
            syncWeekWithServer(applyOnlyUI: false)
        }
    }

    private func applySyncWeekUIState(isEnabled: Bool) {
        changeWeekSegmentedControl.isEnabled = !isEnabled
        changeWeekLabel.textColor = isEnabled ? .secondaryLabel : .label
    }

    // MARK: - Theme
    @objc private func themeChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case AppTheme.light.rawValue:
            ThemeManager.current = .light
        case AppTheme.dark.rawValue:
            ThemeManager.current = .dark
        case AppTheme.system.rawValue:
            ThemeManager.current = .system
        default:
            ThemeManager.current = .system
        }
        // Обновляем иконку Telegram в footerLabel при изменении темы
        updateFooterLabel(footerLabel)
        // Обновляем цвета навигации немедленно и с задержкой для надежности
        updateNavigationBarColors()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateNavigationBarColors()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // Обновляем иконку Telegram при смене системной темы (если выбрана системная тема)
        if ThemeManager.current == .system,
           traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            updateFooterLabel(footerLabel)
            // Обновляем цвета навигации при смене системной темы
            updateNavigationBarColors()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Актуализируем доступность "Показать всю неделю" при каждом открытии настроек.
        applyCorrespondenceFullWeekAvailability()

        // Отключаем все анимации перед появлением view
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Обновляем цвета навигации при каждом появлении экрана
        updateNavigationBarColors()

        // Гарантируем правильное состояние блока времени уведомлений ДО фикса альфы/лейаута
        updateNotificationTimeVisibility()
        
        // Убеждаемся, что все элементы находятся на своих местах без transform
        let allViews: [UIView] = [
            customCardView, customCardView2, customCardView3, customCardView4,
            customCardView5, customCardView6, customCardView7, customCardView8, feedbackCardView
        ]
        for cardView in allViews {
            cardView.transform = .identity
            if cardView == customCardView6 {
                // Не даём блоку "Время уведомления" появляться при выключенных уведомлениях
                cardView.alpha = notificationsSwitch.isOn ? 1.0 : 0.0
            } else {
                cardView.alpha = 1.0
            }
        }
        
        // Принудительно обновляем layout, чтобы все элементы были на своих местах
        view.setNeedsLayout()
        view.layoutIfNeeded()
        scrollView.setNeedsLayout()
        scrollView.layoutIfNeeded()
        contentView.setNeedsLayout()
        contentView.layoutIfNeeded()
        
        CATransaction.commit()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Дополнительно обновляем layout после появления для гарантии
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Убеждаемся, что все элементы находятся на своих местах
        let allViews: [UIView] = [
            customCardView, customCardView2, customCardView3, customCardView4,
            customCardView5, customCardView6, customCardView7, customCardView8, feedbackCardView
        ]
        for cardView in allViews {
            cardView.transform = .identity
        }
        
        view.layoutIfNeeded()
        scrollView.layoutIfNeeded()
        contentView.layoutIfNeeded()
        CATransaction.commit()

        #if DEBUG
        // Демонстрация опросов: прокрутить к «Оставить отзыв»
        if SurveysDebug.openSettings {
            let rect = feedbackCardView.convert(feedbackCardView.bounds, to: scrollView).insetBy(dx: 0, dy: -20)
            scrollView.scrollRectToVisible(rect, animated: true)
        }
        #endif
    }
    
    private func updateNavigationBarColors() {
        // Определяем цвет на основе текущей темы из ThemeManager
        // Используем resolvedColor для правильного разрешения динамического цвета
        let textColor: UIColor
        switch ThemeManager.current {
        case .light:
            // Для светлой темы используем черный цвет
            textColor = UIColor.label.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        case .dark:
            // Для темной темы используем белый цвет
            textColor = UIColor.label.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        case .system:
            // Для системной темы используем текущий traitCollection
            textColor = UIColor.label.resolvedColor(with: traitCollection)
        }
        
        // Принудительно обновляем цвет заголовка навигации
        navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: textColor
        ]
        
        // Обновляем цвет кнопки "Назад", пересоздавая её для гарантии обновления
        let backButton = UIBarButtonItem(title: "Назад", style: .plain, target: self, action: #selector(backButtonTapped))
        backButton.tintColor = textColor
        navigationItem.leftBarButtonItem = backButton
        
        // Принудительно обновляем навигационную панель
        if let navBar = navigationController?.navigationBar {
            navBar.setNeedsLayout()
            navBar.layoutIfNeeded()
            navBar.setNeedsDisplay()
        }
        
        // Также обновляем сам view для гарантии
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    private func applyCorrespondenceFullWeekAvailability() {
        // Заочная группа определяется либо по уровню, либо по флагу активного режима сессии.
        let selectedLevel = UserDefaults.standard.string(forKey: "selectedGroupLevel") ?? ""
        let isCorrespondenceByLevel = selectedLevel.lowercased().contains("заочн")
        let isCorrespondenceModeActive = UserDefaults.standard.bool(forKey: "correspondenceModeActive")
        let isCorrespondence = isCorrespondenceByLevel || isCorrespondenceModeActive

        if isCorrespondence {
            showFullScheduleSwitch.setOn(false, animated: false)
            showFullScheduleSwitch.isEnabled = false
            showFullScheduleSwitch.alpha = 0.5
            titleLabel.textColor = .secondaryLabel
            UserDefaults.standard.set(false, forKey: "showFullSchedule")

            // Для заочки смена недели тоже неактуальна (расписание по датам/сессии)
            changeWeekSegmentedControl.isEnabled = false
            changeWeekSegmentedControl.alpha = 0.5
            changeWeekLabel.textColor = .secondaryLabel
        } else {
            showFullScheduleSwitch.isEnabled = true
            showFullScheduleSwitch.alpha = 1.0
            titleLabel.textColor = .label
            showFullScheduleSwitch.isOn = UserDefaults.standard.bool(forKey: "showFullSchedule")

            // Возвращаем доступность смены недели только если синхронизация недели выключена
            let syncEnabled = UserDefaults.standard.bool(forKey: "syncWeekEnabled")
            changeWeekSegmentedControl.isEnabled = !syncEnabled
            changeWeekSegmentedControl.alpha = (!syncEnabled) ? 1.0 : 0.5
            changeWeekLabel.textColor = syncEnabled ? .secondaryLabel : .label
        }
    }

    private func syncWeekWithServer(applyOnlyUI: Bool) {
        ScheduleRepository.shared.getWeekCount { result in
            switch result {
            case .success(let week):
                let isOdd = (week == 1)
                UserDefaults.standard.set(isOdd, forKey: "isOddWeek")
                DispatchQueue.main.async {
                    self.changeWeekSegmentedControl.selectedSegmentIndex = isOdd ? 0 : 1
                }
                if !applyOnlyUI {
                    NotificationCenter.default.post(name: Notification.Name("reloadSchedule"), object: nil)
                }
            case .failure:
                break
            }
        }
    }
}









