import UIKit
import FirebaseAuth
import FirebaseFirestore

class MultiplayerGameViewController: UIViewController {
    private let game: MultiplayerGame
    private let multiplayerService = MultiplayerGameService.shared
    private var gameListener: ListenerRegistration?
    
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
            
            // Score label constraints
            scoreLabel.topAnchor.constraint(equalTo: answerStackView.bottomAnchor, constant: 30),
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
            switch result {
            case .success(let updatedGame):
                self?.handleGameUpdate(updatedGame)
            case .failure(let error):
                print("Error listening for game updates: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleGameUpdate(_ updatedGame: MultiplayerGame) {
        if updatedGame.currentQuestionIndex != game.currentQuestionIndex {
            loadQuestion(at: updatedGame.currentQuestionIndex)
        }
        
        DispatchQueue.main.async {
            self.updateScoreLabel()
        }
    }
    
    private func loadQuestion(at index: Int) {
        guard let questions = game.questions, index < questions.count else {
            endGame()
            return
        }
        
        let questionId = questions[index]
        multiplayerService.getQuestion(questionId: questionId) { [weak self] result in
            switch result {
            case .success(let question):
                self?.displayQuestion(question)
            case .failure(let error):
                print("Error loading question: \(error.localizedDescription)")
            }
        }
    }
    
    private func displayQuestion(_ question: Question) {
        currentQuestion = question
        
        DispatchQueue.main.async {
            self.questionLabel.text = question.text
            self.answerStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            
            for option in question.options {
                let button = UIButton(type: .system)
                button.setTitle(option, for: .normal)
                button.titleLabel?.font = .systemFont(ofSize: 18)
                button.backgroundColor = .systemBlue.withAlphaComponent(0.1)
                button.setTitleColor(.systemBlue, for: .normal)
                button.layer.cornerRadius = 12
                button.layer.borderWidth = 1
                button.layer.borderColor = UIColor.systemBlue.cgColor
                button.heightAnchor.constraint(equalToConstant: 56).isActive = true
                button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
                button.addTarget(self, action: #selector(self.answerButtonTapped(_:)), for: .touchUpInside)
                
                // Add hover effect
                button.addTarget(self, action: #selector(self.buttonTouchDown(_:)), for: .touchDown)
                button.addTarget(self, action: #selector(self.buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside])
                
                self.answerStackView.addArrangedSubview(button)
            }
            
            self.startTimer()
        }
    }
    
    private func startTimer() {
        timeLeft = 5
        hasAnswered = false
        updateTimerLabel()
        
        // Enable all buttons at the start of new question
        answerStackView.arrangedSubviews.forEach { view in
            if let button = view as? UIButton {
                button.isEnabled = true
                button.backgroundColor = .systemBlue.withAlphaComponent(0.1)
                button.layer.borderColor = UIColor.systemBlue.cgColor
            }
        }
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.timeLeft > 0 {
                self.timeLeft -= 1
                self.updateTimerLabel()
            }
            
            if self.timeLeft == 0 {
                self.timer?.invalidate()
                
                // If user has already answered, show the result
                if self.hasAnswered {
                    let isCorrect = self.correctAnswerButton?.backgroundColor == .systemGreen
                    self.showAnswerResult(isCorrect: isCorrect)
                } else {
                    // If user hasn't answered, handle time up
                    self.handleTimeUp()
                }
            }
        }
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
        guard let question = currentQuestion, !hasAnswered else { return }
        
        hasAnswered = true
        let selectedAnswer = sender.title(for: .normal) ?? ""
        let isCorrect = selectedAnswer == question.correctAnswer
        
        // Disable all buttons after first answer
        answerStackView.arrangedSubviews.forEach { view in
            if let button = view as? UIButton {
                button.isEnabled = false
            }
        }
        
        // Highlight selected answer with a different color
        sender.backgroundColor = .systemPurple.withAlphaComponent(0.3)
        sender.layer.borderColor = UIColor.systemPurple.cgColor
        
        // Store selected button and correct answer button
        for view in answerStackView.arrangedSubviews {
            if let button = view as? UIButton,
               button.title(for: .normal) == question.correctAnswer {
                correctAnswerButton = button
                break
            }
        }
        
        if isCorrect {
            // Update game score immediately
            multiplayerService.updateGameScore(gameId: game.id, points: 10) { error in
                if let error = error {
                    print("Error updating score: \(error.localizedDescription)")
                }
            }
        }
        
        // Wait for timer to finish (5 seconds) before showing result and moving to next question
        if timeLeft > 0 {
            // Let the timer continue running
            return
        } else {
            // If timer is already at 0, handle the result
            showAnswerResult(isCorrect: isCorrect)
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
        guard let question = currentQuestion else { return }
        
        // If user hasn't answered, mark it as answered now
        if !hasAnswered {
            hasAnswered = true
            
            // Disable all buttons
            answerStackView.arrangedSubviews.forEach { view in
                if let button = view as? UIButton {
                    button.isEnabled = false
                }
            }
        }
        
        showAnswerResult(isCorrect: false)
    }
    
    private func showAnswerResult(isCorrect: Bool) {
        // Show correct answer in green
        correctAnswerButton?.backgroundColor = .systemGreen
        correctAnswerButton?.layer.borderColor = UIColor.systemGreen.cgColor
        
        if isCorrect {
            // Animate score increase
            animateScoreIncrease()
        }
        
        // Move to next question after showing result
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            
            self.multiplayerService.moveToNextQuestion(gameId: self.game.id) { error in
                if let error = error {
                    print("Error moving to next question: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func animateScoreIncrease() {
        scoreAnimationView.isHidden = false
        scoreAnimationLabel.text = "+10"
        
        // Reset animation state
        scoreAnimationView.transform = .identity
        scoreAnimationView.alpha = 0
        
        // Animate
        UIView.animate(withDuration: 0.5, animations: {
            self.scoreAnimationView.alpha = 1
            self.scoreAnimationView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0.2, animations: {
                self.scoreAnimationView.alpha = 0
                self.scoreAnimationView.transform = CGAffineTransform(translationX: 0, y: -50)
            }) { _ in
                self.scoreAnimationView.isHidden = true
            }
        }
    }
    
    private func endGame() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Game Over",
                                        message: "The game has ended!",
                                        preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.navigationController?.popToRootViewController(animated: true)
            })
            self.present(alert, animated: true)
        }
    }
} 