import UIKit
import FirebaseFirestore

class GameSetupViewController: UIViewController {
    private let game: MultiplayerGame
    private let multiplayerService = MultiplayerGameService.shared
    
    private let categoryPicker: UIPickerView = {
        let picker = UIPickerView()
        return picker
    }()
    
    private let difficultyPicker: UIPickerView = {
        let picker = UIPickerView()
        return picker
    }()
    
    private let startButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Start Game", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        return button
    }()
    
    private var categories: [QuizCategory] = []
    private let difficulties = ["Easy", "Medium", "Hard"]
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    
    // Listeners
    private var categoryListener: ListenerRegistration?
    private var gameListener: ListenerRegistration?
    
    init(game: MultiplayerGame) {
        self.game = game
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupListeners()
        fetchCategories()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        categoryListener?.remove()
        gameListener?.remove()
    }
    
    private func setupUI() {
        title = "Game Setup"
        view.backgroundColor = .systemBackground
        
        let categoryLabel = UILabel()
        categoryLabel.text = "Select Category"
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let difficultyLabel = UILabel()
        difficultyLabel.text = "Select Difficulty"
        difficultyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        categoryPicker.delegate = self
        categoryPicker.dataSource = self
        difficultyPicker.delegate = self
        difficultyPicker.dataSource = self
        
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        
        [categoryLabel, categoryPicker, difficultyLabel, difficultyPicker, startButton, loadingIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            categoryLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            categoryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            categoryPicker.topAnchor.constraint(equalTo: categoryLabel.bottomAnchor, constant: 8),
            categoryPicker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoryPicker.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoryPicker.heightAnchor.constraint(equalToConstant: 150),
            
            difficultyLabel.topAnchor.constraint(equalTo: categoryPicker.bottomAnchor, constant: 20),
            difficultyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            difficultyPicker.topAnchor.constraint(equalTo: difficultyLabel.bottomAnchor, constant: 8),
            difficultyPicker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            difficultyPicker.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            difficultyPicker.heightAnchor.constraint(equalToConstant: 150),
            
            startButton.topAnchor.constraint(equalTo: difficultyPicker.bottomAnchor, constant: 40),
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.widthAnchor.constraint(equalToConstant: 200),
            startButton.heightAnchor.constraint(equalToConstant: 44),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
    }
    
    private func setupListeners() {
        // Listen for game status changes
        gameListener = multiplayerService.listenForGameUpdates(gameId: game.id) { [weak self] result in
            switch result {
            case .success(let updatedGame):
                if updatedGame.status == .inProgress {
                    DispatchQueue.main.async {
                        let gameVC = MultiplayerGameViewController(game: updatedGame)
                        self?.navigationController?.pushViewController(gameVC, animated: true)
                    }
                }
            case .failure(let error):
                print("Error listening for game updates: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchCategories() {
        loadingIndicator.startAnimating()
        startButton.isEnabled = false
        
        categoryListener = multiplayerService.getQuizCategories { [weak self] result in
            DispatchQueue.main.async {
                self?.loadingIndicator.stopAnimating()
                self?.startButton.isEnabled = true
                
                switch result {
                case .success(let categories):
                    self?.categories = categories
                    self?.categoryPicker.reloadAllComponents()
                case .failure(let error):
                    self?.showAlert(title: "Error", message: "Failed to load categories: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func startButtonTapped() {
        guard !categories.isEmpty else {
            showAlert(title: "Error", message: "Please wait for categories to load")
            return
        }
        
        let selectedCategory = categories[categoryPicker.selectedRow(inComponent: 0)]
        let selectedDifficulty = difficulties[difficultyPicker.selectedRow(inComponent: 0)].lowercased()
        
        startButton.isEnabled = false
        loadingIndicator.startAnimating()
        
        multiplayerService.setupGame(
            gameId: game.id,
            category: selectedCategory.rawValue,
            difficulty: selectedDifficulty
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.startButton.isEnabled = true
                self?.loadingIndicator.stopAnimating()
                
                switch result {
                case .success(let game):
                    print("Game setup successful: \(game.id)")
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

extension GameSetupViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerView == categoryPicker ? categories.count : difficulties.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerView == categoryPicker ? categories[row].rawValue : difficulties[row]
    }
} 