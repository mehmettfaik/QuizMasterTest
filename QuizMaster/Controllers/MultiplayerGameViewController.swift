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
    
    private let resultLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.isHidden = true
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
    private var selectedAnswer: String?
    private var selectedButton: UIButton?
    
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
        
        [timerLabel, questionLabel, scoreLabel, resultLabel, answerStackView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            timerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            scoreLabel.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 20),
            scoreLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scoreLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            questionLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 40),
            questionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            questionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            resultLabel.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 20),
            resultLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            resultLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            answerStackView.topAnchor.constraint(equalTo: resultLabel.bottomAnchor, constant: 20),
            answerStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            answerStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
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
        
        hasAnswered = false
        selectedAnswer = nil
        selectedButton = nil
        resultLabel.isHidden = true
        
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
                button.backgroundColor = .systemBlue
                button.setTitleColor(.white, for: .normal)
                button.layer.cornerRadius = 8
                button.heightAnchor.constraint(equalToConstant: 44).isActive = true
                button.addTarget(self, action: #selector(self.answerButtonTapped(_:)), for: .touchUpInside)
                self.answerStackView.addArrangedSubview(button)
            }
            
            self.startTimer()
        }
    }
    
    private func startTimer() {
        timeLeft = 5
        updateTimerLabel()
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.timeLeft -= 1
            self.updateTimerLabel()
            
            if self.timeLeft <= 0 {
                self.timer?.invalidate()
                if !self.hasAnswered {
                    self.handleTimeUp()
                }
                self.showAnswerResult()
            }
        }
    }
    
    private func updateTimerLabel() {
        timerLabel.text = "Time: \(timeLeft)s"
    }
    
    private func updateScoreLabel() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let currentPlayerScore = game.playerScores[currentUserId]?.score ?? 0
        let opponentId = game.creatorId == currentUserId ? game.invitedId : game.creatorId
        let opponentScore = game.playerScores[opponentId]?.score ?? 0
        
        scoreLabel.text = "You: \(currentPlayerScore) - Opponent: \(opponentScore)"
    }
    
    @objc private func answerButtonTapped(_ button: UIButton) {
        guard let currentQuestion = currentQuestion,
              let answer = button.title(for: .normal),
              let currentUserId = Auth.auth().currentUser?.uid,
              !hasAnswered else { return }
        
        hasAnswered = true
        selectedAnswer = answer
        selectedButton = button
        
        // Sadece seçilen butonu devre dışı bırak ve rengini değiştir
        button.isEnabled = false
        button.backgroundColor = .systemGray
        
        let isCorrect = answer == currentQuestion.correctAnswer
        multiplayerService.submitAnswer(gameId: game.id, userId: currentUserId, isCorrect: isCorrect) { _ in }
    }
    
    private func handleTimeUp() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        hasAnswered = true
        multiplayerService.submitAnswer(gameId: game.id, userId: currentUserId, isCorrect: false) { _ in }
        
        // Tüm butonları devre dışı bırak
        answerStackView.arrangedSubviews.forEach { ($0 as? UIButton)?.isEnabled = false }
    }
    
    private func showAnswerResult() {
        guard let currentQuestion = currentQuestion else { return }
        
        // Tüm butonları devre dışı bırak
        answerStackView.arrangedSubviews.forEach { ($0 as? UIButton)?.isEnabled = false }
        
        // Önce tüm butonları normal renge çevir (seçili olan gri kalacak)
        answerStackView.arrangedSubviews.forEach { view in
            guard let button = view as? UIButton else { return }
            if button != selectedButton {
                button.backgroundColor = .systemBlue
            }
        }
        
        // Doğru cevabı ve kullanıcının yanlış cevabını göster
        answerStackView.arrangedSubviews.forEach { view in
            guard let button = view as? UIButton,
                  let buttonTitle = button.title(for: .normal) else { return }
            
            if buttonTitle == currentQuestion.correctAnswer {
                // Doğru cevabı yeşil yap
                button.backgroundColor = .systemGreen
            } else if buttonTitle == selectedAnswer && buttonTitle != currentQuestion.correctAnswer {
                // Kullanıcının yanlış cevabını kırmızı yap
                button.backgroundColor = .systemRed
            }
        }
        
        // Sonuç mesajını göster
        if let selectedAnswer = selectedAnswer {
            let isCorrect = selectedAnswer == currentQuestion.correctAnswer
            resultLabel.text = isCorrect ? "Correct! ✅" : "Wrong! ❌"
            resultLabel.textColor = isCorrect ? .systemGreen : .systemRed
        } else {
            resultLabel.text = "Time's up! ⏰"
            resultLabel.textColor = .systemRed
        }
        resultLabel.isHidden = false
        
        // 2 saniye sonra bir sonraki soruya geç
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            self.multiplayerService.moveToNextQuestion(gameId: self.game.id) { _ in }
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