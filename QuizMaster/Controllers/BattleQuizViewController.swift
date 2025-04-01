import UIKit
import Combine
import FirebaseAuth
import FirebaseFirestore

class BattleQuizViewController: UIViewController {
    private var quiz: Quiz
    private var battle: QuizBattle?
    private let isChallenger: Bool
    private var currentQuestionIndex = 0
    private var selectedOptionIndex: Int?
    private var score = 0
    private var timer: Timer?
    private var timeLeft = 0
    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    
    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .primaryPurple
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let challengerLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let vsLabel: UILabel = {
        let label = UILabel()
        label.text = "VS"
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let opponentLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let scoreLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.progressTintColor = .white
        progress.trackTintColor = UIColor.white.withAlphaComponent(0.3)
        progress.layer.cornerRadius = 4
        progress.clipsToBounds = true
        progress.translatesAutoresizingMaskIntoConstraints = false
        return progress
    }()
    
    private let timerContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 30
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let timerLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .primaryPurple
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let questionContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 6
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let questionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let optionsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let waitingView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 20
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let waitingLabel: UILabel = {
        let label = UILabel()
        label.text = "Rakibiniz bekleniyor..."
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .primaryPurple
        label.textAlignment = .center
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
    
    init(quiz: Quiz, battle: QuizBattle?, isChallenger: Bool) {
        self.quiz = quiz
        self.battle = battle
        self.isChallenger = isChallenger
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupOptionsButtons()
        setupBattleInfo()
        setupBattleListener()
        startQuestion()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        listener?.remove()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        waitingView.addSubview(waitingLabel)
        waitingView.addSubview(loadingIndicator)
        
        view.addSubview(headerView)
        headerView.addSubview(challengerLabel)
        headerView.addSubview(vsLabel)
        headerView.addSubview(opponentLabel)
        headerView.addSubview(scoreLabel)
        headerView.addSubview(progressView)
        
        view.addSubview(timerContainer)
        timerContainer.addSubview(timerLabel)
        
        view.addSubview(questionContainer)
        questionContainer.addSubview(questionLabel)
        
        view.addSubview(optionsStackView)
        view.addSubview(waitingView)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 120),
            
            challengerLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            challengerLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            
            vsLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            vsLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            
            opponentLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            opponentLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            
            scoreLabel.topAnchor.constraint(equalTo: challengerLabel.bottomAnchor, constant: 8),
            scoreLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            
            progressView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            progressView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            progressView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16),
            progressView.heightAnchor.constraint(equalToConstant: 8),
            
