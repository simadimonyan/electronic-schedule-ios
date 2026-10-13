//
//  MainViewController.swift
//  schedule
//
//  Created by Дмитрий Цепилов on 30.11.2024.
//

import UIKit
import MyTrackerSDK

protocol GroupSelectionDelegate: AnyObject {
    func didSelectGroup(withURL url: String)
}

protocol TeacherSelectionDelegate: AnyObject {
    func didSelectTeacher(withURL url: String)
}

class MainViewController: UIViewController, GroupSelectionDelegate, TeacherSelectionDelegate {
    var firstVC: ViewController!
    var secondVC: TwoViewController!
    var teacherFirstVC: TeacherViewController!
    var teacherSecondVC: TeacherScheduleViewController!
    
    private var isTeacherMode: Bool = false
    private var currentAnimationVC: ModeSwitchAnimationViewController?

    private var customTabBar: UIView!
    private var tabBarContainer: UIView!
    private var listButton: UIButton!
    private var calendarButton: UIButton!
    private var currentItemIndex: Int = 0
    private var indicatorView: UIView!
    private var indicatorLeadingConstraint: NSLayoutConstraint!
    private var isFirstLayout: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        // Инициализация контроллеров для режима студента
        firstVC = ViewController()
        secondVC = TwoViewController()

        // Инициализация контроллеров для режима преподавателя
        teacherFirstVC = TeacherViewController()
        teacherSecondVC = TeacherScheduleViewController()

        // Установка делегатов
        firstVC.delegate = self
        teacherFirstVC.delegate = self

        // Добавляем контроллеры режима студента как дочерние
        addChild(firstVC)
        view.addSubview(firstVC.view)
        firstVC.didMove(toParent: self)

        addChild(secondVC)
        view.addSubview(secondVC.view)
        secondVC.didMove(toParent: self)

        secondVC.view.frame.origin.x = self.view.bounds.width // Начальная позиция второго контроллера (спрятан справа)

        // Добавляем контроллеры режима преподавателя как дочерние (изначально скрыты)
        addChild(teacherFirstVC)
        view.addSubview(teacherFirstVC.view)
        teacherFirstVC.didMove(toParent: self)
        teacherFirstVC.view.isHidden = true

        addChild(teacherSecondVC)
        view.addSubview(teacherSecondVC.view)
        teacherSecondVC.didMove(toParent: self)
        teacherSecondVC.view.isHidden = true
        teacherSecondVC.view.frame.origin.x = self.view.bounds.width

        // Настроим кастомный таббар
        setupTabBar()
        
        // Загружаем сохраненный режим
        loadSavedMode()

        // Проверка состояния переключателя для удаления выбора группы
        let isGroupSelectionRemoved = UserDefaults.standard.bool(forKey: "removeGroupSelection")
        updateTabBarAccess(isGroupSelectionRemoved: isGroupSelectionRemoved)

        if let selectedGroupURL = UserDefaults.standard.string(forKey: "selectedGroupURL") {
            // Теперь здесь хранится имя группы
            secondVC.selectedGroupURL = selectedGroupURL
            secondVC.loadTimetableData()
        }
        
        // Подписываемся на нотификацию об изменении режима
        NotificationCenter.default.addObserver(self, selector: #selector(handleModeChange), name: Notification.Name("modeChanged"), object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Показываем окно с информацией о виджетах через 10 секунд после запуска
        showWidgetInfoIfNeeded()

        // Опрос обратной связи: проверка не чаще раза в сутки, с учётом «Не сейчас»
        SurveyManager.shared.scheduleScreenDidAppear(from: self)
    }
    
