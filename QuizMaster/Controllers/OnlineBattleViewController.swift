import UIKit
import FirebaseFirestore
import Combine
import FirebaseAuth

// CANLI YARISMA SORULAR EKRANI 
class OnlineBattleViewController: UIViewController {
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var currentUserId: String?
    private var currentBattleId: String?
    private var timer: Timer?
    private var remainingTime: Int = 30
    private var onlineUsers: [User] = []
    private var selectedUserId: String?
    private var battleListeners: [ListenerRegistration] = []
    private var battleInvitations: [QueryDocumentSnapshot] = []
    
    // MARK: - UI Components
    private let containerStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .primaryPurple
        label.textAlignment = .center
        label.text = "Çevrimiçi Kullanıcılar"
        return label
    }()
    
    private let onlineUsersCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 16
        layout.minimumInteritemSpacing = 16
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    private let createBattleButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Yarışma İsteği Gönder", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .primaryPurple
        button.layer.cornerRadius = 20
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isEnabled = false
        button.alpha = 0.5
        return button
    }()
    
    private let timerLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 36, weight: .bold)
        label.textColor = .primaryPurple
        label.isHidden = true
        return label
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .primaryPurple
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private let noUsersLabel: UILabel = {
        let label = UILabel()
        label.text = "Şu anda çevrimiçi kullanıcı bulunmamaktadır."
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
        setupActions()
        getCurrentUser()
        observeOnlineUsers()
        observeBattleInvitations()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        if let battleId = currentBattleId {
            leaveBattle(battleId: battleId)
        }
        updateUserOnlineStatus(isOnline: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUserOnlineStatus(isOnline: true)
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Canlı Yarışma"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Kapat",
            style: .done,
            target: self,
            action: #selector(closeTapped)
        )
        
        view.addSubview(containerStackView)
        containerStackView.addArrangedSubview(statusLabel)
        containerStackView.addArrangedSubview(onlineUsersCollectionView)
        containerStackView.addArrangedSubview(createBattleButton)
        containerStackView.addArrangedSubview(timerLabel)
        containerStackView.addArrangedSubview(loadingIndicator)
        containerStackView.addArrangedSubview(noUsersLabel)
        
        NSLayoutConstraint.activate([
            containerStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            containerStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            containerStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            containerStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            onlineUsersCollectionView.heightAnchor.constraint(equalToConstant: 400),
            onlineUsersCollectionView.widthAnchor.constraint(equalTo: containerStackView.widthAnchor),
            
            createBattleButton.heightAnchor.constraint(equalToConstant: 50),
            createBattleButton.widthAnchor.constraint(equalTo: containerStackView.widthAnchor, constant: -40)
        ])
    }
    
    private func setupCollectionView() {
        onlineUsersCollectionView.delegate = self
        onlineUsersCollectionView.dataSource = self
        onlineUsersCollectionView.register(OnlineUserCell.self, forCellWithReuseIdentifier: "OnlineUserCell")
    }
    
    private func setupActions() {
        createBattleButton.addTarget(self, action: #selector(createBattleTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func createBattleTapped() {
        guard let selectedUserId = selectedUserId, let userId = currentUserId else {
            showErrorAlert(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı seçilmedi"]))
            return
        }
        
        loadingIndicator.startAnimating()
        createBattleButton.isEnabled = false
        
        // Show category selection
        showCategorySelection { [weak self] category, difficulty in
            guard let self = self else { return }
            
            // Create a new battle
            FirebaseService.shared.createBattle(createdBy: userId, category: category, difficulty: difficulty) { [weak self] result in
                self?.loadingIndicator.stopAnimating()
                
                switch result {
                case .success(let battleId):
                    // Send invitation to the selected user
                    FirebaseService.shared.sendBattleInvitation(fromUserId: userId, toUserId: selectedUserId, battleId: battleId) { [weak self] result in
                        switch result {
                        case .success(_):
                            // Show waiting message
                            let alert = UIAlertController(
                                title: "Davet Gönderildi",
                                message: "Kullanıcının daveti kabul etmesi bekleniyor...",
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "Tamam", style: .default))
                            self?.present(alert, animated: true)
                            
                            // Start observing the battle
                            self?.observeBattle(battleId: battleId)
                            
                        case .failure(let error):
                            self?.showErrorAlert(error)
                            self?.createBattleButton.isEnabled = true
                        }
                    }
                    
                case .failure(let error):
                    self?.showErrorAlert(error)
                    self?.createBattleButton.isEnabled = true
                }
            }
        }
    }
    
    private func showCategorySelection(completion: @escaping (String, String) -> Void) {
        let alertController = UIAlertController(title: "Kategori Seçimi", message: "Yarışma için kategori seçin", preferredStyle: .actionSheet)
        
        // Add categories
        for category in QuizCategory.allCases {
            let action = UIAlertAction(title: category.rawValue, style: .default) { [weak self] _ in
                self?.showDifficultySelection(category: category.rawValue, completion: completion)
            }
            alertController.addAction(action)
        }
        
        alertController.addAction(UIAlertAction(title: "İptal", style: .cancel))
        present(alertController, animated: true)
    }
    
    private func showDifficultySelection(category: String, completion: @escaping (String, String) -> Void) {
        let alertController = UIAlertController(title: "Zorluk Seçimi", message: "Yarışma için zorluk seviyesi seçin", preferredStyle: .actionSheet)
        
        // Add difficulties
        for difficulty in QuizDifficulty.allCases {
            let action = UIAlertAction(title: difficulty.rawValue, style: .default) { _ in
                completion(category, difficulty.rawValue)
            }
            alertController.addAction(action)
        }
        
        alertController.addAction(UIAlertAction(title: "İptal", style: .cancel))
        present(alertController, animated: true)
    }
    
    private func observeBattle(battleId: String) {
        currentBattleId = battleId
        
        let listener = FirebaseService.shared.observeBattle(battleId: battleId) { [weak self] result in
            switch result {
            case .success(let battleData):
                if let status = battleData["status"] as? String, status == "active" {
                    self?.navigateToQuizBattle(battleId: battleId)
                }
                
            case .failure(let error):
                self?.showErrorAlert(error)
            }
        }
        
        battleListeners.append(listener)
    }
    
    // MARK: - Firebase Operations
    private func getCurrentUser() {
        guard let userId = Auth.auth().currentUser?.uid else {
            showErrorAlert(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı bilgisi bulunamadı"]))
            return
        }
        currentUserId = userId
        
        // Önce kullanıcı dokümanını kontrol et
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            if let error = error {
                self?.showErrorAlert(error)
                return
            }
            
            if snapshot?.exists == true {
                // Doküman varsa online durumunu güncelle
                self?.updateUserOnlineStatus(isOnline: true)
            } else {
                // Doküman yoksa yeni oluştur
                let userData: [String: Any] = [
                    "id": userId,
                    "isOnline": true,
                    "lastSeen": Timestamp(date: Date()),
                    "name": UserDefaults.standard.string(forKey: "userName") ?? "Anonim",
                    "avatar": UserDefaults.standard.string(forKey: "userAvatar") ?? "wizard",
                    "email": Auth.auth().currentUser?.email ?? "",
                    "total_points": 0,
                    "quizzes_played": 0,
                    "quizzes_won": 0,
                    "language": "tr",
                    "category_stats": [:] as [String: Any]
                ]
                
                self?.db.collection("users").document(userId).setData(userData) { error in
                    if let error = error {
                        self?.showErrorAlert(error)
                    }
                }
            }
        }
    }
    
    private func updateUserOnlineStatus(isOnline: Bool) {
        guard let userId = currentUserId else { return }
        
        let data: [String: Any] = [
            "isOnline": isOnline,
            "lastSeen": Timestamp(date: Date())
        ]
        
        db.collection("users").document(userId).updateData(data) { [weak self] error in
            if let error = error {
                // Doküman yoksa, yeni oluştur
                if (error as NSError).domain == "FIRFirestoreErrorDomain" && (error as NSError).code == 5 {
                    let userData: [String: Any] = [
                        "id": userId,
                        "isOnline": isOnline,
                        "lastSeen": Timestamp(date: Date()),
                        "name": UserDefaults.standard.string(forKey: "userName") ?? "Anonim",
                        "avatar": UserDefaults.standard.string(forKey: "userAvatar") ?? "wizard"
                    ]
                    
                    self?.db.collection("users").document(userId).setData(userData) { error in
                        if let error = error {
                            self?.showErrorAlert(error)
                        }
                    }
                } else {
                    self?.showErrorAlert(error)
                }
            }
        }
    }
    
    private func observeOnlineUsers() {
        loadingIndicator.startAnimating()
        
        guard let userId = currentUserId else {
            loadingIndicator.stopAnimating()
            return
        }
        
        // Use the FirebaseService to get online users
        FirebaseService.shared.getOnlineUsers(excludeUserId: userId) { [weak self] result in
            self?.loadingIndicator.stopAnimating()
            
            switch result {
            case .success(let users):
                self?.onlineUsers = users
                
                DispatchQueue.main.async {
                    if users.isEmpty {
                        self?.noUsersLabel.isHidden = false
                        self?.createBattleButton.isEnabled = false
                        self?.createBattleButton.alpha = 0.5
                        self?.statusLabel.text = "Çevrimiçi Kullanıcılar (0)"
                    } else {
                        self?.noUsersLabel.isHidden = true
                        self?.statusLabel.text = "Çevrimiçi Kullanıcılar (\(users.count))"
                        // Don't enable create battle button until a user is selected
                    }
                    
                    self?.onlineUsersCollectionView.reloadData()
                }
                
            case .failure(let error):
                self?.showErrorAlert(error)
            }
        }
    }
    
    private func joinBattle(battleId: String) {
        guard let userId = currentUserId else { return }
        
        db.collection("battles").document(battleId).updateData([
            "players": FieldValue.arrayUnion([userId])
        ]) { [weak self] error in
            if let error = error {
                self?.showErrorAlert(error)
            } else {
                self?.currentBattleId = battleId
                self?.startWaitingForPlayers(battleId: battleId)
            }
        }
    }
    
    private func leaveBattle(battleId: String) {
        guard let userId = currentUserId else { return }
        
        db.collection("battles").document(battleId).updateData([
            "players": FieldValue.arrayRemove([userId])
        ])
    }
    
    private func startWaitingForPlayers(battleId: String) {
        currentBattleId = battleId
        remainingTime = 30
        timerLabel.isHidden = false
        updateTimerLabel()
        
        // Yarışmayı dinle
        db.collection("battles").document(battleId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    self?.showErrorAlert(error)
                    return
                }
                
                guard let data = snapshot?.data(),
                      let players = data["players"] as? [String],
                      let status = data["status"] as? String else { return }
                
                // Oyuncu sayısını güncelle
                self?.statusLabel.text = "Oyuncular Bekleniyor (\(players.count)/4)"
                
                // Eğer yarışma aktif duruma geçtiyse
                if status == "active" {
                    self?.timer?.invalidate()
                    self?.navigateToQuizBattle(battleId: battleId)
                }
                
                // Eğer yeterli oyuncu varsa veya süre dolduysa
                if players.count >= 4 || (self?.remainingTime ?? 0) <= 0 {
                    self?.startBattle(battleId: battleId)
                }
            }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            
            self.remainingTime -= 1
            self.updateTimerLabel()
            
            if self.remainingTime <= 0 {
                timer.invalidate()
                self.startBattle(battleId: battleId)
            }
        }
    }
    
    private func updateTimerLabel() {
        timerLabel.text = "\(remainingTime) saniye"
    }
    
    private func startBattle(battleId: String) {
        guard let currentBattleId = currentBattleId else { return }
        
        db.collection("battles").document(currentBattleId).updateData([
            "status": "active"
        ]) { [weak self] error in
            if let error = error {
                self?.showErrorAlert(error)
            }
        }
    }
    
    private func navigateToQuizBattle(battleId: String) {
        // Battle verilerini al
        db.collection("battles").document(battleId).getDocument { [weak self] snapshot, error in
            if let error = error {
                self?.showErrorAlert(error)
                return
            }
            
            guard let data = snapshot?.data(),
                  let category = data["category"] as? String,
                  let difficulty = data["difficulty"] as? String,
                  let players = data["players"] as? [String] else {
                self?.showErrorAlert(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Battle verisi alınamadı"]))
                return
            }
            
            // Rakip ID'sini bul
            guard let currentUserId = self?.currentUserId else { return }
            let opponentId = players.first { $0 != currentUserId } ?? ""
            
            DispatchQueue.main.async {
                let quizBattleVC = QuizBattleViewController(category: category,
                                                           difficulty: difficulty,
                                                           battleId: battleId,
                                                           opponentId: opponentId)
                self?.navigationController?.pushViewController(quizBattleVC, animated: true)
            }
        }
    }
    
    private func observeBattleInvitations() {
        guard let userId = currentUserId else { return }
        
        db.collection("battleInvitations")
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    self?.showErrorAlert(error)
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                // If we received new invitations, show them
                let newInvitations = documents.filter { document in
                    if let battleInvitations = self?.battleInvitations {
                        return !battleInvitations.contains(document)
                    }
                    return true
                }
                self?.battleInvitations = documents
                
                if !newInvitations.isEmpty {
                    self?.handleNewBattleInvitations(newInvitations)
                }
            }
    }
    
    private func handleNewBattleInvitations(_ invitations: [QueryDocumentSnapshot]) {
        guard let invitation = invitations.first,
              let fromUserId = invitation.data()["fromUserId"] as? String,
              let battleId = invitation.data()["battleId"] as? String else {
            return
        }
        
        // Get the sender's user info
        FirebaseService.shared.getUser(userId: fromUserId) { [weak self] result in
            switch result {
            case .success(let user):
                // Show the invitation alert
                DispatchQueue.main.async {
                    self?.showBattleInvitationAlert(invitation: invitation, fromUser: user, battleId: battleId)
                }
                
            case .failure(let error):
                self?.showErrorAlert(error)
            }
        }
    }
    
    private func showBattleInvitationAlert(invitation: QueryDocumentSnapshot, fromUser: User, battleId: String) {
        let alert = UIAlertController(
            title: "Yarışma Daveti",
            message: "\(fromUser.name) size yarışma daveti gönderdi. Kabul ediyor musunuz?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Kabul Et", style: .default) { [weak self] _ in
            self?.acceptBattleInvitation(invitation: invitation, battleId: battleId)
        })
        
        alert.addAction(UIAlertAction(title: "Reddet", style: .destructive) { [weak self] _ in
            self?.declineBattleInvitation(invitation: invitation)
        })
        
        present(alert, animated: true)
    }
    
    private func acceptBattleInvitation(invitation: QueryDocumentSnapshot, battleId: String) {
        FirebaseService.shared.acceptBattleInvitation(invitationId: invitation.documentID) { [weak self] result in
            switch result {
            case .success(_):
                // Navigate to the battle screen
                self?.navigateToQuizBattle(battleId: battleId)
                
            case .failure(let error):
                self?.showErrorAlert(error)
            }
        }
    }
    
    private func declineBattleInvitation(invitation: QueryDocumentSnapshot) {
        FirebaseService.shared.declineBattleInvitation(invitationId: invitation.documentID) { [weak self] result in
            if case .failure(let error) = result {
                self?.showErrorAlert(error)
            }
        }
    }
}

