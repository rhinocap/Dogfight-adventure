//
//  HomeViewController.swift
//  Dogfight Adventures
//
//  Title / home screen: sky background, drifting clouds, a banking jet, the game
//  title, and a big PLAY button that flies you into the game.
//

import UIKit

final class HomeViewController: UIViewController {

    private let sky = CAGradientLayer()
    private let sun = CAGradientLayer()
    private let cloud1 = CAShapeLayer()
    private let cloud2 = CAShapeLayer()
    private let jet = CAShapeLayer()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tagline = UILabel()
    private let playButton = UIButton(type: .custom)

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setup()
    }

    private func setup() {
        // Sky gradient.
        sky.colors = [
            UIColor(red: 0.30, green: 0.55, blue: 0.86, alpha: 1).cgColor,
            UIColor(red: 0.62, green: 0.80, blue: 0.95, alpha: 1).cgColor,
        ]
        sky.startPoint = CGPoint(x: 0.5, y: 0); sky.endPoint = CGPoint(x: 0.5, y: 1)
        view.layer.addSublayer(sky)

        // Soft sun glow.
        sun.type = .radial
        sun.colors = [UIColor(white: 1, alpha: 0.9).cgColor, UIColor(white: 1, alpha: 0).cgColor]
        sun.startPoint = CGPoint(x: 0.5, y: 0.5); sun.endPoint = CGPoint(x: 1, y: 1)
        view.layer.addSublayer(sun)

        // Clouds.
        for c in [cloud1, cloud2] { c.fillColor = UIColor(white: 1, alpha: 0.5).cgColor; view.layer.addSublayer(c) }

        // Jet (white, banking).
        jet.fillColor = UIColor.white.cgColor
        jet.shadowColor = UIColor.black.cgColor
        jet.shadowOpacity = 0.25; jet.shadowRadius = 10; jet.shadowOffset = CGSize(width: 0, height: 8)
        view.layer.addSublayer(jet)

        // Title.
        titleLabel.text = "DOGFIGHT"
        titleLabel.font = .systemFont(ofSize: 72, weight: .heavy)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOpacity = 0.3; titleLabel.layer.shadowRadius = 8
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.addSubview(titleLabel)

        subtitleLabel.attributedText = NSAttributedString(string: "A D V E N T U R E S", attributes: [
            .font: UIFont.systemFont(ofSize: 26, weight: .semibold),
            .foregroundColor: UIColor.white, .kern: 6,
        ])
        subtitleLabel.textAlignment = .center
        view.addSubview(subtitleLabel)

        tagline.text = "Fly through the Golden Gate · San Francisco Bay"
        tagline.font = .systemFont(ofSize: 16, weight: .medium)
        tagline.textColor = UIColor(white: 1, alpha: 0.9)
        tagline.textAlignment = .center
        view.addSubview(tagline)

        // PLAY button.
        playButton.setTitle("START", for: .normal)
        playButton.titleLabel?.font = .systemFont(ofSize: 30, weight: .heavy)
        playButton.setTitleColor(.white, for: .normal)
        playButton.backgroundColor = UIColor(red: 1.0, green: 0.45, blue: 0.2, alpha: 1)
        playButton.layer.cornerRadius = 36
        playButton.layer.shadowColor = UIColor.black.cgColor
        playButton.layer.shadowOpacity = 0.3; playButton.layer.shadowRadius = 12
        playButton.layer.shadowOffset = CGSize(width: 0, height: 8)
        playButton.addTarget(self, action: #selector(play), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(pressDown), for: .touchDown)
        playButton.addTarget(self, action: #selector(pressUp), for: [.touchUpOutside, .touchCancel])
        view.addSubview(playButton)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let b = view.bounds
        sky.frame = b
        sun.frame = CGRect(x: b.width * 0.1, y: -b.height * 0.4, width: b.width * 0.8, height: b.height * 0.9)
        cloud1.path = cloudPath(width: 220, height: 60); cloud1.frame = CGRect(x: b.width * 0.12, y: b.height * 0.22, width: 220, height: 60)
        cloud2.path = cloudPath(width: 300, height: 80); cloud2.frame = CGRect(x: b.width * 0.6, y: b.height * 0.14, width: 300, height: 80)

        let jetSize: CGFloat = 200
        jet.frame = CGRect(x: b.midX - jetSize / 2, y: b.height * 0.20, width: jetSize, height: jetSize)
        jet.path = jetPath(in: CGRect(x: 0, y: 0, width: jetSize, height: jetSize))
        jet.setAffineTransform(CGAffineTransform(rotationAngle: -0.35))

        titleLabel.frame = CGRect(x: 0, y: b.height * 0.44, width: b.width, height: 80)
        subtitleLabel.frame = CGRect(x: 0, y: b.height * 0.44 + 76, width: b.width, height: 34)
        tagline.frame = CGRect(x: 0, y: b.height * 0.44 + 116, width: b.width, height: 22)

        let pw: CGFloat = 240, ph: CGFloat = 72
        playButton.frame = CGRect(x: b.midX - pw / 2, y: b.height * 0.80, width: pw, height: ph)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Gentle jet bob.
        let bob = CABasicAnimation(keyPath: "position.y")
        bob.byValue = -16; bob.duration = 2.2; bob.autoreverses = true
        bob.repeatCount = .infinity; bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        jet.add(bob, forKey: "bob")
        // PLAY pulse.
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0; pulse.toValue = 1.06; pulse.duration = 0.9
        pulse.autoreverses = true; pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        playButton.layer.add(pulse, forKey: "pulse")
        // Drift clouds.
        drift(cloud1, distance: 60, duration: 9)
        drift(cloud2, distance: 90, duration: 13)
    }

    private func drift(_ layer: CALayer, distance: CGFloat, duration: CFTimeInterval) {
        let a = CABasicAnimation(keyPath: "position.x")
        a.byValue = distance; a.duration = duration; a.autoreverses = true
        a.repeatCount = .infinity; a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(a, forKey: "drift")
    }

    // MARK: Actions

    @objc private func pressDown() {
        UIView.animate(withDuration: 0.1) { self.playButton.transform = CGAffineTransform(scaleX: 0.94, y: 0.94) }
    }
    @objc private func pressUp() {
        UIView.animate(withDuration: 0.1) { self.playButton.transform = .identity }
    }
    @objc private func play() {
        pressUp()
        let game = GameViewController()
        game.modalPresentationStyle = .fullScreen
        game.modalTransitionStyle = .crossDissolve
        present(game, animated: true)
    }

    // MARK: Shapes

    private func cloudPath(width: CGFloat, height: CGFloat) -> CGPath {
        let p = UIBezierPath()
        p.addArc(withCenter: CGPoint(x: width * 0.3, y: height * 0.6), radius: height * 0.4, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        p.addArc(withCenter: CGPoint(x: width * 0.55, y: height * 0.45), radius: height * 0.5, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        p.addArc(withCenter: CGPoint(x: width * 0.75, y: height * 0.6), radius: height * 0.38, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        p.append(UIBezierPath(roundedRect: CGRect(x: width * 0.2, y: height * 0.6, width: width * 0.6, height: height * 0.35), cornerRadius: height * 0.18))
        return p.cgPath
    }

    private func jetPath(in r: CGRect) -> CGPath {
        // Top-down fighter, nose up, normalized then fit into r.
        let half: [CGPoint] = [
            CGPoint(x: 0.00, y: 0.97), CGPoint(x: 0.045, y: 0.62), CGPoint(x: 0.075, y: 0.40),
            CGPoint(x: 0.55, y: 0.06), CGPoint(x: 0.52, y: -0.04), CGPoint(x: 0.115, y: 0.06),
            CGPoint(x: 0.10, y: -0.18), CGPoint(x: 0.31, y: -0.34), CGPoint(x: 0.27, y: -0.43),
            CGPoint(x: 0.075, y: -0.28), CGPoint(x: 0.065, y: -0.52), CGPoint(x: 0.00, y: -0.55),
        ]
        var pts = half
        pts.append(contentsOf: half.dropFirst().dropLast().reversed().map { CGPoint(x: -$0.x, y: $0.y) })
        let p = UIBezierPath()
        func map(_ q: CGPoint) -> CGPoint {
            CGPoint(x: r.midX + q.x * r.width * 0.9, y: r.midY - q.y * r.height * 0.5)
        }
        for (i, q) in pts.enumerated() { i == 0 ? p.move(to: map(q)) : p.addLine(to: map(q)) }
        p.close()
        return p.cgPath
    }
}
