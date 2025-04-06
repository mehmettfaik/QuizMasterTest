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
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()
    
    private let opponentScoreLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()
    
    private let vsLabel: UILabel = {
        let label = UILabel()
        label.text = "VS"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemGray
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
        scoreStackView.addArrangedSubview(vsLabel)
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
            scoreView.heightAnchor.constraint(equalToConstant: 100),
            
            scoreStackView.leadingAnchor.constraint(equalTo: scoreView.leadingAnchor, constant: 20),
            scoreStackView.trailingAnchor.constraint(equalTo: scoreView.trailingAnchor, constant: -20),
            scoreStackView.topAnchor.constraint(equalTo: scoreView.topAnchor, constant: 10),
            scoreStackView.bottomAnchor.constraint(equalTo: scoreView.bottomAnchor, constant: -10),
            
            vsLabel.widthAnchor.constraint(equalToConstant: 40),
            
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
        // Oyun verilerini güncelle
        if let currentUserId = Auth.auth().currentUser?.uid {
            // Puanları güncelle
            let currentPlayerScore = updatedGame.playerScores[currentUserId]?.score ?? 0
            let opponentId = updatedGame.creatorId == currentUserId ? updatedGame.invitedId : updatedGame.creatorId
            let opponentScore = updatedGame.playerScores[opponentId]?.score ?? 0
            
            DispatchQueue.main.async {
                self.updateScoreLabel(with: updatedGame)
            }
        }
        
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
    }
    
    private func updateScoreLabel(with updatedGame: MultiplayerGame? = nil) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let gameToUse = updatedGame ?? game
        
        // Mevcut oyuncunun bilgileri
        let currentPlayerScore = gameToUse.playerScores[currentUserId]?.score ?? 0
        let currentPlayerCorrect = gameToUse.playerScores[currentUserId]?.correctAnswers ?? 0
        
        // Rakip oyuncunun bilgileri
        let opponentId = gameToUse.creatorId == currentUserId ? gameToUse.invitedId : gameToUse.creatorId
        let opponentScore = gameToUse.playerScores[opponentId]?.score ?? 0
        let opponentCorrect = gameToUse.playerScores[opponentId]?.correctAnswers ?? 0
        
        // Kullanıcı isimlerini belirle
        let currentPlayerName = currentUserId == gameToUse.creatorId ? gameToUse.creatorName : gameToUse.invitedName
        let opponentName = currentUserId == gameToUse.creatorId ? gameToUse.invitedName : gameToUse.creatorName
        
        // Skor etiketlerini güncelle
        DispatchQueue.main.async {
            // Mevcut oyuncunun skoru
            let currentPlayerText = """
                \(currentPlayerName)
                \(currentPlayerScore) pts
                """
            self.yourScoreLabel.text = currentPlayerText
            self.yourScoreLabel.textColor = .label
            
            // Rakibin skoru
            let opponentText = """
                \(opponentName)
                \(opponentScore) pts
                """
            self.opponentScoreLabel.text = opponentText
            self.opponentScoreLabel.textColor = .secondaryLabel
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
        self.answerStackView.arrangedSubviews.forEach { ($0 as? UIButton)?.isEnabled = false }
        
        // Doğru cevabı göster
        showCorrectAnswer()
    }
    
    private func endGame() {
        // Timer'ları temizle
        timer?.invalidate()
        nextQuestionTimer?.invalidate()
        
        DispatchQueue.main.async {
            // Özel sonuç ekranı oluştur
            let resultVC = UIViewController()
            resultVC.view.backgroundColor = .systemBackground
            resultVC.modalPresentationStyle = .fullScreen
            
            // Başlık etiketi
            let titleLabel = UILabel()
            titleLabel.text = "Online Quiz Bitti"
            titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
            titleLabel.textAlignment = .center
            titleLabel.textColor = .label
            
            // Sonuç container view
            let resultContainer = UIView()
            resultContainer.backgroundColor = .secondarySystemBackground
            resultContainer.layer.cornerRadius = 16
            
            // Sonuç metni etiketi
            let resultLabel = UILabel()
            resultLabel.text = self.getGameResultMessage()
            resultLabel.numberOfLines = 0
            resultLabel.font = .systemFont(ofSize: 18)
            resultLabel.textColor = .label
            
            // Profile butonu
            let profileButton = UIButton(type: .system)
            profileButton.setTitle("Profili Görüntüle", for: .normal)
            profileButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
            profileButton.backgroundColor = .systemBlue
            profileButton.setTitleColor(.white, for: .normal)
            profileButton.layer.cornerRadius = 12
            profileButton.addTarget(self, action: #selector(self.goToProfile), for: .touchUpInside)
            
            // View'ları ekle
            [titleLabel, resultContainer, profileButton].forEach {
                $0.translatesAutoresizingMaskIntoConstraints = false
                resultVC.view.addSubview($0)
            }
            
            resultContainer.addSubview(resultLabel)
            resultLabel.translatesAutoresizingMaskIntoConstraints = false
            
            // Constraint'leri ayarla
            NSLayoutConstraint.activate([
                titleLabel.topAnchor.constraint(equalTo: resultVC.view.safeAreaLayoutGuide.topAnchor, constant: 40),
                titleLabel.leadingAnchor.constraint(equalTo: resultVC.view.leadingAnchor, constant: 20),
                titleLabel.trailingAnchor.constraint(equalTo: resultVC.view.trailingAnchor, constant: -20),
                
                resultContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
                resultContainer.leadingAnchor.constraint(equalTo: resultVC.view.leadingAnchor, constant: 20),
                resultContainer.trailingAnchor.constraint(equalTo: resultVC.view.trailingAnchor, constant: -20),
                
                resultLabel.topAnchor.constraint(equalTo: resultContainer.topAnchor, constant: 20),
                resultLabel.leadingAnchor.constraint(equalTo: resultContainer.leadingAnchor, constant: 20),
                resultLabel.trailingAnchor.constraint(equalTo: resultContainer.trailingAnchor, constant: -20),
                resultLabel.bottomAnchor.constraint(equalTo: resultContainer.bottomAnchor, constant: -20),
                
                profileButton.bottomAnchor.constraint(equalTo: resultVC.view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
                profileButton.leadingAnchor.constraint(equalTo: resultVC.view.leadingAnchor, constant: 40),
                profileButton.trailingAnchor.constraint(equalTo: resultVC.view.trailingAnchor, constant: -40),
                profileButton.heightAnchor.constraint(equalToConstant: 50)
            ])
            
            self.present(resultVC, animated: true)
        }
    }
    
    @objc private func goToProfile() {
        // Profil sayfasına yönlendir
        dismiss(animated: true) { [weak self] in
            self?.navigationController?.popToRootViewController(animated: true)
        }
    }
    
    private func getGameResultMessage() -> String {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return "" }
        
        // Mevcut oyuncunun bilgileri
        let currentPlayerName = currentUserId == game.creatorId ? game.creatorName : game.invitedName
        let currentPlayer = game.playerScores[currentUserId]
        let currentPlayerScore = currentPlayer?.score ?? 0
        let currentPlayerCorrect = currentPlayer?.correctAnswers ?? 0
        let currentPlayerWrong = currentPlayer?.wrongAnswers ?? 0
        
        // Rakip oyuncunun bilgileri
        let opponentId = game.creatorId == currentUserId ? game.invitedId : game.creatorId
        let opponentName = currentUserId == game.creatorId ? game.invitedName : game.creatorName
        let opponent = game.playerScores[opponentId]
        let opponentScore = opponent?.score ?? 0
        let opponentCorrect = opponent?.correctAnswers ?? 0
        let opponentWrong = opponent?.wrongAnswers ?? 0
        
        // Kazanan/Kaybeden durumunu belirle
        let resultStatus: String
        if currentPlayerScore > opponentScore {
            resultStatus = "🎉 Tebrikler! Kazandınız!"
        } else if currentPlayerScore < opponentScore {
            resultStatus = "😔 Maalesef kaybettiniz."
        } else {
            resultStatus = "🤝 Berabere kaldınız!"
        }
        
        // Sonuç mesajını oluştur
        let resultMessage = """
        \(resultStatus)
        
        \(currentPlayerName.uppercased())
        ▸ Puan: \(currentPlayerScore) pts
        ▸ Doğru: \(currentPlayerCorrect)
        ▸ Yanlış: \(currentPlayerWrong)
        
        \(opponentName.uppercased())
        ▸ Puan: \(opponentScore) pts
        ▸ Doğru: \(opponentCorrect)
        ▸ Yanlış: \(opponentWrong)
        """
        
        return resultMessage
    }
} 