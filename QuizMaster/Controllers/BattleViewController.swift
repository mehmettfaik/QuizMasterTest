import UIKit
import FirebaseFirestore

class BattleViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private var tableView: UITableView!
    private var categories: [String] = []
    private var selectedCategory: String?
    private let firebaseService = FirebaseService.shared
    private var isChallenger: Bool
    private var battleId: String
    private var opponentId: String
    private var battleListener: ListenerRegistration?
    private var waitingAlert: UIAlertController?
    
    init(isChallenger: Bool, opponentId: String, battleId: String? = nil) {
        self.isChallenger = isChallenger
        self.opponentId = opponentId
        self.battleId = battleId ?? opponentId  // If battleId is not provided, use opponentId as fallback
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        battleListener?.remove()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = isChallenger ? "Select Category" : "Waiting for Challenger"
        
        if isChallenger {
            setupCategorySelection()
        } else {
            setupWaitingView()
            listenForBattleUpdates()
        }
    }
    
    private func setupCategorySelection() {
        // Setup table view for category selection
        tableView = UITableView(frame: view.bounds)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CategoryCell")
        view.addSubview(tableView)
        
        // Add start battle button
        let startButton = UIButton(type: .system)
        startButton.setTitle("Start Battle", for: .normal)
        startButton.backgroundColor = .systemBlue
        startButton.setTitleColor(.white, for: .normal)
        startButton.layer.cornerRadius = 8
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.addTarget(self, action: #selector(startBattleTapped), for: .touchUpInside)
        view.addSubview(startButton)
        
        NSLayoutConstraint.activate([
            startButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            startButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            startButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            startButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Adjust table view frame to account for button
        tableView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - 80)
        
        // Load categories from QuizCategory enum
        categories = QuizCategory.allCases.map { $0.rawValue }
        tableView.reloadData()
    }
    
    private func setupWaitingView() {
        let waitingLabel = UILabel()
        waitingLabel.text = "Waiting for challenger to set up the battle..."
        waitingLabel.textAlignment = .center
        waitingLabel.numberOfLines = 0
        waitingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(waitingLabel)
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.startAnimating()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            waitingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            waitingLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            waitingLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            waitingLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: waitingLabel.bottomAnchor, constant: 20)
        ])
    }
    
    private func listenForBattleUpdates() {
        battleListener = firebaseService.listenForBattleUpdates(battleId: battleId) { [weak self] battleData in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let status = battleData["status"] as? String {
                    switch status {
                    case "accepted":
                        if !self.isChallenger {
                            // Opponent waiting for category selection
                            if let category = battleData["category"] as? String,
                               !category.isEmpty {
                                let battleQuestionVC = BattleQuestionViewController(
                                    category: category,
                                    opponentId: self.battleId
                                )
                                self.navigationController?.pushViewController(battleQuestionVC, animated: true)
                            }
                        }
                        
                    case "ready":
                        // Both players can start the battle
                        self.waitingAlert?.dismiss(animated: true) {
                            if let category = battleData["category"] as? String,
                               !category.isEmpty {
                                let battleQuestionVC = BattleQuestionViewController(
                                    category: category,
                                    opponentId: self.battleId
                                )
                                self.navigationController?.pushViewController(battleQuestionVC, animated: true)
                            }
                        }
                        
                    case "rejected":
                        self.waitingAlert?.dismiss(animated: true) {
                            let alert = UIAlertController(
                                title: "Challenge Rejected",
                                message: "The opponent has rejected your challenge.",
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                                self.navigationController?.popViewController(animated: true)
                            })
                            self.present(alert, animated: true)
                        }
                        
                    default:
                        break
                    }
                }
            }
        }
    }
    
    @objc private func startBattleTapped() {
        guard let selectedCategory = selectedCategory else {
            let alert = UIAlertController(title: "Error", message: "Please select a category", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        // Update battle with selected category and set status to ready
        firebaseService.updateBattleState(battleId: battleId, category: selectedCategory, status: "ready") { [weak self] success in
            guard success else { return }
            
            // Wait for opponent to join
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.waitingAlert = UIAlertController(
                    title: "Starting Battle",
                    message: "Preparing the quiz battle...",
                    preferredStyle: .alert
                )
                
                self.waitingAlert?.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
                    self?.firebaseService.cancelChallenge(battleId: self?.battleId ?? "")
                    self?.navigationController?.popViewController(animated: true)
                })
                
                if let alert = self.waitingAlert {
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell", for: indexPath)
        let category = categories[indexPath.row]
        cell.textLabel?.text = category
        
        // Add checkmark for selected category
        if category == selectedCategory {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectedCategory = categories[indexPath.row]
        tableView.reloadData()
    }
}
