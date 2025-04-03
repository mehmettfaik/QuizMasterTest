import UIKit
import FirebaseAuth
import FirebaseFirestore

class OnlineUsersViewController: UIViewController {
    private let tableView: UITableView = {
        let table = UITableView()
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return table
    }()
    
    private var onlineUsers: [User] = []
    private let multiplayerService = MultiplayerGameService.shared
    private var onlineUsersListener: ListenerRegistration?
    private var invitationListener: ListenerRegistration?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupListeners()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let currentUserId = Auth.auth().currentUser?.uid {
            multiplayerService.updateOnlineStatus(userId: currentUserId, isOnline: true)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onlineUsersListener?.remove()
        invitationListener?.remove()
        if let currentUserId = Auth.auth().currentUser?.uid {
            multiplayerService.updateOnlineStatus(userId: currentUserId, isOnline: false)
        }
    }
    
    private func setupUI() {
        title = "Online Users"
        view.backgroundColor = .systemBackground
        
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupListeners() {
        setupOnlineUsersListener()
        setupInvitationListener()
    }
    
    private func setupOnlineUsersListener() {
        onlineUsersListener = multiplayerService.getOnlineUsers { [weak self] users in
            DispatchQueue.main.async {
                self?.onlineUsers = users.filter { $0.id != Auth.auth().currentUser?.uid }
                self?.tableView.reloadData()
            }
        }
    }
    
    private func setupInvitationListener() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        invitationListener = multiplayerService.listenForGameInvitations { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let game):
                    self?.handleGameInvitation(game)
                case .failure(let error):
                    print("Error listening for game invitations: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleGameInvitation(_ game: MultiplayerGame) {
        // Prevent showing duplicate invitations
        guard presentedViewController == nil else { return }
        
        let alert = UIAlertController(
            title: "Game Invitation",
            message: "\(game.creatorName) has invited you to play a quiz game!",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Accept", style: .default) { [weak self] _ in
            self?.acceptGameInvitation(game)
        })
        
        alert.addAction(UIAlertAction(title: "Decline", style: .destructive) { [weak self] _ in
            self?.declineGameInvitation(game)
        })
        
        present(alert, animated: true)
    }
    
    private func acceptGameInvitation(_ game: MultiplayerGame) {
        multiplayerService.respondToGameInvitation(gameId: game.id, accept: true) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let game):
                    let waitingVC = GameWaitingViewController(game: game)
                    self?.navigationController?.pushViewController(waitingVC, animated: true)
                case .failure(let error):
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func declineGameInvitation(_ game: MultiplayerGame) {
        multiplayerService.respondToGameInvitation(gameId: game.id, accept: false) { result in
            if case .failure(let error) = result {
                print("Error declining game invitation: \(error.localizedDescription)")
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension OnlineUsersViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return onlineUsers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let user = onlineUsers[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = user.name
        content.secondaryText = "Online"
        cell.contentConfiguration = content
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let user = onlineUsers[indexPath.row]
        let alert = UIAlertController(title: "Challenge User",
                                    message: "Do you want to challenge \(user.name) to a quiz?",
                                    preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Yes", style: .default) { [weak self] _ in
            self?.sendGameInvitation(to: user)
        })
        
        alert.addAction(UIAlertAction(title: "No", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func sendGameInvitation(to user: User) {
        multiplayerService.sendGameInvitation(to: user.id) { [weak self] result in
            switch result {
            case .success(let game):
                DispatchQueue.main.async {
                    let gameSetupVC = GameSetupViewController(game: game)
                    self?.navigationController?.pushViewController(gameSetupVC, animated: true)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
} 