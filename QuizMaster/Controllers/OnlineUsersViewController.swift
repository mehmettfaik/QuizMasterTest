import UIKit
import FirebaseFirestore

class OnlineUsersViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private var tableView: UITableView!
    private var onlineUsers: [User] = []
    private let firebaseService = FirebaseService.shared
    private var challengeListener: ListenerRegistration?
    private var onlineUsersListener: ListenerRegistration?
    
    deinit {
        challengeListener?.remove()
        onlineUsersListener?.remove()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Online Users"
        view.backgroundColor = .white
        configureTableView()
        setupChallengeListener()
        setupOnlineUsersListener()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        firebaseService.updateUserOnlineStatus(isOnline: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        firebaseService.updateUserOnlineStatus(isOnline: false)
    }
    
    private func configureTableView() {
        tableView = UITableView(frame: view.bounds)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "UserCell")
        view.addSubview(tableView)
    }
    
    private func setupChallengeListener() {
        challengeListener = firebaseService.listenForChallenges { [weak self] battleId, challengerId in
            self?.handleIncomingChallenge(battleId: battleId, challengerId: challengerId)
        }
    }
    
    private func handleIncomingChallenge(battleId: String, challengerId: String) {
        // Find challenger's name
        let challenger = onlineUsers.first { $0.id == challengerId }
        let challengerName = challenger?.name ?? "Someone"
        
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: "Quiz Challenge",
                message: "\(challengerName) wants to challenge you to a quiz battle!",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Accept", style: .default) { [weak self] _ in
                self?.acceptChallenge(battleId: battleId)
            })
            
            alert.addAction(UIAlertAction(title: "Decline", style: .cancel))
            
            self?.present(alert, animated: true)
        }
    }
    
    private func acceptChallenge(battleId: String) {
        firebaseService.acceptChallenge(battleId: battleId) { [weak self] success in
            if success {
                DispatchQueue.main.async {
                    let battleVC = BattleViewController(isChallenger: false, opponentId: battleId)
                    self?.navigationController?.pushViewController(battleVC, animated: true)
                }
            }
        }
    }
    
    private func setupOnlineUsersListener() {
        onlineUsersListener = firebaseService.listenForOnlineUsers { [weak self] users in
            DispatchQueue.main.async {
                self?.onlineUsers = users
                self?.tableView.reloadData()
            }
        }
    }
    
    // UITableViewDataSource methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return onlineUsers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath)
        let user = onlineUsers[indexPath.row]
        cell.textLabel?.text = user.name
        return cell
    }
    
    // UITableViewDelegate method
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedUser = onlineUsers[indexPath.row]
        
        let alert = UIAlertController(
            title: "Challenge User",
            message: "Do you want to challenge \(selectedUser.name) to a quiz battle?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Yes", style: .default) { [weak self] _ in
            self?.sendChallenge(to: selectedUser)
        })
        
        alert.addAction(UIAlertAction(title: "No", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func sendChallenge(to user: User) {
        firebaseService.sendChallenge(to: user) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let battleId):
                    let battleVC = BattleViewController(isChallenger: true, opponentId: battleId)
                    self?.navigationController?.pushViewController(battleVC, animated: true)
                case .failure(let error):
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to send challenge: \(error.localizedDescription)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }
}
