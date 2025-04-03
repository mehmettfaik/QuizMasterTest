import UIKit
import FirebaseFirestore

class GameWaitingViewController: UIViewController {
    private let multiplayerService = MultiplayerGameService.shared
    private var invitationListener: ListenerRegistration?
    private var gameListener: ListenerRegistration?
    private var game: MultiplayerGame?
    
    init(game: MultiplayerGame? = nil) {
        self.game = game
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Waiting for opponent..."
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textAlignment = .center
        label.textColor = .darkGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .primaryPurple
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        if let game = game {
            statusLabel.text = "Waiting for game to start..."
            listenForGameStart(game)
        } else {
            setupListeners()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        invitationListener?.remove()
        gameListener?.remove()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Game Invitation"
        
        view.addSubview(statusLabel)
        view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20)
        ])
        
        activityIndicator.startAnimating()
    }
    
    private func setupListeners() {
        // Listen for incoming game invitations
        invitationListener = multiplayerService.listenForGameInvitations { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let game):
                    // Only show invitation if we haven't handled it yet
                    if !self.isShowingInvitation {
                        self.handleGameInvitation(game)
                    }
                case .failure(let error):
                    print("Error listening for game invitations: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private var isShowingInvitation = false
    
    private func handleGameInvitation(_ game: MultiplayerGame) {
        isShowingInvitation = true
        
        // Show invitation alert
        let alert = UIAlertController(
            title: "Game Invitation",
            message: "You have been invited to play a quiz game!",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Accept", style: .default) { [weak self] _ in
            self?.isShowingInvitation = false
            self?.acceptInvitation(game)
        })
        
        alert.addAction(UIAlertAction(title: "Decline", style: .destructive) { [weak self] _ in
            self?.isShowingInvitation = false
            self?.declineInvitation(game)
        })
        
        // If alert is already being presented, dismiss it first
        if let presentedVC = presentedViewController {
            presentedVC.dismiss(animated: true) { [weak self] in
                self?.present(alert, animated: true)
            }
        } else {
            present(alert, animated: true)
        }
    }
    
    private func acceptInvitation(_ game: MultiplayerGame) {
        statusLabel.text = "Accepting invitation..."
        
        multiplayerService.respondToGameInvitation(gameId: game.id, accept: true) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedGame):
                    self?.statusLabel.text = "Waiting for game to start..."
                    self?.listenForGameStart(updatedGame)
                case .failure(let error):
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func declineInvitation(_ game: MultiplayerGame) {
        multiplayerService.respondToGameInvitation(gameId: game.id, accept: false) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.navigationController?.popViewController(animated: true)
                case .failure(let error):
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func listenForGameStart(_ game: MultiplayerGame) {
        gameListener = multiplayerService.listenForGameUpdates(gameId: game.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedGame):
                    if updatedGame.status == .inProgress {
                        let gameVC = MultiplayerGameViewController(game: updatedGame)
                        self?.navigationController?.pushViewController(gameVC, animated: true)
                    }
                case .failure(let error):
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
} 