import UIKit
import FirebaseFirestore
import Combine
import FirebaseAuth


class QuizBattleViewController: UIViewController {
    private let category: String
    private let difficulty: String
    private let battleId: String
    private let opponentId: String
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var currentQuestion: [String: Any]?
    private var questions: [[String: Any]] = []
    private var currentQuestionIndex = 0
    private var timer: Timer?
    private var timeLeft = 15 // Each question has 15 seconds
    private var score = 0
    private var players: [User] = []
    private var questionListener: ListenerRegistration?
    private var currentQuestionData: [String: Any]?
    private var isAnswered = false
    
    // MARK: - UI Components
    private let containerStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .fill
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let playersContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let player1View: PlayerScoreView = {
        let view = PlayerScoreView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let player2View: PlayerScoreView = {
        let view = PlayerScoreView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let vsLabel: UILabel = {
        let label = UILabel()
        label.text = "VS"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .primaryPurple
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let timerLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .primaryPurple
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let questionContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let questionLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let answersStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .primaryPurple
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Initialization
    init(category: String, difficulty: String, battleId: String, opponentId: String) {
        self.category = category
        self.difficulty = difficulty
        self.battleId = battleId
        self.opponentId = opponentId
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCloseButton()
        fetchBattleDetails()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        questionListener?.remove()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Canlı Yarışma"
        
        view.addSubview(containerStackView)
        
        // Add players view
        containerStackView.addArrangedSubview(playersContainerView)
        playersContainerView.addSubview(player1View)
        playersContainerView.addSubview(vsLabel)
        playersContainerView.addSubview(player2View)
        
        // Add timer and question container
        containerStackView.addArrangedSubview(timerLabel)
        containerStackView.addArrangedSubview(questionContainerView)
        questionContainerView.addSubview(questionLabel)
        
        // Add answers stack view
        containerStackView.addArrangedSubview(answersStackView)
        
        // Add loading indicator
        containerStackView.addArrangedSubview(loadingIndicator)
        
        // Setup constraints for container stack view
        NSLayoutConstraint.activate([
            containerStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            containerStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            containerStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            containerStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            // Player view constraints
            playersContainerView.heightAnchor.constraint(equalToConstant: 80),
            
            player1View.leadingAnchor.constraint(equalTo: playersContainerView.leadingAnchor),
            player1View.topAnchor.constraint(equalTo: playersContainerView.topAnchor),
            player1View.bottomAnchor.constraint(equalTo: playersContainerView.bottomAnchor),
            player1View.widthAnchor.constraint(equalTo: playersContainerView.widthAnchor, multiplier: 0.45),
            
            vsLabel.centerXAnchor.constraint(equalTo: playersContainerView.centerXAnchor),
            vsLabel.centerYAnchor.constraint(equalTo: playersContainerView.centerYAnchor),
            
            player2View.trailingAnchor.constraint(equalTo: playersContainerView.trailingAnchor),
            player2View.topAnchor.constraint(equalTo: playersContainerView.topAnchor),
            player2View.bottomAnchor.constraint(equalTo: playersContainerView.bottomAnchor),
            player2View.widthAnchor.constraint(equalTo: playersContainerView.widthAnchor, multiplier: 0.45),
            
            // Question container constraints
            questionContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            questionLabel.topAnchor.constraint(equalTo: questionContainerView.topAnchor, constant: 20),
            questionLabel.leadingAnchor.constraint(equalTo: questionContainerView.leadingAnchor, constant: 20),
            questionLabel.trailingAnchor.constraint(equalTo: questionContainerView.trailingAnchor, constant: -20),
            questionLabel.bottomAnchor.constraint(equalTo: questionContainerView.bottomAnchor, constant: -20)
        ])
        
        loadingIndicator.startAnimating()
    }
    
    private func setupCloseButton() {
        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
        navigationItem.leftBarButtonItem = closeButton
    }
    
    @objc private func closeButtonTapped() {
        let alert = UIAlertController(
            title: "Yarışmadan Çıkılsın mı?",
            message: "Yarışmadan çıkmak istediğinize emin misiniz?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "İptal", style: .cancel))
        alert.addAction(UIAlertAction(title: "Çık", style: .destructive) { [weak self] _ in
            self?.leaveQuiz()
        })
        
        present(alert, animated: true)
    }
    
    private func leaveQuiz() {
        // Update battle status to mark player as left
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("battles").document(battleId).updateData([
            "playerLeft": userId
        ]) { [weak self] error in
            if let error = error {
                print("Error updating battle: \(error)")
            }
            
            self?.navigationController?.popViewController(animated: true)
        }
    }
    
    // MARK: - Battle Management
    private func fetchBattleDetails() {
        loadingIndicator.startAnimating()
        
        // Get user details
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            showErrorAlert(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı bulunamadı"]))
            return
        }
        
        let group = DispatchGroup()
        
        // Get current user
        group.enter()
        FirebaseService.shared.getUser(userId: currentUserId) { [weak self] result in
            defer { group.leave() }
            
            switch result {
            case .success(let user):
                self?.players.append(user)
            case .failure(let error):
                print("Error fetching current user: \(error)")
            }
        }
        
        // Get opponent user
        group.enter()
        FirebaseService.shared.getUser(userId: opponentId) { [weak self] result in
            defer { group.leave() }
            
            switch result {
            case .success(let user):
                self?.players.append(user)
            case .failure(let error):
                print("Error fetching opponent user: \(error)")
            }
        }
        
        // Get battle details and questions
        group.enter()
        db.collection("battles").document(battleId).getDocument { [weak self] snapshot, error in
            defer { group.leave() }
            
            if let error = error {
                self?.showErrorAlert(error)
                return
            }
            
            guard let data = snapshot?.data(),
                  let questions = data["questions"] as? [[String: Any]] else {
                self?.showErrorAlert(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Yarışma verileri bulunamadı"]))
                return
            }
            
            self?.questions = questions
            
            // Update battle status if needed
            if data["status"] as? String != "active" {
                self?.db.collection("battles").document(self?.battleId ?? "").updateData([
                    "status": "active"
                ])
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.loadingIndicator.stopAnimating()
            
            if self?.players.count == 2 {
                self?.updatePlayerViews()
                self?.startObservingBattle()
                self?.showQuestion(at: 0)
            } else {
                self?.showErrorAlert(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Oyuncular hazırlanamadı"]))
            }
        }
    }
    
    private func updatePlayerViews() {
        guard players.count >= 2 else { return }
        
        let currentUser = players.first { $0.id == Auth.auth().currentUser?.uid }
        let opponent = players.first { $0.id != Auth.auth().currentUser?.uid }
        
        player1View.configure(with: currentUser?.name ?? "Ben", score: 0, isCurrentUser: true)
        player2View.configure(with: opponent?.name ?? "Rakip", score: 0, isCurrentUser: false)
    }
    
    private func startObservingBattle() {
        questionListener = db.collection("battles").document(battleId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Error listening to battle updates: \(error)")
                    return
                }
                
                guard let data = snapshot?.data() else { return }
                
                // Check for current question index
                if let questionIndex = data["currentQuestion"] as? Int,
                   questionIndex != self?.currentQuestionIndex {
                    self?.currentQuestionIndex = questionIndex
                    self?.showQuestion(at: questionIndex)
                }
                
                // Update scores
                if let scores = data["scores"] as? [String: Int] {
                    for (userId, score) in scores {
                        if userId == Auth.auth().currentUser?.uid {
                            self?.player1View.updateScore(score)
                        } else if userId == self?.opponentId {
                            self?.player2View.updateScore(score)
                        }
                    }
                }
                
                // Check for game end
                if let status = data["status"] as? String, status == "completed" {
                    self?.showResults(data: data)
                }
            }
    }
    
    private func showQuestion(at index: Int) {
        guard index < questions.count else {
            // End the quiz if we've gone through all questions
            endQuiz()
            return
        }
        
        isAnswered = false
        currentQuestionData = questions[index]
        
        // Reset UI
        answersStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Setup question
        if let questionText = currentQuestionData?["question"] as? String {
            questionLabel.text = questionText
        }
        
        // Create answer buttons
        if let options = currentQuestionData?["options"] as? [String] {
            for (index, option) in options.enumerated() {
                let button = createAnswerButton(option, tag: index)
                answersStackView.addArrangedSubview(button)
            }
        }
        
        // Start timer
        timeLeft = 15
        updateTimerLabel()
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.timeLeft -= 1
            self?.updateTimerLabel()
            
            if self?.timeLeft == 0 {
                self?.timer?.invalidate()
                self?.handleAnswer(isTimeout: true)
            }
        }
    }
    
    private func createAnswerButton(_ title: String, tag: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .primaryPurple
        button.layer.cornerRadius = 12
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        button.tag = tag
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
        
        button.addTarget(self, action: #selector(answerButtonTapped(_:)), for: .touchUpInside)
        return button
    }
    
    @objc private func answerButtonTapped(_ sender: UIButton) {
        guard !isAnswered else { return }
        
        isAnswered = true
        handleAnswer(selectedIndex: sender.tag)
    }
    
    private func handleAnswer(selectedIndex: Int? = nil, isTimeout: Bool = false) {
        guard let currentQuestion = currentQuestionData else { return }
        
        var isCorrect = false
        if !isTimeout, let selectedIndex = selectedIndex,
           let options = currentQuestion["options"] as? [String],
           let correctAnswer = currentQuestion["correct_answer"] as? String,
           selectedIndex < options.count {
            
            isCorrect = options[selectedIndex] == correctAnswer
        }
        
        // Update UI to show correct answer
        for (index, view) in answersStackView.arrangedSubviews.enumerated() {
            if let button = view as? UIButton,
               let options = currentQuestion["options"] as? [String],
               let correctAnswer = currentQuestion["correct_answer"] as? String,
               index < options.count {
                
                if options[index] == correctAnswer {
                    button.backgroundColor = .systemGreen
                } else if selectedIndex == index {
                    button.backgroundColor = .systemRed
                }
                
                // Disable all buttons
                button.isEnabled = false
            }
        }
        
        // Update score in Firestore
        if isCorrect {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            
            db.collection("battles").document(battleId).updateData([
                "scores.\(userId)": FieldValue.increment(Int64(10))
            ])
        }
        
        // Wait for a moment before showing the next question
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            
            // If the current user is the creator, update the current question index
            db.collection("battles").document(self.battleId).getDocument { snapshot, error in
                if let data = snapshot?.data(),
                   let creator = data["createdBy"] as? String,
                   creator == Auth.auth().currentUser?.uid {
                    
                    let nextIndex = self.currentQuestionIndex + 1
                    self.db.collection("battles").document(self.battleId).updateData([
                        "currentQuestion": nextIndex
                    ])
                    
                    // If we've reached the end, update status to completed
                    if nextIndex >= self.questions.count {
                        self.db.collection("battles").document(self.battleId).updateData([
                            "status": "completed"
                        ])
                    }
                }
            }
        }
    }
    
    private func updateTimerLabel() {
        timerLabel.text = "\(timeLeft) saniye"
        if timeLeft <= 5 {
            timerLabel.textColor = .systemRed
        } else {
            timerLabel.textColor = .primaryPurple
        }
    }
    
    private func endQuiz() {
        timer?.invalidate()
        
        db.collection("battles").document(battleId).updateData([
            "status": "completed"
        ])
    }
    
    private func showResults(data: [String: Any]) {
        timer?.invalidate()
        
        // Show results
        guard let scores = data["scores"] as? [String: Int],
              let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let currentUserScore = scores[currentUserId] ?? 0
        let opponentScore = scores[opponentId] ?? 0
        
        var resultMessage = ""
        if currentUserScore > opponentScore {
            resultMessage = "Tebrikler! Kazandınız!"
        } else if currentUserScore < opponentScore {
            resultMessage = "Maalesef kaybettiniz."
        } else {
            resultMessage = "Berabere bitti!"
        }
        
        // Show alert
        let alert = UIAlertController(
            title: "Yarışma Bitti",
            message: "\(resultMessage)\n\nSonuç: \(currentUserScore) - \(opponentScore)",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Tamam", style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
}

// MARK: - PlayerScoreView
class PlayerScoreView: UIView {
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let scoreLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.textColor = .primaryPurple
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 12
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
        addSubview(containerView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(scoreLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            scoreLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            scoreLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            scoreLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            scoreLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with name: String, score: Int, isCurrentUser: Bool) {
        nameLabel.text = name
        scoreLabel.text = "\(score)"
        
        if isCurrentUser {
            containerView.backgroundColor = .primaryPurple.withAlphaComponent(0.1)
            nameLabel.font = .systemFont(ofSize: 14, weight: .bold)
        } else {
            containerView.backgroundColor = .systemGray6
            nameLabel.font = .systemFont(ofSize: 14, weight: .medium)
        }
    }
    
    func updateScore(_ score: Int) {
        scoreLabel.text = "\(score)"
    }
} 
