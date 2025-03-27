import UIKit

class BattleViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private var tableView: UITableView!
    private var categories: [String] = []
    private var selectedCategory: String?
    private let firebaseService = FirebaseService.shared
    private var isChallenger = true
    private var opponentId: String?
    
    init(isChallenger: Bool = true, opponentId: String? = nil) {
        self.isChallenger = isChallenger
        self.opponentId = opponentId
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = isChallenger ? "Select Category" : "Waiting for Challenger"
        
        if isChallenger {
            setupCategorySelection()
        } else {
            setupWaitingView()
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
        
        // Fetch categories
        fetchCategories()
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
        
        // TODO: Listen for battle start event from Firestore
    }
    
    private func fetchCategories() {
        firebaseService.fetchCategories { [weak self] categories in
            DispatchQueue.main.async {
                self?.categories = categories
                self?.tableView.reloadData()
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
        
        // Start the battle with the selected category
        let battleQuestionVC = BattleQuestionViewController(category: selectedCategory, opponentId: opponentId)
        navigationController?.pushViewController(battleQuestionVC, animated: true)
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
        
        // Update selected category
        selectedCategory = categories[indexPath.row]
        tableView.reloadData()
    }
}