// MARK: - UICollectionView DataSource
extension OnlineBattleViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return onlineUsers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "OnlineUserCell", for: indexPath) as! OnlineUserCell
        let user = onlineUsers[indexPath.item]
        
        // Configure cell
        cell.configure(with: user)
        
        // Set selection state
        if let selectedUserId = selectedUserId, user.id == selectedUserId {
            cell.setSelected(true)
        } else {
            cell.setSelected(false)
        }
        
        return cell
    }
}

// MARK: - UICollectionView Delegate
extension OnlineBattleViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Get the selected user
        let selectedUser = onlineUsers[indexPath.item]
        
        // Update the selected user ID
        selectedUserId = selectedUser.id
        
        // Enable the create battle button
        createBattleButton.isEnabled = true
        createBattleButton.alpha = 1.0
        createBattleButton.setTitle("Yarışma İsteği Gönder: \(selectedUser.name)", for: .normal)
        
        // Update the UI to show selection
        collectionView.reloadData()
    }
}

// MARK: - UICollectionView FlowLayout Delegate
extension OnlineBattleViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width - 32
        return CGSize(width: width, height: 80)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
    }
}

// MARK: - OnlineUserCell
class OnlineUserCell: UICollectionViewCell {
    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 30
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let statusIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGreen
        view.layer.cornerRadius = 5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .systemGray6
        layer.cornerRadius = 12
        
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(statusIndicator)
        
        NSLayoutConstraint.activate([
            avatarImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            avatarImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 60),
            avatarImageView.heightAnchor.constraint(equalToConstant: 60),
            
            nameLabel.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            
            statusIndicator.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            statusIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            statusIndicator.widthAnchor.constraint(equalToConstant: 10),
            statusIndicator.heightAnchor.constraint(equalToConstant: 10)
        ])
    }
    
    func configure(with user: User) {
        nameLabel.text = user.name
        if let avatarEnum = Avatar(rawValue: user.avatar) {
            avatarImageView.image = avatarEnum.image
            avatarImageView.backgroundColor = avatarEnum.backgroundColor
        }
    }
    
    func setSelected(_ selected: Bool) {
        statusIndicator.backgroundColor = selected ? .systemGreen : .systemGray
    }
} 