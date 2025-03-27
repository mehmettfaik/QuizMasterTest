import UIKit

class OnlineUsersViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private var tableView: UITableView!
    private var onlineUsers: [User] = []
    private let firebaseService = FirebaseService.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Online Users"
        view.backgroundColor = .white
        configureTableView()
        fetchOnlineUsers()
    }
    
    private func configureTableView() {
        tableView = UITableView(frame: view.bounds)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "UserCell")
        view.addSubview(tableView)
    }
    
    private func fetchOnlineUsers() {
        firebaseService.fetchOnlineUsers { [weak self] users in
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
        let selectedUser = onlineUsers[indexPath.row]
        firebaseService.sendChallenge(to: selectedUser) { [weak self] success in
            DispatchQueue.main.async {
                let msg = success ? "Challenge sent successfully!" : "Failed to send challenge."
                let alert = UIAlertController(title: "Challenge", message: msg, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    if success {
                        // After sending challenge, navigate to Battle view as the challenger
                        let battleVC = BattleViewController(isChallenger: true, opponentId: selectedUser.id)
                        self?.navigationController?.pushViewController(battleVC, animated: true)
                    }
                })
                self?.present(alert, animated: true, completion: nil)
            }
        }
    }
}
