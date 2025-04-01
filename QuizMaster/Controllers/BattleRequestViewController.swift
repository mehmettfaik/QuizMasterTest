import UIKit
import Combine
import FirebaseFirestore

class BattleRequestViewController: UIViewController {
    private var battle: QuizBattle
    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Yarışma İsteği"
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .primaryPurple
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textColor = .darkGray
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .systemPurple.withAlphaComponent(0.1)
        imageView.layer.cornerRadius = 40
        imageView.layer.masksToBounds = true
        imageView.image = UIImage(systemName: "person.fill")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let acceptButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Kabul Et", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemGreen
        button.layer.cornerRadius = 20
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let rejectButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Reddet", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemRed
        button.layer.cornerRadius = 20
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .primaryPurple
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    init(battle: QuizBattle) {
        self.battle = battle
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateUI()
        setupButtonActions()
        setupBattleStatusListener()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        listener?.remove()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(avatarImageView)
        containerView.addSubview(messageLabel)
        containerView.addSubview(acceptButton)
        containerView.addSubview(rejectButton)
        containerView.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            avatarImageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            avatarImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 80),
            avatarImageView.heightAnchor.constraint(equalToConstant: 80),
            
            messageLabel.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: 16),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            rejectButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 24),
            rejectButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            rejectButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
            rejectButton.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.4),
            rejectButton.heightAnchor.constraint(equalToConstant: 40),
            
            acceptButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 24),
            acceptButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            acceptButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
            acceptButton.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.4),
            acceptButton.heightAnchor.constraint(equalToConstant: 40),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }
    
    private func updateUI() {
        messageLabel.text = "\(battle.challengerName) sizinle yarışmak istiyor. Kabul ediyor musunuz?"
    }
    
    private func setupButtonActions() {
        acceptButton.addTarget(self, action: #selector(acceptButtonTapped), for: .touchUpInside)
        rejectButton.addTarget(self, action: #selector(rejectButtonTapped), for: .touchUpInside)
    }
    
    private func setupBattleStatusListener() {
        listener = FirebaseService.shared.listenForBattleStatus(battleId: battle.id) { [weak self] result in
            switch result {
            case .success(let updatedBattle):
                self?.battle = updatedBattle
                
                // Eğer meydan okuma reddedilmişse veya bir problemi varsa, view controller'ı kapat
                if updatedBattle.status == .rejected {
                    self?.dismiss(animated: true)
                }
                
            case .failure:
                self?.dismiss(animated: true)
            }
        }
    }
    
    @objc private func acceptButtonTapped() {
        loadingIndicator.startAnimating()
        acceptButton.isEnabled = false
        rejectButton.isEnabled = false
        
        FirebaseService.shared.respondToBattleRequest(battleId: battle.id, status: .accepted) { [weak self] result in
            self?.loadingIndicator.stopAnimating()
            
            switch result {
            case .success:
                self?.dismiss(animated: true) {
                    // Kategori seçimi sayfasına yönlendir
                    self?.navigateToBattleSetup()
                }
                
            case .failure(let error):
                self?.acceptButton.isEnabled = true
                self?.rejectButton.isEnabled = true
                
                let alert = UIAlertController(
                    title: "Hata",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Tamam", style: .default))
                self?.present(alert, animated: true)
            }
        }
    }
    
    @objc private func rejectButtonTapped() {
        loadingIndicator.startAnimating()
        acceptButton.isEnabled = false
        rejectButton.isEnabled = false
        
        FirebaseService.shared.respondToBattleRequest(battleId: battle.id, status: .rejected) { [weak self] result in
            self?.loadingIndicator.stopAnimating()
            
            switch result {
            case .success:
                self?.dismiss(animated: true)
                
            case .failure(let error):
                self?.acceptButton.isEnabled = true
                self?.rejectButton.isEnabled = true
                
                let alert = UIAlertController(
                    title: "Hata",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Tamam", style: .default))
                self?.present(alert, animated: true)
            }
        }
    }
    
    private func navigateToBattleSetup() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let battleCategoryVC = BattleCategoryViewController(battle: battle)
        let navController = UINavigationController(rootViewController: battleCategoryVC)
        navController.modalPresentationStyle = .fullScreen
        
        rootViewController.present(navController, animated: true)
    }
} 