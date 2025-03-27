import UIKit
import FirebaseFirestore

class BattleQuestionViewController: UIViewController {
    private let category: String
    private let opponentId: String?
    private let firebaseService = FirebaseService.shared
    private var currentQuestionIndex = 0
    private var timer: Timer?
    private var secondsRemaining = 5
    private var score = 0
    
    // UI Elements
    private let questionLabel = UILabel()
    private let timerLabel = UILabel()
    private let answerButtons = [UIButton(), UIButton(), UIButton(), UIButton()]
    private let scoreLabel = UILabel()
    
    init(category: String, opponentId: String?) {
        self.category = category
        self.opponentId = opponentId
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Battle Quiz"
        setupUI()
        startBattle()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
    }
    
    private func setupUI() {
        // Question Label
        questionLabel.text = "Loading question..."
        questionLabel.textAlignment = .center
        questionLabel.numberOfLines = 0
        questionLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        questionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(questionLabel)
        
        // Timer Label
        timerLabel.text = "5"
        timerLabel.textAlignment = .center
        timerLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(timerLabel)
        
        // Score Label
        scoreLabel.text = "Score: 0"
        scoreLabel.textAlignment = .right
        scoreLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scoreLabel)
        
        // Answer Buttons
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        for (index, button) in answerButtons.enumerated() {
            button.setTitle("Answer \(index + 1)", for: .normal)
            button.backgroundColor = .systemBlue
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 8
            button.tag = index
            button.addTarget(self, action: #selector(answerButtonTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
        
        NSLayoutConstraint.activate([
            timerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            scoreLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            scoreLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            questionLabel.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 40),
            questionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            questionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            stackView.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 40),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    private func startBattle() {
        // In a real implementation, we would fetch questions from Firestore
        // For now, we'll simulate with a mock question
        loadQuestion()
        startTimer()
    }
    
    private func loadQuestion() {
        // Mock question data - in a real app, this would come from Firestore
        let questionText = "What is the capital of France?"
        let options = ["London", "Berlin", "Paris", "Madrid"]
        
        questionLabel.text = questionText
        
        for (index, button) in answerButtons.enumerated() {
            button.setTitle(options[index], for: .normal)
        }
        
        // Reset timer
        secondsRemaining = 5
        timerLabel.text = "\(secondsRemaining)"
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
    }
    
    @objc private func updateTimer() {
        secondsRemaining -= 1
        timerLabel.text = "\(secondsRemaining)"
        
        if secondsRemaining <= 0 {
            timer?.invalidate()
            
            // Time's up - move to next question or end battle
            let alert = UIAlertController(title: "Time's Up!", message: "The correct answer was Paris", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Next Question", style: .default) { [weak self] _ in
                self?.currentQuestionIndex += 1
                if self?.currentQuestionIndex ?? 0 < 5 { // Assuming 5 questions per battle
                    self?.loadQuestion()
                    self?.startTimer()
                } else {
                    self?.endBattle()
                }
            })
            present(alert, animated: true)
        }
    }
    
    @objc private func answerButtonTapped(_ sender: UIButton) {
        timer?.invalidate()
        
        // Check if the answer is correct (in this mock, "Paris" is at index 2)
        let isCorrect = sender.tag == 2
        
        if isCorrect {
            score += 100 + (secondsRemaining * 20) // More points for faster answers
            scoreLabel.text = "Score: \(score)"
            
            // Update the battle document in Firestore with the new score
            // This would be implemented in a real app
        }
        
        // Show result and move to next question
        let alert = UIAlertController(
            title: isCorrect ? "Correct!" : "Wrong!",
            message: "The correct answer was Paris",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Next Question", style: .default) { [weak self] _ in
            self?.currentQuestionIndex += 1
            if self?.currentQuestionIndex ?? 0 < 5 { // Assuming 5 questions per battle
                self?.loadQuestion()
                self?.startTimer()
            } else {
                self?.endBattle()
            }
        })
        present(alert, animated: true)
    }
    
    private func endBattle() {
        let alert = UIAlertController(
            title: "Battle Ended",
            message: "Your final score: \(score)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Return to Profile", style: .default) { [weak self] _ in
            self?.navigationController?.popToRootViewController(animated: true)
        })
        present(alert, animated: true)
    }
}
