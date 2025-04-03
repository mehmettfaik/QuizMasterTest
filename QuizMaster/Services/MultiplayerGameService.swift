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
        
        return db.collection("multiplayer_games")
            .whereField("invited_id", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: GameStatus.pending.rawValue)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents,
                      let latestInvite = documents.first,
                      let game = MultiplayerGame.from(latestInvite) else {
                    return
                }
                
                completion(.success(game))
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
        let gameData: [String: Any] = [
            "creator_id": currentUserId,
            "invited_id": invitedUserId,
            "status": GameStatus.pending.rawValue,
            "created_at": Timestamp(date: Date()),
            "current_question_index": 0,
            "player_scores": [
                currentUserId: ["score": 0, "correct_answers": 0, "wrong_answers": 0],
                invitedUserId: ["score": 0, "correct_answers": 0, "wrong_answers": 0]
            ]
        ]
        
        let gameRef = db.collection("multiplayer_games").document()
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
    
    func respondToGameInvitation(gameId: String, accept: Bool, completion: @escaping (Result<MultiplayerGame, Error>) -> Void) {
        let gameRef = db.collection("multiplayer_games").document(gameId)
        let status = accept ? GameStatus.accepted : GameStatus.rejected
        
        gameRef.updateData([
            "status": status.rawValue,
            "response_time": Timestamp(date: Date())
        ]) { error in
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
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to update game"])))
                }
            }
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
        let gameRef = db.collection("multiplayer_games").document(gameId)
        
        return gameRef.addSnapshotListener { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let game = document.flatMap(MultiplayerGame.from) {
                completion(.success(game))
            } else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse game data"])))
            }
        }
    }
} 