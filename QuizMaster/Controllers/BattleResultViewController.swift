import UIKit
import Combine

class BattleResultViewController: UIViewController {
    private var battle: QuizBattle
    private let isChallenger: Bool
    private let isWinner: Bool
    private var cancellables = Set<AnyCancellable>()
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowOpacity = 0.2
        view.layer.shadowRadius = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let resultIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let scoreLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let playersLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textAlignment = .center
        label.textColor = .darkGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let categoryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textAlignment = .center
        label.textColor = .systemGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let difficultyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textAlignment = .center
        label.textColor = .systemGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let pointsEarnedLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .primaryPurple
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Ana Sayfaya Dön", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .primaryPurple
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.layer.cornerRadius = 20
        button.layer.shadowColor = UIColor.primaryPurple.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    init(battle: QuizBattle, isChallenger: Bool, isWinner: Bool) {
        self.battle = battle
        self.isChallenger = isChallenger
        self.isWinner = isWinner
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateResultUI()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        
        view.addSubview(containerView)
        containerView.addSubview(resultIconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(scoreLabel)
        containerView.addSubview(playersLabel)
        containerView.addSubview(categoryLabel)
        containerView.addSubview(difficultyLabel)
        containerView.addSubview(pointsEarnedLabel)
        containerView.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9),
            containerView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.8),
            
            resultIconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 32),
            resultIconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            resultIconImageView.widthAnchor.constraint(equalToConstant: 100),
            resultIconImageView.heightAnchor.constraint(equalToConstant: 100),
            
            titleLabel.topAnchor.constraint(equalTo: resultIconImageView.bottomAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            scoreLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            scoreLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            scoreLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            scoreLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            playersLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 16),
            playersLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            playersLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            playersLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            categoryLabel.topAnchor.constraint(equalTo: playersLabel.bottomAnchor, constant: 24),
            categoryLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            categoryLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            categoryLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            difficultyLabel.topAnchor.constraint(equalTo: categoryLabel.bottomAnchor, constant: 8),
            difficultyLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            difficultyLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            difficultyLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            pointsEarnedLabel.topAnchor.constraint(equalTo: difficultyLabel.bottomAnchor, constant: 24),
            pointsEarnedLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            pointsEarnedLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            pointsEarnedLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            closeButton.topAnchor.constraint(equalTo: pointsEarnedLabel.bottomAnchor, constant: 32),
            closeButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            closeButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 32),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -32),
            closeButton.heightAnchor.constraint(equalToConstant: 50),
            closeButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32)
        ])
        
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
    }
    
    private func updateResultUI() {
        // UI'yi kazanan veya kaybeden durumuna göre güncelle
        if isWinner {
            resultIconImageView.image = UIImage(systemName: "trophy.fill")
            resultIconImageView.tintColor = .systemYellow
            titleLabel.text = "Tebrikler, Kazandınız!"
            titleLabel.textColor = .systemGreen
        } else {
            resultIconImageView.image = UIImage(systemName: "xmark.circle.fill")
            resultIconImageView.tintColor = .systemRed
            titleLabel.text = "Maalesef Kaybettiniz!"
            titleLabel.textColor = .systemRed
        }
        
        // Score
        let challengerScore = battle.challengerScore ?? 0
        let opponentScore = battle.opponentScore ?? 0
        scoreLabel.text = "\(challengerScore) - \(opponentScore)"
        
        // Players
        playersLabel.text = "\(battle.challengerName) vs \(battle.opponentName)"
        
        // Category and Difficulty
        categoryLabel.text = "Kategori: \(battle.category)"
        difficultyLabel.text = "Zorluk Seviyesi: \(battle.difficulty)"
        
        // Points Earned
        let myScore = isChallenger ? challengerScore : opponentScore
        pointsEarnedLabel.text = "Kazandığınız Puan: \(myScore)"
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
} 