            timerContainer.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -30),
            timerContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            timerContainer.widthAnchor.constraint(equalToConstant: 60),
            timerContainer.heightAnchor.constraint(equalToConstant: 60),
            
            timerLabel.centerXAnchor.constraint(equalTo: timerContainer.centerXAnchor),
            timerLabel.centerYAnchor.constraint(equalTo: timerContainer.centerYAnchor),
            
            questionContainer.topAnchor.constraint(equalTo: timerContainer.bottomAnchor, constant: 16),
            questionContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            questionContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            questionLabel.topAnchor.constraint(equalTo: questionContainer.topAnchor, constant: 24),
            questionLabel.leadingAnchor.constraint(equalTo: questionContainer.leadingAnchor, constant: 16),
            questionLabel.trailingAnchor.constraint(equalTo: questionContainer.trailingAnchor, constant: -16),
            questionLabel.bottomAnchor.constraint(equalTo: questionContainer.bottomAnchor, constant: -24),
            
            optionsStackView.topAnchor.constraint(equalTo: questionContainer.bottomAnchor, constant: 24),
            optionsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            optionsStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            optionsStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            
            waitingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            waitingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            waitingView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            waitingView.heightAnchor.constraint(equalToConstant: 200),
            
            waitingLabel.centerXAnchor.constraint(equalTo: waitingView.centerXAnchor),
            waitingLabel.topAnchor.constraint(equalTo: waitingView.topAnchor, constant: 40),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: waitingView.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: waitingLabel.bottomAnchor, constant: 24)
        ])
        
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeButtonTapped))
        navigationItem.leftBarButtonItem = closeButton
    }
    
    private func setupOptionsButtons() {
        for _ in 0..<4 {
            let button = UIButton(type: .system)
            button.backgroundColor = .systemGray6
            button.setTitleColor(.label, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 16)
            button.contentHorizontalAlignment = .left
            button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
            button.layer.cornerRadius = 10
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.systemGray4.cgColor
            
            optionsStackView.addArrangedSubview(button)
        }
    }
    
    private func setupBattleInfo() {
        guard let battle = battle else { return }
        
        challengerLabel.text = battle.challengerName
        opponentLabel.text = battle.opponentName
        updateScoreLabel()
    }
    
    private func setupBattleListener() {
        guard let battle = battle else { return }
        
        listener = FirebaseService.shared.listenForBattleStatus(battleId: battle.id) { [weak self] result in
            switch result {
            case .success(let updatedBattle):
                self?.battle = updatedBattle
                self?.updateScoreLabel()
                
                // Eğer rakip bağlandıysa ve ilk soru başlatılmışsa, bekletme ekranını kaldır
                if updatedBattle.currentQuestionIndex != nil {
                    self?.waitingView.isHidden = true
                    self?.loadingIndicator.stopAnimating()
                    
                    // Eğer güncel soru indexi bizimkinden farklıysa, güncelle
                    if let remoteIndex = updatedBattle.currentQuestionIndex, remoteIndex != self?.currentQuestionIndex {
                        self?.currentQuestionIndex = remoteIndex
                        self?.startQuestion()
                    }
                }
                
                // Eğer yarışma tamamlandıysa, sonuç ekranına git
                if updatedBattle.status == .completed {
                    self?.showResults()
                }
                
            case .failure:
                self?.dismiss(animated: true)
            }
        }
    }
    
    private func updateScoreLabel() {
        guard let battle = battle else { return }
        
        let challengerScore = battle.challengerScore ?? 0
        let opponentScore = battle.opponentScore ?? 0
        scoreLabel.text = "\(challengerScore) - \(opponentScore)"
    }
    
    private func startQuestion() {
        guard currentQuestionIndex < quiz.questions.count else {
            completeBattle()
            return
        }
        
        let question = quiz.questions[currentQuestionIndex]
        
        // Soruyu ve şıkları göster
        questionLabel.text = question.text
        
        for (index, button) in optionsStackView.arrangedSubviews.enumerated() {
            if let optionButton = button as? UIButton, index < question.options.count {
                optionButton.tag = index
                optionButton.setTitle(question.options[index], for: .normal)
                optionButton.isEnabled = true
                optionButton.backgroundColor = .systemGray6
                optionButton.addTarget(self, action: #selector(optionButtonTapped), for: .touchUpInside)
            }
        }
        
        // Progress bar'ı güncelle
        let progress = Float(currentQuestionIndex + 1) / Float(quiz.questions.count)
        progressView.setProgress(progress, animated: true)
        
        // Timer'ı başlat
        startTimer()
    }
    
    private func startTimer() {
        timeLeft = quiz.timePerQuestion
        updateTimerLabel()
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.timeLeft > 0 {
                self.timeLeft -= 1
                self.updateTimerLabel()
            } else {
                self.timeUp()
            }
        }
    }
    
    private func updateTimerLabel() {
        timerLabel.text = "\(timeLeft)"
        
        // Son 3 saniyede kırmızı göster
        if timeLeft <= 3 {
            timerLabel.textColor = .systemRed
        } else {
            timerLabel.textColor = .primaryPurple
        }
    }
    
    private func timeUp() {
        timer?.invalidate()
        
        // Doğru cevabı göster
        highlightCorrectAnswer()
        
        // Sonraki soruya geç
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.moveToNextQuestion()
        }
    }
    
    @objc private func optionButtonTapped(_ sender: UIButton) {
        timer?.invalidate()
        
        let selectedIndex = sender.tag
        selectedOptionIndex = selectedIndex
        
        let question = quiz.questions[currentQuestionIndex]
        let isCorrect = question.options[selectedIndex] == question.correctAnswer
        
        // Butonun rengini güncelle
        if isCorrect {
            sender.backgroundColor = .systemGreen
            score += quiz.pointsPerQuestion
            updateBattleScore()
        } else {
            sender.backgroundColor = .systemRed
        }
        
        // Tüm butonları devre dışı bırak
        for case let button as UIButton in optionsStackView.arrangedSubviews {
            button.isEnabled = false
        }
        
        // Doğru cevabı göster
        highlightCorrectAnswer()
        
        // Sonraki soruya geç
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.moveToNextQuestion()
        }
    }
    
    private func highlightCorrectAnswer() {
        let question = quiz.questions[currentQuestionIndex]
        
        for (index, option) in question.options.enumerated() {
            if option == question.correctAnswer {
                if let button = optionsStackView.arrangedSubviews[index] as? UIButton {
                    button.backgroundColor = .systemGreen
                    break
                }
            }
        }
    }
    
    private func moveToNextQuestion() {
        currentQuestionIndex += 1
        
        if isChallenger {
            advanceQuestion()
        } else if currentQuestionIndex >= quiz.questions.count {
            // Opponent ise son sorudan sonra completing'i yapalım
            completeBattle()
        } else {
            startQuestion()
        }
    }
    
    private func advanceQuestion() {
        guard let battle = battle else { return }
        
        if currentQuestionIndex >= quiz.questions.count {
            completeBattle()
            return
        }
        
        FirebaseService.shared.advanceQuestion(
            battleId: battle.id,
            newIndex: currentQuestionIndex
        ) { [weak self] result in
            switch result {
            case .success:
                self?.startQuestion()
            case .failure(let error):
                self?.showErrorAlert(error)
            }
        }
    }
    
    private func updateBattleScore() {
        guard let battle = battle else { return }
        
        FirebaseService.shared.updateBattleScore(
            battleId: battle.id,
            isChallenger: isChallenger,
            score: score
        ) { result in
            switch result {
            case .failure(let error):
                print("Score update error: \(error)")
            case .success:
                break
            }
        }
    }
    
    private func completeBattle() {
        guard let battle = battle, isChallenger else { return }
        
        FirebaseService.shared.completeBattle(battleId: battle.id) { [weak self] result in
            switch result {
            case .success:
                self?.showResults()
            case .failure(let error):
                self?.showErrorAlert(error)
            }
        }
    }
    
    private func showResults() {
        guard let battle = battle else { return }
        
        guard let challengerScore = battle.challengerScore,
              let opponentScore = battle.opponentScore else {
            return
        }
        
        let isWinner = isChallenger ? challengerScore > opponentScore : opponentScore > challengerScore
        
        // Kullanıcı istatistiklerini güncelle
        guard let currentUser = Auth.auth().currentUser else { return }
        
        FirebaseService.shared.updateUserBattleStats(userId: currentUser.uid, won: isWinner)
        
        // Sonuç ekranını göster
        let resultVC = BattleResultViewController(
            battle: battle,
            isChallenger: isChallenger,
            isWinner: isWinner
        )
        resultVC.modalPresentationStyle = .fullScreen
        
        present(resultVC, animated: true)
    }
    
    @objc private func closeButtonTapped() {
        let alert = UIAlertController(
            title: "Çıkış Yap",
            message: "Yarışmadan çıkmak istediğinize emin misiniz? Bu durumda yarışma rakibiniz lehine sonuçlanacaktır.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "İptal", style: .cancel))
        alert.addAction(UIAlertAction(title: "Çıkış Yap", style: .destructive) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        
        present(alert, animated: true)
    }
} 