    private func showWidgetInfoIfNeeded() {
        // Проверяем, было ли уже показано окно
        let hasSeenWidgetInfo = UserDefaults.standard.bool(forKey: "hasSeenWidgetInfo")
        
        if !hasSeenWidgetInfo {
            // Показываем через 10 секунд
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                // Проверяем еще раз, чтобы избежать показа, если пользователь уже закрыл окно
                if !UserDefaults.standard.bool(forKey: "hasSeenWidgetInfo") {
                    let widgetInfoVC = WidgetInfoViewController()
                    widgetInfoVC.modalPresentationStyle = .overFullScreen
                    widgetInfoVC.modalTransitionStyle = .crossDissolve
                    self.present(widgetInfoVC, animated: true)
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func loadSavedMode() {
        // Проверяем, есть ли сохраненный режим, если нет - устанавливаем режим студента по умолчанию
        if UserDefaults.standard.object(forKey: "isTeacherMode") == nil {
            UserDefaults.standard.set(false, forKey: "isTeacherMode")
        }
        
        let savedMode = UserDefaults.standard.bool(forKey: "isTeacherMode")
        if savedMode != isTeacherMode {
            isTeacherMode = savedMode
            switchMode()
        }
    }
    
    @objc private func handleModeChange() {
        let newMode = UserDefaults.standard.bool(forKey: "isTeacherMode")
        
        // Если режим не изменился, ничего не делаем
        if newMode == isTeacherMode {
            return
        }
        
        // Показываем анимацию переключения режимов
        showModeSwitchAnimation {
            // Анимация завершена, ничего дополнительно не делаем
        }
        
        // Переключаем режим во время показа анимации (когда пользователь не видит экран)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isTeacherMode = newMode
            self.switchMode()
        }
    }

    // Реализация методов протоколов
    func didSelectGroup(withURL url: String) {
        if !isTeacherMode {
            // Очищаем старое расписание при смене группы
            if secondVC.selectedGroupURL != url {
                secondVC.fullSchedule = []
                secondVC.schedule = []
                UserDefaults.standard.removeObject(forKey: "correspondenceSelectedISODate")
                UserDefaults.standard.set(false, forKey: "correspondenceModeActive")
            }
            
            // Теперь сюда приходит имя группы
            secondVC.selectedGroupURL = url
            secondVC.loadTimetableData()

            // Переход на вторую view
            UIView.animate(withDuration: 0.3, animations: {
                self.firstVC.view.frame.origin.x = -self.view.bounds.width
                self.secondVC.view.frame.origin.x = 0
            })

            // Обновление таб бара
            currentItemIndex = 1
            updateTabBarButtons()
            updateIndicatorPosition(animated: true)
            updateTabBar()
        }
    }
    
    func didSelectTeacher(withURL url: String) {
        if isTeacherMode {
            // Очищаем старое расписание при смене преподавателя
            if teacherSecondVC.selectedTeacherURL != url {
                teacherSecondVC.fullSchedule = []
                teacherSecondVC.schedule = []
            }
            
            teacherSecondVC.selectedTeacherURL = url
            teacherSecondVC.loadTimetableData()

            // Переход на вторую view
            UIView.animate(withDuration: 0.3, animations: {
                self.teacherFirstVC.view.frame.origin.x = -self.view.bounds.width
                self.teacherSecondVC.view.frame.origin.x = 0
            })

            // Обновление таб бара
            currentItemIndex = 1
            updateTabBarButtons()
            updateIndicatorPosition(animated: true)
            updateTabBar()
        }
    }

    private func updateTabBar() {
        if currentItemIndex == 0 {
            // Плавное скольжение для первого контроллера
            if isTeacherMode {
                UIView.animate(withDuration: 0.3, animations: {
                    self.teacherFirstVC.view.frame.origin.x = 0
                    self.teacherSecondVC.view.frame.origin.x = self.view.bounds.width
                })
            } else {
                UIView.animate(withDuration: 0.3, animations: {
                    self.firstVC.view.frame.origin.x = 0
                    self.secondVC.view.frame.origin.x = self.view.bounds.width
                })
            }
        } else {
            // Плавное скольжение для второго контроллера
            if isTeacherMode {
                UIView.animate(withDuration: 0.3, animations: {
                    self.teacherFirstVC.view.frame.origin.x = -self.view.bounds.width
                    self.teacherSecondVC.view.frame.origin.x = 0
                })
            } else {
                UIView.animate(withDuration: 0.3, animations: {
                    self.firstVC.view.frame.origin.x = -self.view.bounds.width
                    self.secondVC.view.frame.origin.x = 0
                })
            }
        }
    }


    private func setupTabBar() {
        // Создаем контейнер для таб бара
        tabBarContainer = UIView()
        tabBarContainer.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(tabBarContainer)

        NSLayoutConstraint.activate([
            tabBarContainer.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            tabBarContainer.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 40),
            tabBarContainer.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -40),
            tabBarContainer.heightAnchor.constraint(equalToConstant: 70)
        ])

        // Тень для контейнера
        tabBarContainer.layer.shadowColor = UIColor.black.cgColor
        tabBarContainer.layer.shadowOffset = CGSize(width: 0, height: 4)
        tabBarContainer.layer.shadowOpacity = 0.2
        tabBarContainer.layer.shadowRadius = 10

        // Создаем кастомный таб бар - непрозрачный белый контейнер
        customTabBar = UIView()
        customTabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainer.addSubview(customTabBar)

        NSLayoutConstraint.activate([
            customTabBar.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor),
            customTabBar.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor),
            customTabBar.topAnchor.constraint(equalTo: tabBarContainer.topAnchor),
            customTabBar.bottomAnchor.constraint(equalTo: tabBarContainer.bottomAnchor)
        ])

        // Непрозрачный фон без стеклянного эффекта
        customTabBar.backgroundColor = .secondarySystemBackground
        customTabBar.layer.cornerRadius = 20
        customTabBar.layer.masksToBounds = true

        // Создаем кнопки для таб бара
        listButton = UIButton(type: .custom)
        listButton.translatesAutoresizingMaskIntoConstraints = false
        calendarButton = UIButton(type: .custom)
        calendarButton.translatesAutoresizingMaskIntoConstraints = false

        customTabBar.addSubview(listButton)
        customTabBar.addSubview(calendarButton)

        // Настройка кнопок
        listButton.addTarget(self, action: #selector(listButtonTapped), for: .touchUpInside)
        calendarButton.addTarget(self, action: #selector(calendarButtonTapped), for: .touchUpInside)
        
        // Устанавливаем renderingMode для кнопок, чтобы tintColor работал правильно
        listButton.imageView?.contentMode = .scaleAspectFit
        calendarButton.imageView?.contentMode = .scaleAspectFit

        // Настройка контента кнопок с отступами (поднимаем иконки выше)
        listButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 0, bottom: 20, right: 0)
        calendarButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 0, bottom: 20, right: 0)
        
        // Расположение кнопок
        NSLayoutConstraint.activate([
            listButton.leadingAnchor.constraint(equalTo: customTabBar.leadingAnchor),
            listButton.topAnchor.constraint(equalTo: customTabBar.topAnchor),
            listButton.bottomAnchor.constraint(equalTo: customTabBar.bottomAnchor),
            listButton.widthAnchor.constraint(equalTo: customTabBar.widthAnchor, multiplier: 0.5),
            
            calendarButton.trailingAnchor.constraint(equalTo: customTabBar.trailingAnchor),
            calendarButton.topAnchor.constraint(equalTo: customTabBar.topAnchor),
            calendarButton.bottomAnchor.constraint(equalTo: customTabBar.bottomAnchor),
            calendarButton.widthAnchor.constraint(equalTo: customTabBar.widthAnchor, multiplier: 0.5)
        ])

        addIndicatorView()
        updateTabBarButtons()
    }


    private func resizeAndTintImage(named imageName: String, size: CGSize, color: UIColor) -> UIImage? {
        guard let originalImage = UIImage(named: imageName) else {
            return nil
        }

        // Изменяем размер изображения
        let resizedImage = UIGraphicsImageRenderer(size: size).image { _ in
            originalImage.draw(in: CGRect(origin: .zero, size: size))
        }
        
        // Возвращаем как template, чтобы можно было применить цвет через tintColor
        return resizedImage.withRenderingMode(.alwaysTemplate)
    }

    private func addIndicatorView() {
        indicatorView = UIView()
        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        indicatorView.backgroundColor = UIColor(red: 13/255, green: 128/255, blue: 255/255, alpha: 1.0)
        indicatorView.layer.cornerRadius = 2
        customTabBar.addSubview(indicatorView)

        // Создаем constraint для начальной позиции (будет обновлен в viewDidLayoutSubviews)
        indicatorLeadingConstraint = indicatorView.leadingAnchor.constraint(equalTo: customTabBar.leadingAnchor, constant: 0)
        
        NSLayoutConstraint.activate([
            indicatorView.bottomAnchor.constraint(equalTo: customTabBar.bottomAnchor, constant: -12),
            indicatorView.widthAnchor.constraint(equalToConstant: 45),
            indicatorView.heightAnchor.constraint(equalToConstant: 4),
            indicatorLeadingConstraint
        ])

        // Сразу позиционируем индикатор под активной вкладкой
        indicatorView.alpha = 1
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Обновляем позицию индикатора только если layout изменился
        if customTabBar.frame.width > 0 && indicatorLeadingConstraint != nil {
            // Используем constraint вместо frame для более надежной работы
            let targetX = calculateIndicatorXPosition()
            if abs(indicatorLeadingConstraint.constant - targetX) > 0.1 {
                // При первом layout устанавливаем позицию синхронно и без анимации
                if isFirstLayout {
                    indicatorLeadingConstraint.constant = targetX
                    isFirstLayout = false
                } else {
                    DispatchQueue.main.async {
                        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                            self.indicatorLeadingConstraint.constant = targetX
                            self.view.layoutIfNeeded()
                        })
                    }
                }
            } else if isFirstLayout {
                // Если позиция уже правильная, просто помечаем что первый layout прошел
                isFirstLayout = false
            }
        }
    }

    private func calculateIndicatorXPosition() -> CGFloat {
        guard customTabBar.frame.width > 0 else { return 0 }
        let itemWidth = customTabBar.frame.width / 2.0
        return CGFloat(currentItemIndex) * itemWidth + itemWidth / 2 - 22.5 // 22.5 = половина ширины индикатора (45/2)
    }

    @objc private func listButtonTapped() {
        currentItemIndex = 0
        MRMyTracker.trackEvent(name: "Перейти на главный экран")
        updateTabBarButtons()
        updateTabBar()
        updateIndicatorPosition(animated: true)
        
        // При каждом переключении на главный экран обновляем баннер
        if isTeacherMode {
            teacherFirstVC.refreshAdBannerIfNeeded()
        } else {
            firstVC.refreshAdBannerIfNeeded()
        }
    }

    @objc private func calendarButtonTapped() {
        currentItemIndex = 1
        MRMyTracker.trackEvent(name: "Перейти на экран расписания")
        updateTabBarButtons()
        updateTabBar()
        updateIndicatorPosition(animated: true)
    }

    private func updateTabBarButtons() {
        let activeColor = UIColor(red: 13/255, green: 128/255, blue: 255/255, alpha: 1.0)
        let inactiveColor = UIColor.gray

        // Создаем изображения как template (один раз для каждой иконки)
        let listImage = resizeAndTintImage(named: "list", size: CGSize(width: 35, height: 35), color: activeColor)
        let calendarImage = resizeAndTintImage(named: "calendar", size: CGSize(width: 35, height: 35), color: activeColor)

        // Активная иконка - синяя, неактивная - серая
        if currentItemIndex == 0 {
            // Первая вкладка активна - синяя, вторая неактивна - серая
            listButton.setImage(listImage, for: .normal)
            listButton.tintColor = activeColor
            
            calendarButton.setImage(calendarImage, for: .normal)
            calendarButton.tintColor = inactiveColor
        } else {
            // Вторая вкладка активна - синяя, первая неактивна - серая
            listButton.setImage(listImage, for: .normal)
            listButton.tintColor = inactiveColor
            
            calendarButton.setImage(calendarImage, for: .normal)
            calendarButton.tintColor = activeColor
        }
    }
    


    private func updateIndicatorPosition(animated: Bool) {
        let targetX = calculateIndicatorXPosition()

        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                self.indicatorLeadingConstraint.constant = targetX
                self.view.layoutIfNeeded()
            })
        } else {
            indicatorLeadingConstraint.constant = targetX
            view.layoutIfNeeded()
        }
    }
    
    private func showModeSwitchAnimation(completion: @escaping () -> Void) {
        // Отменяем предыдущую анимацию, если она есть
        currentAnimationVC?.dismiss(animated: false)
        
        let animationVC = ModeSwitchAnimationViewController()
        animationVC.modalPresentationStyle = .overFullScreen
        animationVC.completion = completion
        currentAnimationVC = animationVC
        present(animationVC, animated: false)
    }
    
    private func switchMode() {
        if isTeacherMode {
            // Переключаемся на режим преподавателя
            firstVC.view.isHidden = true
            secondVC.view.isHidden = true
            teacherFirstVC.view.isHidden = false
            teacherSecondVC.view.isHidden = false
            
            // Очищаем старое расписание студента
            secondVC.fullSchedule = []
            secondVC.schedule = []
            
            // Сбрасываем позиции
            currentItemIndex = 0
            teacherFirstVC.view.frame.origin.x = 0
            teacherSecondVC.view.frame.origin.x = self.view.bounds.width
            
            // Загружаем сохраненные данные преподавателя
            if let selectedTeacherURL = UserDefaults.standard.string(forKey: "selectedTeacherURL") {
                // Теперь здесь хранится ФИО преподавателя
                teacherSecondVC.selectedTeacherURL = selectedTeacherURL
                teacherSecondVC.loadTimetableData()
            }
            
            // При переключении в режим преподавателя обновляем баннер на первом экране
            teacherFirstVC.refreshAdBannerIfNeeded()
        } else {
            // Переключаемся на режим студента
            firstVC.view.isHidden = false
            secondVC.view.isHidden = false
            teacherFirstVC.view.isHidden = true
            teacherSecondVC.view.isHidden = true
            
            // Очищаем старое расписание преподавателя
            teacherSecondVC.fullSchedule = []
            teacherSecondVC.schedule = []
            
            // Сбрасываем позиции
            currentItemIndex = 0
            firstVC.view.frame.origin.x = 0
            secondVC.view.frame.origin.x = self.view.bounds.width
            
            // Загружаем сохраненные данные группы
            if let selectedGroupURL = UserDefaults.standard.string(forKey: "selectedGroupURL") {
                secondVC.selectedGroupURL = selectedGroupURL
                secondVC.loadTimetableData()
            }
            
            // При переключении в режим студента обновляем баннер на первом экране
            firstVC.refreshAdBannerIfNeeded()
        }
        
        updateTabBarButtons()
        updateTabBar()
        updateIndicatorPosition(animated: false)
    }

    func updateTabBarAccess(isGroupSelectionRemoved: Bool) {
        if isGroupSelectionRemoved && !isTeacherMode {
            // Скрываем первый экран выбора группы
            firstVC.view.isHidden = true
            // Скрываем таб бар
            customTabBar.isHidden = true
            tabBarContainer.isHidden = true
            // Показываем только окно расписания
            secondVC.view.isHidden = false
            // Перемещаем окно расписания на позицию 0
            secondVC.view.frame.origin.x = 0
            // Update the current tab index
            currentItemIndex = 1
            updateTabBarButtons()
        } else {
            // Показываем первый экран выбора группы
            if !isTeacherMode {
                firstVC.view.isHidden = false
            }
            // Показываем таб бар
            customTabBar.isHidden = false
            tabBarContainer.isHidden = false
            // Update the current tab index
            currentItemIndex = 0
            updateTabBarButtons()
            updateTabBar()
            updateIndicatorPosition(animated: false)
        }
    }
}
