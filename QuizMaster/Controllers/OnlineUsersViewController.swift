import UIKit
import FirebaseAuth

class OnlineUsersViewController: UIViewController {
    private let tableView: UITableView = {
        let table = UITableView()
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return table
    }()
    
    private var onlineUsers: [User] = []
    private let multiplayerService = MultiplayerGameService.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchOnlineUsers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let currentUserId = Auth.auth().currentUser?.uid {
            multiplayerService.updateOnlineStatus(userId: currentUserId, isOnline: true)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
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
    
    private func fetchOnlineUsers() {
        multiplayerService.getOnlineUsers { [weak self] users in
            guard let self = self else { return }
            
            // Filter out current user
            self.onlineUsers = users.filter { $0.id != Auth.auth().currentUser?.uid }
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
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
} 