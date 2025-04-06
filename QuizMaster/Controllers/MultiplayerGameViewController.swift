import UIKit
import FirebaseAuth
import FirebaseFirestore

class MultiplayerGameViewController: UIViewController {
    private let game: MultiplayerGame
    private let multiplayerService = MultiplayerGameService.shared
    private var gameListener: ListenerRegistration?
    private var answerListener: ListenerRegistration?
    
    private var bothPlayersAnswered = false
    private var showingCorrectAnswer = false
    private var nextQuestionTimer: Timer?
    private var waitingForNextQuestion = false
    
    private var selectedButton: UIButton?
    
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
    
    private let scoreView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray4.cgColor
        return view
    }()
    
    private let yourScoreLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        return label
    }()
    
    private let opponentScoreLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let scoreStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 20
        return stack
    }()
    
    private let answerStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.spacing = 10
        return stack
    }()
    
    private var timer: Timer?
    private var timeLeft: Int = 5 // 5 seconds per question
    private var currentQuestion: Question?
    
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
        answerListener?.remove()
        timer?.invalidate()
        nextQuestionTimer?.invalidate()
    }
    
    private func setupUI() {
        title = "Multiplayer Quiz"
        view.backgroundColor = .systemBackground
        
        // Score view setup
        scoreView.addSubview(scoreStackView)
        scoreStackView.addArrangedSubview(yourScoreLabel)
        scoreStackView.addArrangedSubview(opponentScoreLabel)
        
        [timerLabel, scoreView, questionLabel, answerStackView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        scoreStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            timerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            scoreView.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 20),
            scoreView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scoreView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scoreView.heightAnchor.constraint(equalToConstant: 80),
            
            scoreStackView.leadingAnchor.constraint(equalTo: scoreView.leadingAnchor, constant: 16),
            scoreStackView.trailingAnchor.constraint(equalTo: scoreView.trailingAnchor, constant: -16),
            scoreStackView.topAnchor.constraint(equalTo: scoreView.topAnchor),
            scoreStackView.bottomAnchor.constraint(equalTo: scoreView.bottomAnchor),
            
            questionLabel.topAnchor.constraint(equalTo: scoreView.bottomAnchor, constant: 40),
            questionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            questionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            answerStackView.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 40),
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
        // Oyun tamamlandıysa sonuç ekranını göster
        if updatedGame.status == .completed {
            endGame()
            return
        }
        
        // Soru değiştiyse yeni soruyu yükle
        if updatedGame.currentQuestionIndex != game.currentQuestionIndex {
            // Timer'ları temizle
            timer?.invalidate()
            nextQuestionTimer?.invalidate()
            
            // Yeni soruyu yükle
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
        bothPlayersAnswered = false
        showingCorrectAnswer = false
        waitingForNextQuestion = false
        selectedButton = nil
        
        DispatchQueue.main.async {
            self.questionLabel.text = question.text
            self.answerStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            
            for option in question.options {
                let button = UIButton(type: .system)
                button.setTitle(option, for: .normal)
                button.backgroundColor = .systemBlue
                button.setTitleColor(.white, for: .normal)
                button.layer.cornerRadius = 8
                button.layer.borderWidth = 0
                button.heightAnchor.constraint(equalToConstant: 44).isActive = true
                button.addTarget(self, action: #selector(self.answerButtonTapped(_:)), for: .touchUpInside)
                self.answerStackView.addArrangedSubview(button)
            }
            
            self.startTimer()
            self.setupAnswerListener()
        }
    }
    
    private func setupAnswerListener() {
        answerListener?.remove()
        answerListener = multiplayerService.listenForAnswers(gameId: game.id) { [weak self] result in
            switch result {
            case .success(let answers):
                self?.checkIfBothPlayersAnswered(answers)
            case .failure(let error):
                print("Error listening for answers: \(error.localizedDescription)")
            }
        }
    }
    
    private func checkIfBothPlayersAnswered(_ answers: [String: Bool]) {
        guard !bothPlayersAnswered else { return }
        
        if answers.count == 2 {
            bothPlayersAnswered = true
            DispatchQueue.main.async {
                if !self.showingCorrectAnswer {
                    self.showCorrectAnswer()
                }
            }
        }
    }
    
    private func showCorrectAnswer() {
        guard let currentQuestion = currentQuestion,
              !showingCorrectAnswer else { return }
        
        showingCorrectAnswer = true
        
        // Timer'ı durdur
        timer?.invalidate()
        
        answerStackView.arrangedSubviews.forEach { view in
            guard let button = view as? UIButton,
                  let buttonTitle = button.title(for: .normal) else { return }
            
            // Seçili butonun vurgusunu kaldır
            button.layer.borderWidth = 0
            
            if buttonTitle == currentQuestion.correctAnswer {
                button.backgroundColor = .systemGreen
            } else {
                // Eğer bu buton seçilmişse ve yanlışsa, kırmızı yap
                if button == selectedButton {
                    button.backgroundColor = .systemRed
                } else {
                    button.backgroundColor = .systemGray
                }
            }
        }
        
        // 2 saniye sonra bir sonraki soruya geç
        nextQuestionTimer?.invalidate() // Önceki timer varsa temizle
        nextQuestionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.moveToNextQuestion()
        }
    }
    
    private func moveToNextQuestion() {
        guard !waitingForNextQuestion else { return }
        waitingForNextQuestion = true
        
        guard let currentUserId = Auth.auth().currentUser?.uid,
              game.creatorId == currentUserId else { return }
        
        // Eğer son soru ise oyunu bitir
        if let questions = game.questions,
           game.currentQuestionIndex >= questions.count - 1 {
            multiplayerService.updateGameStatus(gameId: game.id, status: .completed) { _ in }
        } else {
            multiplayerService.moveToNextQuestion(gameId: game.id) { _ in }
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
                self.handleTimeUp()
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
        
        yourScoreLabel.text = "You\n\(currentPlayerScore)"
        opponentScoreLabel.text = "Opponent\n\(opponentScore)"
    }
    
    private func animateScoreChange(for label: UILabel, from oldScore: Int, to newScore: Int) {
        // Skor değişim animasyonu
        let duration: TimeInterval = 1.0
        let steps = 10
        let stepDuration = duration / TimeInterval(steps)
        let scoreDifference = newScore - oldScore
        let stepValue = Double(scoreDifference) / Double(steps)
        
        // Label'ı büyüt
        UIView.animate(withDuration: 0.2, animations: {
            label.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            label.textColor = .systemGreen
        })
        
        // Skor artış animasyonu
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                let currentValue = oldScore + Int(Double(i) * stepValue)
                let text = label.text?.components(separatedBy: "\n").first ?? ""
                label.text = "\(text)\n\(currentValue)"
                
                // Son adımda label'ı normal boyutuna döndür
                if i == steps {
                    UIView.animate(withDuration: 0.2, animations: {
                        label.transform = .identity
                        label.textColor = .label
                    })
                }
            }
        }
    }
    
    @objc private func answerButtonTapped(_ button: UIButton) {
        guard let currentQuestion = currentQuestion,
              let answer = button.title(for: .normal),
              let currentUserId = Auth.auth().currentUser?.uid,
              !showingCorrectAnswer else { return }
        
        // Seçilen butonu vurgula
        highlightSelectedButton(button)
        
        let isCorrect = answer == currentQuestion.correctAnswer
        
        // Mevcut skoru kaydet
        let oldScore = game.playerScores[currentUserId]?.score ?? 0
        
        multiplayerService.submitAnswer(gameId: game.id, userId: currentUserId, isCorrect: isCorrect) { [weak self] _ in
            if isCorrect {
                // Doğru cevap durumunda skor animasyonunu göster
                DispatchQueue.main.async {
                    self?.animateScoreChange(for: self?.yourScoreLabel ?? UILabel(), from: oldScore, to: oldScore + 10)
                }
            }
        }
        
        // Disable all buttons after answering
        answerStackView.arrangedSubviews.forEach { ($0 as? UIButton)?.isEnabled = false }
        
        // Eğer her iki oyuncu da cevap verdiyse veya süre dolduysa doğru cevabı göster
        if bothPlayersAnswered || timeLeft <= 0 {
            showCorrectAnswer()
        }
    }
    
    private func highlightSelectedButton(_ button: UIButton) {
        // Önceki seçili butonu normale döndür
        selectedButton?.backgroundColor = .systemBlue
        selectedButton?.layer.borderWidth = 0
        
        // Yeni butonu vurgula
        button.backgroundColor = .systemIndigo
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.borderWidth = 2
        button.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        
        // Animasyonlu geçiş efekti
        UIView.animate(withDuration: 0.2, animations: {
            button.transform = .identity
        })
        
        selectedButton = button
    }
    
    private func handleTimeUp() {
        guard !showingCorrectAnswer else { return }
        
        // Süre dolduğunda henüz cevap verilmediyse otomatik olarak yanlış cevap gönder
        if let currentUserId = Auth.auth().currentUser?.uid {
            multiplayerService.submitAnswer(gameId: game.id, userId: currentUserId, isCorrect: false) { _ in }
        }
        
        // Seçili butonun vurgusunu kaldır
        selectedButton?.layer.borderWidth = 0
        selectedButton = nil
        
        // Tüm butonları devre dışı bırak
        answerStackView.arrangedSubviews.forEach { ($0 as? UIButton)?.isEnabled = false }
        
        // Doğru cevabı göster
        showCorrectAnswer()
    }
    
    private func endGame() {
        // Timer'ları temizle
        timer?.invalidate()
        nextQuestionTimer?.invalidate()
        
        DispatchQueue.main.async {
            // Özel tasarlanmış sonuç ekranını göster
            let resultVC = UIAlertController(title: "Game Over", message: "", preferredStyle: .alert)
            
            // Özel görünüm oluştur
            let resultView = UIView(frame: CGRect(x: 0, y: 0, width: 270, height: 200))
            
            let titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 270, height: 30))
            titleLabel.text = self.getGameResultTitle()
            titleLabel.textAlignment = .center
            titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
            
            let scoreStackView = UIStackView(frame: CGRect(x: 20, y: 40, width: 230, height: 140))
            scoreStackView.axis = .vertical
            scoreStackView.distribution = .fillEqually
            scoreStackView.spacing = 10
            
            let scores = self.getDetailedScores()
            scores.forEach { scoreText in
                let label = UILabel()
                label.text = scoreText
                label.textAlignment = .center
                label.numberOfLines = 0
                scoreStackView.addArrangedSubview(label)
            }
            
            resultView.addSubview(titleLabel)
            resultView.addSubview(scoreStackView)
            
            resultVC.setValue(resultView, forKey: "contentView")
            
            resultVC.addAction(UIAlertAction(title: "Return to Home", style: .default) { [weak self] _ in
                self?.navigationController?.popToRootViewController(animated: true)
            })
            
            self.present(resultVC, animated: true)
        }
    }
    
    private func getGameResultTitle() -> String {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return "Game Over!" }
        
        let currentPlayerScore = game.playerScores[currentUserId]?.score ?? 0
        let opponentId = game.creatorId == currentUserId ? game.invitedId : game.creatorId
        let opponentScore = game.playerScores[opponentId]?.score ?? 0
        
        if currentPlayerScore > opponentScore {
            return "You Won! 🎉"
        } else if currentPlayerScore < opponentScore {
            return "You Lost! 😔"
        } else {
            return "It's a Tie! 🤝"
        }
    }
    
    private func getDetailedScores() -> [String] {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return [] }
        
        let currentPlayer = game.playerScores[currentUserId]
        let opponentId = game.creatorId == currentUserId ? game.invitedId : game.creatorId
        let opponent = game.playerScores[opponentId]
        
        return [
            "Your Score: \(currentPlayer?.score ?? 0)\nCorrect: \(currentPlayer?.correctAnswers ?? 0)\nWrong: \(currentPlayer?.wrongAnswers ?? 0)",
            "Opponent Score: \(opponent?.score ?? 0)\nCorrect: \(opponent?.correctAnswers ?? 0)\nWrong: \(opponent?.wrongAnswers ?? 0)"
        ]
    }
} 