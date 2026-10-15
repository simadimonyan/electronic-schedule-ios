//
//  ModeSwitchAnimationViewController.swift
//  schedule
//
//  Created by Дмитрий Цепилов on 30.11.2024.
//

import UIKit

class ModeSwitchAnimationViewController: UIViewController {
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.alpha = 0
        return imageView
    }()
    
    private let titleLabel = UILabel()

    private func setupImage() {
        // Логотип и подпись нового режима
        imageView.image = DS.Image.logo
        imageView.layer.cornerRadius = 24
        imageView.clipsToBounds = true
        let isTeacher = UserDefaults.standard.bool(forKey: "isTeacherMode")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 0
        titleLabel.alpha = 0
        let text = NSMutableAttributedString(attributedString: .ds("РЕЖИМ\n", font: DS.Font.text(11, .bold), color: DS.Color.accent, kern: 1, lineHeight: 18, alignment: .center))
        text.append(.ds(isTeacher ? "Преподаватель" : "Студент", font: DS.Font.display(28, .heavy), color: DS.Color.fg, kern: -0.7, lineHeight: 32, alignment: .center))
        titleLabel.attributedText = text
    }

    private let backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = DS.Color.bg
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0
        return view
    }()
    
    var completion: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupImage()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAnimation()
    }
    
    private func setupUI() {
        view.backgroundColor = .clear
        
        view.addSubview(backgroundView)
        view.addSubview(imageView)
        view.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            imageView.widthAnchor.constraint(equalToConstant: 96),
            imageView.heightAnchor.constraint(equalToConstant: 96),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func startAnimation() {
        // Анимация появления фона
        UIView.animate(withDuration: 0.4, animations: {
            self.backgroundView.alpha = 1
        }) { _ in
            // Анимация появления картинки
            UIView.animate(withDuration: 0.6, animations: {
                self.imageView.alpha = 1
                self.titleLabel.alpha = 1
                self.imageView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }) { _ in
                // Длительная задержка для показа логотипа
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // Анимация исчезновения картинки
                    UIView.animate(withDuration: 0.4, animations: {
                        self.imageView.alpha = 0
                        self.titleLabel.alpha = 0
                        self.imageView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                    }) { _ in
                        // Анимация исчезновения фона
                        UIView.animate(withDuration: 0.4, animations: {
                            self.backgroundView.alpha = 0
                        }) { _ in
                            // Вызываем completion и закрываем контроллер
                            self.completion?()
                            self.dismiss(animated: false)
                        }
                    }
                }
            }
        }
    }
} 