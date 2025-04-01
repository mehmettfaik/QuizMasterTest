import UIKit
import Combine
import FirebaseAuth

class BattleCategoryViewController: UIViewController {
    private var battle: QuizBattle
    private var categories: [String] = []
    private var selectedCategory: String?
    private var selectedDifficulty: QuizDifficulty?
    private var cancellables = Set<AnyCancellable>()
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 16
        layout.minimumInteritemSpacing = 16
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(BattleCategoryCell.self, forCellWithReuseIdentifier: "BattleCategoryCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .primaryPurple
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Kategori Seçin"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .primaryPurple
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let difficultySegmentedControl: UISegmentedControl = {
        let items = QuizDifficulty.allCases.map { $0.rawValue }
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0
        control.backgroundColor = .systemGray6
        control.selectedSegmentTintColor = .primaryPurple
        control.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        control.setTitleTextAttributes([.foregroundColor: UIColor.systemGray], for: .normal)
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private let nextButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Devam Et", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .primaryPurple
        button.layer.cornerRadius = 20
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.layer.shadowColor = UIColor.primaryPurple.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 8
        button.isEnabled = false
        button.alpha = 0.7
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    init(battle: QuizBattle) {
        self.battle = battle
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
        setupActions()
        fetchCategories()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        view.addSubview(difficultySegmentedControl)
        view.addSubview(collectionView)
        view.addSubview(nextButton)
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            
            difficultySegmentedControl.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
            difficultySegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            difficultySegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            collectionView.topAnchor.constraint(equalTo: difficultySegmentedControl.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            collectionView.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -24),
            
            nextButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            nextButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nextButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            nextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            nextButton.heightAnchor.constraint(equalToConstant: 50),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeButtonTapped))
        navigationItem.leftBarButtonItem = closeButton
    }
    
    private func setupCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    private func setupActions() {
        difficultySegmentedControl.addTarget(self, action: #selector(difficultyChanged), for: .valueChanged)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
    }
    
    private func fetchCategories() {
        loadingIndicator.startAnimating()
        collectionView.isHidden = true
        
        FirebaseService.shared.getQuizCategories { [weak self] result in
            self?.loadingIndicator.stopAnimating()
            self?.collectionView.isHidden = false
            
            switch result {
            case .success(let categories):
                self?.categories = categories
                self?.collectionView.reloadData()
                
            case .failure(let error):
                self?.showErrorAlert(error)
            }
        }
    }
    
    private func updateNextButton() {
        let isEnabled = selectedCategory != nil
        nextButton.isEnabled = isEnabled
        nextButton.alpha = isEnabled ? 1.0 : 0.7
    }
    
    @objc private func difficultyChanged() {
        let index = difficultySegmentedControl.selectedSegmentIndex
        selectedDifficulty = QuizDifficulty.allCases[index]
    }
    
    @objc private func nextButtonTapped() {
        guard let category = selectedCategory,
              let difficulty = selectedDifficulty ?? QuizDifficulty.allCases.first else {
            return
        }
        
        loadingIndicator.startAnimating()
        nextButton.isEnabled = false
        
        FirebaseService.shared.getQuizzes(
            category: QuizCategory(rawValue: category) ?? .generalCulture,
            difficulty: difficulty
        ) { [weak self] result in
            switch result {
            case .success(let quizzes):
                guard let quizId = quizzes.first?.id else {
                    self?.loadingIndicator.stopAnimating()
                    self?.nextButton.isEnabled = true
                    
                    let alert = UIAlertController(
                        title: "Hata",
                        message: "Bu kategori ve zorluk seviyesinde soru bulunamadı. Lütfen başka bir kategori veya zorluk seviyesi seçin.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "Tamam", style: .default))
                    self?.present(alert, animated: true)
                    return
                }
                
                guard let battle = self?.battle else { return }
                
                FirebaseService.shared.createBattle(
                    battleId: battle.id,
                    category: category,
                    difficulty: difficulty.rawValue,
                    quizId: quizId
                ) { [weak self] result in
                    self?.loadingIndicator.stopAnimating()
                    self?.nextButton.isEnabled = true
                    
                    switch result {
                    case .success:
                        self?.navigateToBattle(quizId: quizId)
                        
                    case .failure(let error):
                        self?.showErrorAlert(error)
                    }
                }
                
            case .failure(let error):
                self?.loadingIndicator.stopAnimating()
                self?.nextButton.isEnabled = true
                self?.showErrorAlert(error)
            }
        }
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    private func navigateToBattle(quizId: String) {
        guard let currentUser = Auth.auth().currentUser else { return }
        let isChallenger = currentUser.uid == battle.challengerId
        
        guard let category = selectedCategory else { return }
        
        FirebaseService.shared.getQuiz(id: quizId, category: category) { [weak self] result in
            switch result {
            case .success(let quiz):
                let battleVC = BattleQuizViewController(quiz: quiz, battle: self?.battle, isChallenger: isChallenger)
                battleVC.modalPresentationStyle = .fullScreen
                self?.present(battleVC, animated: true) {
                    self?.dismiss(animated: false)
                }
                
            case .failure(let error):
                self?.showErrorAlert(error)
            }
        }
    }
}

// MARK: - UICollectionViewDelegate & UICollectionViewDataSource
extension BattleCategoryViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return categories.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BattleCategoryCell", for: indexPath) as? BattleCategoryCell else {
            return UICollectionViewCell()
        }
        
        let category = categories[indexPath.item]
        cell.configure(with: category, isSelected: category == selectedCategory)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.frame.width - 16) / 2
        return CGSize(width: width, height: 100)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let category = categories[indexPath.item]
        
        if selectedCategory == category {
            selectedCategory = nil
        } else {
            selectedCategory = category
        }
        
        collectionView.reloadData()
        updateNextButton()
    }
} 