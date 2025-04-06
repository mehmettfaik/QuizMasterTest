import Foundation
import FirebaseFirestore
import FirebaseAuth

class MultiplayerGameService {
    private let db = Firestore.firestore()
    static let shared = MultiplayerGameService()
    
    private init() {}
    
    // MARK: - Online Status Management
    
    func updateOnlineStatus(userId: String, isOnline: Bool) {
        let userRef = db.collection("users").document(userId)
        userRef.updateData([
            "is_online": isOnline,
            "last_online": Timestamp(date: Date())
        ])
    }
    
    func getOnlineUsers(completion: @escaping ([User]) -> Void) -> ListenerRegistration {
        return db.collection("users")
            .whereField("is_online", isEqualTo: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let users = documents.compactMap { User.from($0) }
                completion(users)
            }
    }
    
    // MARK: - Game Invitation Management
    
    func listenForGameInvitations(completion: @escaping (Result<MultiplayerGame, Error>) -> Void) -> ListenerRegistration {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return db.collection("dummy").addSnapshotListener { _, _ in }
        }
        
        // Use a simpler query that doesn't require a composite index
        return db.collection("multiplayer_games")
            .whereField("invited_id", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: GameStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Error in game invitations listener: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                // Handle document changes and sort in memory
                let games = snapshot.documents.compactMap { MultiplayerGame.from($0) }
                    .sorted { $0.createdAt > $1.createdAt } // Sort by created_at in descending order
                
                // Process each game invitation
                games.forEach { game in
                    completion(.success(game))
                }
            }
    }
    
    func sendGameInvitation(to userId: String, completion: @escaping (Result<MultiplayerGame, Error>) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }
        
        // First, check if there's already a pending invitation
        db.collection("multiplayer_games")
            .whereField("creator_id", isEqualTo: currentUserId)
            .whereField("invited_id", isEqualTo: userId)
            .whereField("status", isEqualTo: GameStatus.pending.rawValue)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                // If there's already a pending invitation, return it
                if let existingGame = snapshot?.documents.first.flatMap(MultiplayerGame.from) {
                    completion(.success(existingGame))
                    return
                }
                
                // If no pending invitation exists, create a new one
                self?.createNewGameInvitation(currentUserId: currentUserId, invitedUserId: userId, completion: completion)
            }
    }
    
    private func createNewGameInvitation(currentUserId: String, invitedUserId: String, completion: @escaping (Result<MultiplayerGame, Error>) -> Void) {
        // Get user names for better identification
        let batch = db.batch()
        let gameRef = db.collection("multiplayer_games").document()
        
        // Get creator's name
        db.collection("users").document(currentUserId).getDocument { [weak self] creatorDoc, error in
            guard let self = self else { return }
            
            let creatorName = creatorDoc?.data()?["username"] as? String ?? "Unknown"
            
            // Get invited user's name
            self.db.collection("users").document(invitedUserId).getDocument { invitedDoc, error in
                let invitedName = invitedDoc?.data()?["username"] as? String ?? "Unknown"
                
                let gameData: [String: Any] = [
                    "creator_id": currentUserId,
                    "creator_name": creatorName,
                    "invited_id": invitedUserId,
                    "invited_name": invitedName,
                    "status": GameStatus.pending.rawValue,
                    "created_at": Timestamp(date: Date()),
                    "current_question_index": 0,
                    "player_scores": [
                        currentUserId: ["score": 0, "correct_answers": 0, "wrong_answers": 0],
                        invitedUserId: ["score": 0, "correct_answers": 0, "wrong_answers": 0]
                    ]
                ]
                
                gameRef.setData(gameData) { error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    gameRef.getDocument { document, error in
                        if let error = error {
                            completion(.failure(error))
                            return
                        }
                        
                        if let game = document.flatMap(MultiplayerGame.from) {
                            completion(.success(game))
                        } else {
                            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create game"])))
                        }
                    }
                }
            }
        }
    }
    
    func respondToGameInvitation(gameId: String, accept: Bool, completion: @escaping (Result<MultiplayerGame, Error>) -> Void) {
        let status = accept ? GameStatus.accepted : GameStatus.rejected
        
        updateGameStatus(gameId: gameId, status: status) { [weak self] result in
            switch result {
            case .success:
                // Get the updated game data
                self?.db.collection("multiplayer_games").document(gameId).getDocument { document, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    if let game = document.flatMap(MultiplayerGame.from) {
                        // If accepted, notify the creator
                        if accept {
                            self?.notifyGameAccepted(game: game)
                        }
                        completion(.success(game))
                    } else {
                        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to update game"])))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func updateGameStatus(gameId: String, status: GameStatus, completion: @escaping (Result<Void, Error>) -> Void) {
        let gameRef = db.collection("multiplayer_games").document(gameId)
        
        var updateData: [String: Any] = [
            "status": status.rawValue,
            "last_updated": Timestamp(date: Date())
        ]
        
        if status == .accepted {
            updateData["response_time"] = Timestamp(date: Date())
        } else if status == .inProgress {
            updateData["start_time"] = Timestamp(date: Date())
        }
        
        gameRef.updateData(updateData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    private func notifyGameAccepted(game: MultiplayerGame) {
        // Add notification for the creator
        let notificationData: [String: Any] = [
            "type": "game_accepted",
            "game_id": game.id,
            "from_user_id": game.invitedId,
            "from_user_name": game.invitedName,
            "created_at": Timestamp(date: Date()),
            "is_read": false
        ]
        
        db.collection("users").document(game.creatorId)
            .collection("notifications").addDocument(data: notificationData)
    }
    
    func checkPendingInvitations(userId: String, completion: @escaping (Bool) -> Void) {
        db.collection("multiplayer_games")
            .whereField("invited_id", isEqualTo: userId)
            .whereField("status", isEqualTo: GameStatus.pending.rawValue)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error checking pending invitations: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                completion(!(snapshot?.documents.isEmpty ?? true))
            }
    }
    
    // MARK: - Game Setup and Management
    
    func getQuizCategories(completion: @escaping (Result<[QuizCategory], Error>) -> Void) -> ListenerRegistration {
        // Return all available categories from QuizCategory enum
        let categories = QuizCategory.allCases.sorted { $0.rawValue < $1.rawValue }
        completion(.success(categories))
        
        // Return a dummy listener since we don't need real-time updates for static categories
        return db.collection("dummy").addSnapshotListener { _, _ in }
    }
    
    func setupGame(gameId: String, category: String, difficulty: String, completion: @escaping (Result<MultiplayerGame, Error>) -> Void) {
        // First check if the game is accepted
        let gameRef = db.collection("multiplayer_games").document(gameId)
        
        gameRef.getDocument { [weak self] document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let game = document.flatMap(MultiplayerGame.from) else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Game not found"])))
                return
            }
            
            // Only proceed if the game is accepted
            guard game.status == .accepted else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Game must be accepted by both players before starting"])))
                return
            }
            
            // Convert category string to lowercase for Firestore path
            let categoryPath = category.lowercased().replacingOccurrences(of: " ", with: "")
            
            print("📝 Loading questions for:")
            print("   Category: \(category)")
            print("   Category Path: \(categoryPath)")
            print("   Difficulty: \(difficulty)")
            print("   Full Path: aaaa/\(categoryPath)/questions")
            
            // Fetch questions for the selected category
            self?.db.collection("aaaa").document(categoryPath).collection("questions")
                .whereField("difficulty", isEqualTo: difficulty)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("❌ Error loading questions: \(error.localizedDescription)")
                        completion(.failure(error))
                        return
                    }
                    
                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        print("❌ No questions found for category: \(category) and difficulty: \(difficulty)")
                        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No questions found"])))
                        return
                    }
                    
                    print("✅ Found \(documents.count) questions")
                    
                    // Randomly select 5 questions
                    let shuffledDocs = documents.shuffled()
                    let selectedQuestions = Array(shuffledDocs.prefix(5))
                    let questionIds = selectedQuestions.map { "\(categoryPath)/questions/\($0.documentID)" }
                    
                    // Update game with questions
                    gameRef.updateData([
                        "category": category,
                        "difficulty": difficulty,
                        "questions": questionIds,
                        "status": GameStatus.inProgress.rawValue,
                        "start_time": Timestamp(date: Date())
                    ]) { error in
                        if let error = error {
                            print("❌ Error updating game: \(error.localizedDescription)")
                            completion(.failure(error))
                            return
                        }
                        
                        gameRef.getDocument { document, error in
                            if let error = error {
                                print("❌ Error getting updated game: \(error.localizedDescription)")
                                completion(.failure(error))
                                return
                            }
                            
                            if let game = document.flatMap(MultiplayerGame.from) {
                                print("✅ Game setup successful")
                                completion(.success(game))
                            } else {
                                print("❌ Failed to parse game data")
                                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to setup game"])))
                            }
                        }
                    }
                }
        }
    }
    
    func getQuestion(questionId: String, completion: @escaping (Result<Question, Error>) -> Void) {
        // questionId format: "category/questions/questionId"
        let components = questionId.components(separatedBy: "/")
        guard components.count == 3 else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid question ID format"])))
            return
        }
        
        let category = components[0]
        let questionDocId = components[2]
        
        print("📝 Loading question:")
        print("   Category: \(category)")
        print("   Question ID: \(questionDocId)")
        print("   Full Path: aaaa/\(category)/questions/\(questionDocId)")
        
        db.collection("aaaa").document(category).collection("questions").document(questionDocId)
            .getDocument { snapshot, error in
                if let error = error {
                    print("❌ Error loading question: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let data = snapshot?.data() else {
                    print("❌ No question data found")
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Question not found"])))
                    return
                }
                
                guard let questionText = data["question"] as? String,
                      let correctAnswer = data["correct_answer"] as? String,
                      let options = data["options"] as? [String] else {
                    print("❌ Invalid question data:", data)
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid question data"])))
                    return
                }
                
                let questionImage = data["question_image"] as? String
                let optionImages = data["option_images"] as? [String]
                
                print("✅ Successfully loaded question:")
                print("   Question:", questionText)
                print("   Options:", options)
                print("   Correct Answer:", correctAnswer)
                print("   Question Image:", questionImage ?? "None")
                print("   Option Images:", optionImages ?? "None")
                
                let question = Question(
                    text: questionText,
                    options: options,
                    correctAnswer: correctAnswer,
                    questionImage: questionImage,
                    optionImages: optionImages
                )
                
                completion(.success(question))
            }
    }
    
    func submitAnswer(gameId: String, userId: String, isCorrect: Bool, completion: @escaping (Result<MultiplayerGame, Error>) -> Void) {
        let gameRef = db.collection("multiplayer_games").document(gameId)
        
        gameRef.getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let game = document.flatMap(MultiplayerGame.from) else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Game not found"])))
                return
            }
            
            var playerScore = game.playerScores[userId] ?? PlayerScore(userId: userId, score: 0, correctAnswers: 0, wrongAnswers: 0)
            
            if isCorrect {
                playerScore.score += 10
                playerScore.correctAnswers += 1
            } else {
                playerScore.wrongAnswers += 1
            }
            
            let updateData: [String: Any] = [
                "player_scores.\(userId)": [
                    "score": playerScore.score,
                    "correct_answers": playerScore.correctAnswers,
                    "wrong_answers": playerScore.wrongAnswers
                ],
                "current_question_index": game.currentQuestionIndex + 1
            ]
            
            gameRef.updateData(updateData) { error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                gameRef.getDocument { document, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    if let updatedGame = document.flatMap(MultiplayerGame.from) {
                        completion(.success(updatedGame))
                    } else {
                        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to update game"])))
                    }
                }
            }
        }
    }
    
    func listenForGameUpdates(gameId: String, completion: @escaping (Result<MultiplayerGame, Error>) -> Void) -> ListenerRegistration {
        return db.collection("multiplayer_games").document(gameId)
            .addSnapshotListener { documentSnapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let document = documentSnapshot else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Document does not exist"])))
                    return
                }
                
                if let game = MultiplayerGame.from(document) {
                    completion(.success(game))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse game data"])))
                }
            }
    }
    
    // Add retry mechanism for Firestore operations
    private func retryOperation<T>(
        maxAttempts: Int = 3,
        operation: @escaping (@escaping (Result<T, Error>) -> Void) -> Void,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        func attempt(remaining: Int) {
            operation { result in
                switch result {
                case .success(let value):
                    completion(.success(value))
                case .failure(let error):
                    if remaining > 1 && (error.localizedDescription.contains("BloomFilter") || error.localizedDescription.contains("requires an index")) {
                        // Wait briefly before retrying
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                            attempt(remaining: remaining - 1)
                        }
                    } else {
                        completion(.failure(error))
                    }
                }
            }
        }
        
        attempt(remaining: maxAttempts)
    }
    
    func moveToNextQuestion(gameId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let gameRef = db.collection("multiplayer_games").document(gameId)
        
        // Get the current game data
        gameRef.getDocument { [weak self] document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let game = document.flatMap(MultiplayerGame.from) else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get game data"])))
                return
            }
            
            // Calculate next question index
            let nextIndex = (game.currentQuestionIndex ?? 0) + 1
            
            // Update the game with the next question index
            gameRef.updateData([
                "current_question_index": nextIndex,
                "last_updated": Timestamp(date: Date())
            ]) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
} 