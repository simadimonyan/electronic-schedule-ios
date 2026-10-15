//
//  SplashViewController.swift
//  test111
//
//  Created by GPT Assistant on 12.08.2025.
//

import UIKit

/// Сплэш (Splash.dc.html): логотип в кольце с сиянием, название, полоска загрузки
final class SplashViewController: UIViewController {
    private let animationName: String
    var onCompletion: (() -> Void)?

    private let ring = UIView()
    private let glow = CAGradientLayer()
    private let emblem = UIView()
    private let gleam = CAGradientLayer()
    private let lineFill = UIView()
    private let brandStack = UIStackView()
    private let footer = UILabel()
    private var finished = false

    private static let blue = UIColor(rgb: 0x238CFF)

    /// `animationName` сохранён для совместимости с SceneDelegate (раньше — имя Lottie-файла)
    init(animationName: String = "splash", onCompletion: (() -> Void)? = nil) {
        self.animationName = animationName
        self.onCompletion = onCompletion
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        // Тот же цвет, что у LaunchScreen (LaunchBackground), чтобы не было вспышки
        view.backgroundColor = UIColor(named: "LaunchBackground") ?? DS.Color.bg
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playAnimation()
    }

    private func buildUI() {
        // Эмблема в кольце
        let mark = UIView()
        mark.fixSize(width: 144, height: 144)

        glow.type = .radial
        let glowColor = UIColor.ds(UIColor(rgb: 0x238CFF, alpha: 0.22), UIColor(rgb: 0x238CFF, alpha: 0.28)).resolvedColor(with: traitCollection)
        glow.colors = [glowColor.cgColor, glowColor.withAlphaComponent(0).cgColor]
        glow.locations = [0, 0.68]
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        glow.frame = CGRect(x: -48, y: -48, width: 240, height: 240)
        mark.layer.addSublayer(glow)

        ring.translatesAutoresizingMaskIntoConstraints = false
        ring.layer.borderColor = Self.blue.cgColor
        ring.layer.borderWidth = 1
        ring.layer.cornerRadius = 72
        mark.addSubview(ring)
        ring.pinEdges(to: mark)

        emblem.translatesAutoresizingMaskIntoConstraints = false
        emblem.layer.cornerRadius = 18
        emblem.clipsToBounds = true
        let logo = UIImageView(image: DS.Image.logo)
        emblem.addSubview(logo)
        logo.pinEdges(to: emblem)
        gleam.colors = [UIColor(white: 1, alpha: 0).cgColor, UIColor(white: 1, alpha: 0.65).cgColor, UIColor(white: 1, alpha: 0).cgColor]
        gleam.locations = [0.35, 0.49, 0.63]
        gleam.startPoint = CGPoint(x: 0, y: 0.3)
        gleam.endPoint = CGPoint(x: 1, y: 0.7)
        gleam.frame = CGRect(x: -132, y: -44, width: 132, height: 176)
        emblem.layer.addSublayer(gleam)
        let emblemShadow = UIView()
        emblemShadow.translatesAutoresizingMaskIntoConstraints = false
        emblemShadow.layer.shadowColor = Self.blue.cgColor
        emblemShadow.layer.shadowOpacity = 0.65
        emblemShadow.layer.shadowRadius = 10
        emblemShadow.layer.shadowOffset = CGSize(width: 0, height: 16)
        emblemShadow.addSubview(emblem)
        emblem.pinEdges(to: emblemShadow)
        mark.addSubview(emblemShadow)
        NSLayoutConstraint.activate([
            emblemShadow.centerXAnchor.constraint(equalTo: mark.centerXAnchor),
            emblemShadow.centerYAnchor.constraint(equalTo: mark.centerYAnchor),
            emblemShadow.widthAnchor.constraint(equalToConstant: 88),
            emblemShadow.heightAnchor.constraint(equalToConstant: 88)
        ])

        let name = UILabel.ds("Моя Академия", font: DS.Font.display(28, .bold), kern: -0.98, alignment: .center)
        let caption = UILabel.ds("ИМСИТ", font: DS.Font.text(11, .semibold), color: DS.Color.soft, kern: 2.86, alignment: .center)

        let line = UIView()
        line.backgroundColor = Self.blue.withAlphaComponent(0.15)
        line.layer.cornerRadius = 1
        line.clipsToBounds = true
        line.fixSize(width: 40, height: 2)
        lineFill.backgroundColor = Self.blue
        lineFill.frame = CGRect(x: 0, y: 0, width: 0, height: 2)
        line.addSubview(lineFill)

        brandStack.axis = .vertical
        brandStack.alignment = .center
        brandStack.translatesAutoresizingMaskIntoConstraints = false
        [mark, name, caption, line].forEach { brandStack.addArrangedSubview($0) }
        brandStack.setCustomSpacing(16, after: mark)
        brandStack.setCustomSpacing(10, after: name)
        brandStack.setCustomSpacing(32, after: caption)
        view.addSubview(brandStack)

        footer.translatesAutoresizingMaskIntoConstraints = false
        footer.setDS("Ваше расписание всегда под рукой", font: DS.Font.text(12), color: DS.Color.soft, alignment: .center)
        view.addSubview(footer)

        NSLayoutConstraint.activate([
            brandStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            brandStack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -16),
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            footer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -44)
        ])

        // Стартовое состояние для анимации появления
        brandStack.alpha = 0
        brandStack.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        footer.alpha = 0
    }

    private func playAnimation() {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0, options: [], animations: {
            self.brandStack.alpha = 1
            self.brandStack.transform = .identity
            self.footer.alpha = 1
        })

        // Блик по эмблеме
        let move = CABasicAnimation(keyPath: "position.x")
        move.fromValue = -66
        move.toValue = 88 + 66
        move.duration = 0.9
        move.beginTime = CACurrentMediaTime() + 0.35
        move.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        move.fillMode = .both
        gleam.add(move, forKey: "gleam")

        // Мягкая пульсация сияния
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.6
        pulse.toValue = 1
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = 2
        glow.add(pulse, forKey: "pulse")

        // Полоска загрузки
        UIView.animate(withDuration: 1.2, delay: 0.2, options: [.curveEaseInOut], animations: {
            self.lineFill.frame.size.width = 40
        }, completion: { [weak self] _ in
            self?.finish()
        })
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onCompletion?()
    }
}
