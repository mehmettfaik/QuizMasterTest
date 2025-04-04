import UIKit
import FirebaseAuth
import FirebaseFirestore

class MultiplayerGameViewController: UIViewController {
    private let game: MultiplayerGame
    private let multiplayerService = MultiplayerGameService.shared
    private var gameListener: ListenerRegistration?
    private var questionStartTime: Date?
    private var isWaitingForNextQuestion = false
    
    private let questionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 18, weight: .medium)
        return label
    }()
    
    private let timerLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 24, weight: .bold)
        return label
    }()
    
    private let scoreLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16)
        return label
    }()
    
    private lazy var answerStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.distribution = .fillEqually
        return stack
    }()
    
    private var timer: Timer?
    private var timeLeft: Int = 5 // 5 seconds per question
    private var currentQuestion: Question?
    private var hasAnswered: Bool = false
    private var correctAnswerButton: UIButton?
    
    private let scoreAnimationView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGreen
        view.alpha = 0
        view.layer.cornerRadius = 20
        view.isHidden = true
        return view
    }()
    
    private let scoreAnimationLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 24, weight: .bold)
        return label
    }()
    
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
        setupGameListener()
        loadQuestion(at: game.currentQuestionIndex)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        gameListener?.remove()
        timer?.invalidate()
    }
    
    private func setupUI() {
        title = "Multiplayer Quiz"
        view.backgroundColor = .systemBackground
        
        // Make all views translucent to false
        [timerLabel, questionLabel, answerStackView, scoreLabel, scoreAnimationView, scoreAnimationLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        // Configure timer label
        timerLabel.font = .systemFont(ofSize: 40, weight: .bold)
        timerLabel.textColor = .systemBlue
        
        // Configure question label
        questionLabel.font = .systemFont(ofSize: 20, weight: .medium)
        questionLabel.numberOfLines = 0
        questionLabel.textAlignment = .center
        
        // Configure answer stack view
        answerStackView.axis = .vertical
        answerStackView.spacing = 12
        answerStackView.distribution = .fillEqually
        answerStackView.alignment = .fill
        
        // Configure score label
        scoreLabel.font = .systemFont(ofSize: 18, weight: .medium)
        scoreLabel.textColor = .darkGray
        
        // Add subviews
        [timerLabel, questionLabel, answerStackView, scoreLabel].forEach {
            view.addSubview($0)
        }
        view.addSubview(scoreAnimationView)
        scoreAnimationView.addSubview(scoreAnimationLabel)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Timer label constraints
            timerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            timerLabel.heightAnchor.constraint(equalToConstant: 50),
            
            // Question label constraints
            questionLabel.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 40),
            questionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            questionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Answer stack view constraints
            answerStackView.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 40),
            answerStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            answerStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            answerStackView.bottomAnchor.constraint(lessThanOrEqualTo: scoreLabel.topAnchor, constant: -20),
            
            // Score label constraints
            scoreLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            scoreLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Score animation view constraints
            scoreAnimationView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scoreAnimationView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            scoreAnimationView.widthAnchor.constraint(equalToConstant: 120),
            scoreAnimationView.heightAnchor.constraint(equalToConstant: 60),
            
            // Score animation label constraints
            scoreAnimationLabel.centerXAnchor.constraint(equalTo: scoreAnimationView.centerXAnchor),
            scoreAnimationLabel.centerYAnchor.constraint(equalTo: scoreAnimationView.centerYAnchor)
        ])
        
        updateScoreLabel()
    }
    
    private func setupGameListener() {
        gameListener = multiplayerService.listenForGameUpdates(gameId: game.id) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let updatedGame):
                DispatchQueue.main.async {
                    // Update scores immediately
                    self.updateScoreLabel()
                    
                    // Handle question changes
                    if updatedGame.currentQuestionIndex != self.game.currentQuestionIndex {
                        self.isWaitingForNextQuestion = false
                        self.loadQuestion(at: updatedGame.currentQuestionIndex)
                    }
                    
                    // Handle question start time updates
                    if let serverStartTime = updatedGame.questionStartTime?.dateValue(),
                       self.questionStartTime != serverStartTime {
                        self.questionStartTime = serverStartTime
                        self.syncTimer(with: serverStartTime)
                    }
                }
            case .failure(let error):
                print("Error listening for game updates: \(error.localizedDescription)")
            }
        }
    }
    
    private func syncTimer(with startTime: Date) {
        let elapsedTime = Date().timeIntervalSince(startTime)
        let remainingTime = max(5 - Int(elapsedTime), 0)
        
        timeLeft = remainingTime
        updateTimerLabel()
        
        if remainingTime > 0 {
            startTimer(initialTime: remainingTime)
        } else {
            handleTimeUp()
        }
    }
    
    private func loadQuestion(at index: Int) {
        guard let questions = game.questions, index < questions.count else {
            endGame()
            return
        }
        
        // Reset UI state
        DispatchQueue.main.async {
            self.resetUIState()
        }
        
        let questionId = questions[index]
        multiplayerService.getQuestion(questionId: questionId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let question):
                DispatchQueue.main.async {
                    self.displayQuestion(question)
                    
                    // If this is the creator, update the question start time
                    if self.game.creatorId == Auth.auth().currentUser?.uid {
                        self.multiplayerService.updateQuestionStartTime(gameId: self.game.id) { error in
                            if let error = error {
                                print("Error updating question start time: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            case .failure(let error):
                print("Error loading question: \(error.localizedDescription)")
            }
        }
    }
    
    private func resetUIState() {
        // Reset all state variables
        hasAnswered = false
        correctAnswerButton = nil
        isWaitingForNextQuestion = false
        timeLeft = 5
        
        // Reset timer label
        updateTimerLabel()
        
        // Clear existing buttons
        DispatchQueue.main.async {
            self.answerStackView.arrangedSubviews.forEach { view in
                view.removeFromSuperview()
            }
            self.answerStackView.layoutIfNeeded()
        }
        
        // Stop existing timer
        timer?.invalidate()
        timer = nil
    }
    
    private func displayQuestion(_ question: Question) {
        currentQuestion = question
        
        DispatchQueue.main.async {
            // Update question text
            self.questionLabel.text = question.text
            
            // Remove existing buttons
            self.answerStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            
            // Create and add new buttons
            for option in question.options {
                let button = UIButton(type: .system)
                button.translatesAutoresizingMaskIntoConstraints = false
                button.setTitle(option, for: .normal)
                button.titleLabel?.font = .systemFont(ofSize: 18)
                button.backgroundColor = .systemBlue.withAlphaComponent(0.1)
                button.setTitleColor(.systemBlue, for: .normal)
                button.layer.cornerRadius = 12
                button.layer.borderWidth = 1
                button.layer.borderColor = UIColor.systemBlue.cgColor
                
                // Set content hugging and compression resistance
                button.setContentHuggingPriority(.required, for: .vertical)
                button.setContentCompressionResistancePriority(.required, for: .vertical)
                
                // Configure button constraints
                button.heightAnchor.constraint(equalToConstant: 56).isActive = true
                button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
                
                // Add targets
                button.addTarget(self, action: #selector(self.answerButtonTapped(_:)), for: .touchUpInside)
                button.addTarget(self, action: #selector(self.buttonTouchDown(_:)), for: .touchDown)
                button.addTarget(self, action: #selector(self.buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside])
                
                // Ensure button is enabled and interactive
                button.isEnabled = true
                button.isUserInteractionEnabled = true
                
                self.answerStackView.addArrangedSubview(button)
            }
            
            // Force layout update
            self.answerStackView.layoutIfNeeded()
            self.view.layoutIfNeeded()
            
            // Start timer after UI is updated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.startTimer()
            }
        }
    }
    
    private func startTimer(initialTime: Int = 5) {
        // Stop existing timer
        timer?.invalidate()
        timer = nil
        
        timeLeft = initialTime
        updateTimerLabel()
        
        // Create new timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if self.timeLeft > 0 {
                    self.timeLeft -= 1
                    self.updateTimerLabel()
                }
                
                if self.timeLeft == 0 && !self.isWaitingForNextQuestion {
                    self.timer?.invalidate()
                    self.handleTimeUp()
                }
            }
        }
        
        // Add timer to main run loop
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    private func updateTimerLabel() {
        timerLabel.text = "\(timeLeft)"
    }
    
    private func updateScoreLabel() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let currentPlayerScore = game.playerScores[currentUserId]?.score ?? 0
        let opponentId = game.creatorId == currentUserId ? game.invitedId : game.creatorId
        let opponentScore = game.playerScores[opponentId]?.score ?? 0
        
        scoreLabel.text = "You: \(currentPlayerScore) - Opponent: \(opponentScore)"
    }
    
    @objc private func answerButtonTapped(_ sender: UIButton) {
        guard let question = currentQuestion,
              !hasAnswered,
              !isWaitingForNextQuestion,
              timeLeft > 0 else { return }
        
        // Immediately disable all buttons to prevent double taps
        answerStackView.arrangedSubviews.forEach { view in
            if let button = view as? UIButton {
                button.isEnabled = false
            }
        }
        
        hasAnswered = true
        let selectedAnswer = sender.title(for: .normal) ?? ""
        let isCorrect = selectedAnswer == question.correctAnswer
        
        // Highlight selected answer
        sender.backgroundColor = .systemPurple.withAlphaComponent(0.3)
        sender.layer.borderColor = UIColor.systemPurple.cgColor
        
        // Store correct answer button
        for view in answerStackView.arrangedSubviews {
            if let button = view as? UIButton,
               button.title(for: .normal) == question.correctAnswer {
                correctAnswerButton = button
                break
            }
        }
        
        // Submit answer to server
        guard let userId = Auth.auth().currentUser?.uid else { return }
        multiplayerService.submitAnswer(gameId: game.id, userId: userId, isCorrect: isCorrect) { [weak self] result in
            if case .failure(let error) = result {
                print("Error submitting answer: \(error.localizedDescription)")
            }
        }
    }
    
    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            sender.backgroundColor = .systemBlue.withAlphaComponent(0.2)
        }
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = .identity
            sender.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        }
    }
    
    private func handleTimeUp() {
        guard !isWaitingForNextQuestion else { return }
        isWaitingForNextQuestion = true
        
        // Stop the timer
        timer?.invalidate()
        timer = nil
        
        DispatchQueue.main.async {
            // Disable all buttons
            self.answerStackView.arrangedSubviews.forEach { view in
                if let button = view as? UIButton {
                    button.isEnabled = false
                }
            }
            
            // Show correct answer
            self.correctAnswerButton?.backgroundColor = .systemGreen.withAlphaComponent(0.3)
            self.correctAnswerButton?.layer.borderColor = UIColor.systemGreen.cgColor
            
            // If user hasn't answered, submit a wrong answer
            if !self.hasAnswered {
                guard let userId = Auth.auth().currentUser?.uid else { return }
                self.multiplayerService.submitAnswer(gameId: self.game.id, userId: userId, isCorrect: false) { result in
                    if case .failure(let error) = result {
                        print("Error submitting answer: \(error.localizedDescription)")
                    }
                }
            }
            
            // Only the creator moves to the next question
            if self.game.creatorId == Auth.auth().currentUser?.uid {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    guard let self = self else { return }
                    
                    self.multiplayerService.moveToNextQuestion(gameId: self.game.id) { error in
                        if let error = error {
                            print("Error moving to next question: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    private func endGame() {
        timer?.invalidate()
        
        DispatchQueue.main.async {
            // Get final scores
            guard let currentUserId = Auth.auth().currentUser?.uid else { return }
            let currentPlayerScore = self.game.playerScores[currentUserId]?.score ?? 0
            let opponentId = self.game.creatorId == currentUserId ? self.game.invitedId : self.game.creatorId
            let opponentScore = self.game.playerScores[opponentId]?.score ?? 0
            
            let message = """
                Game Over!
                Your Score: \(currentPlayerScore)
                Opponent Score: \(opponentScore)
                \(currentPlayerScore > opponentScore ? "You Won! 🎉" : currentPlayerScore < opponentScore ? "You Lost!" : "It's a Tie!")
                """
            
            let alert = UIAlertController(title: "Game Over",
                                        message: message,
                                        preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.navigationController?.popToRootViewController(animated: true)
            })
            self.present(alert, animated: true)
        }
    }
} 