import UIKit
import Combine
import FirebaseAuth

class OnlineUsersViewController: UIViewController {
    private var users: [User] = []
    private var cancellables = Set<AnyCancellable>()
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .white
        tableView.separatorStyle = .none
        tableView.register(OnlineUserCell.self, forCellReuseIdentifier: "OnlineUserCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .primaryPurple
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "Şu anda çevrimiçi kullanıcı bulunmuyor"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .systemGray
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigation()
        setupTableView()
        fetchOnlineUsers()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        fetchOnlineUsers()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        view.addSubview(tableView)
        view.addSubview(loadingIndicator)
        view.addSubview(emptyStateLabel)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func setupNavigation() {
        title = "Çevrimiçi Kullanıcılar"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        
        let refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refreshButtonTapped))
        navigationItem.rightBarButtonItem = refreshButton
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    private func fetchOnlineUsers() {
        loadingIndicator.startAnimating()
        tableView.isHidden = true
        emptyStateLabel.isHidden = true
        
        FirebaseService.shared.getOnlineUsers { [weak self] result in
            self?.loadingIndicator.stopAnimating()
            self?.tableView.isHidden = false
            
            switch result {
            case .success(let users):
                self?.users = users
                self?.tableView.reloadData()
                
                if users.isEmpty {
                    self?.emptyStateLabel.isHidden = false
                    self?.tableView.isHidden = true
                } else {
                    self?.emptyStateLabel.isHidden = true
                    self?.tableView.isHidden = false
                }
                
            case .failure(let error):
                self?.showErrorAlert(error)
                self?.emptyStateLabel.isHidden = false
                self?.tableView.isHidden = true
            }
        }
    }
    
    @objc private func refreshButtonTapped() {
        fetchOnlineUsers()
    }
    
    private func sendBattleRequest(to user: User) {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        let alertController = UIAlertController(
            title: "Yarışma İsteği",
            message: "\(user.name) kullanıcısına yarışma isteği göndermek istiyor musunuz?",
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "İptal", style: .cancel))
        alertController.addAction(UIAlertAction(title: "Gönder", style: .default) { [weak self] _ in
            self?.loadingIndicator.startAnimating()
            
            FirebaseService.shared.sendBattleRequest(
                challengerId: currentUser.uid,
                challengerName: UserDefaults.standard.string(forKey: "userName") ?? "Kullanıcı",
                opponentId: user.id,
                opponentName: user.name
            ) { [weak self] result in
                self?.loadingIndicator.stopAnimating()
                
                switch result {
                case .success:
                    let alert = UIAlertController(
                        title: "Başarılı",
                        message: "Yarışma isteği başarıyla gönderildi. Kullanıcının cevabı bekleyiniz.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "Tamam", style: .default))
                    self?.present(alert, animated: true)
                    
                case .failure(let error):
                    self?.showErrorAlert(error)
                }
            }
        })
        
        present(alertController, animated: true)
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension OnlineUsersViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "OnlineUserCell", for: indexPath) as? OnlineUserCell else {
            return UITableViewCell()
        }
        
        let user = users[indexPath.row]
        cell.configure(with: user)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let user = users[indexPath.row]
        sendBattleRequest(to: user)
    }
}

// MARK: - OnlineUserCell
class OnlineUserCell: UITableViewCell {
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 25
        imageView.layer.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let pointsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .systemGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let onlineIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGreen
        view.layer.cornerRadius = 5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.addSubview(avatarImageView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(pointsLabel)
        containerView.addSubview(onlineIndicator)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            avatarImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            avatarImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 50),
            avatarImageView.heightAnchor.constraint(equalToConstant: 50),
            
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: onlineIndicator.leadingAnchor, constant: -8),
            
            pointsLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            pointsLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            pointsLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            pointsLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -12),
            
            onlineIndicator.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            onlineIndicator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            onlineIndicator.widthAnchor.constraint(equalToConstant: 10),
            onlineIndicator.heightAnchor.constraint(equalToConstant: 10)
        ])
    }
    
    func configure(with user: User) {
        nameLabel.text = user.name
        pointsLabel.text = "\(user.totalPoints) Puan"
        
        if let avatarType = Avatar(rawValue: user.avatar) {
            avatarImageView.image = avatarType.image
            avatarImageView.backgroundColor = avatarType.backgroundColor
        } else {
            avatarImageView.image = UIImage(systemName: "person.fill")
            avatarImageView.backgroundColor = .systemGray4
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.image = nil
        nameLabel.text = nil
        pointsLabel.text = nil
    }
} 