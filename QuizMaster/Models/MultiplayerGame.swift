import Foundation
import FirebaseFirestore

enum GameStatus: String, Codable {
    case pending
    case accepted
    case rejected
    case inProgress
    case completed
    case cancelled
}

struct PlayerScore: Codable {
    var userId: String
    var score: Int
    var correctAnswers: Int
    var wrongAnswers: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case score
        case correctAnswers = "correct_answers"
        case wrongAnswers = "wrong_answers"
    }
}

struct MultiplayerGame: Codable {
    let id: String
    let createdAt: Date
    var status: GameStatus
    let creatorId: String
    let invitedId: String
    var category: String
    var difficulty: String
    var currentQuestionIndex: Int
    var playerScores: [String: PlayerScore]
    var questions: [String]  // Array of question IDs
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case status
        case creatorId = "creator_id"
        case invitedId = "invited_id"
        case category
        case difficulty
        case currentQuestionIndex = "current_question_index"
        case playerScores = "player_scores"
        case questions
    }
    
    static func from(_ document: DocumentSnapshot) -> MultiplayerGame? {
        guard let data = document.data() else { return nil }
        
        var playerScores: [String: PlayerScore] = [:]
        if let scores = data["player_scores"] as? [String: [String: Any]] {
            for (userId, scoreData) in scores {
                playerScores[userId] = PlayerScore(
                    userId: userId,
                    score: scoreData["score"] as? Int ?? 0,
                    correctAnswers: scoreData["correct_answers"] as? Int ?? 0,
                    wrongAnswers: scoreData["wrong_answers"] as? Int ?? 0
                )
            }
        }
        
        let timestamp = data["created_at"] as? Timestamp
        
        return MultiplayerGame(
            id: document.documentID,
            createdAt: timestamp?.dateValue() ?? Date(),
            status: GameStatus(rawValue: data["status"] as? String ?? "pending") ?? .pending,
            creatorId: data["creator_id"] as? String ?? "",
            invitedId: data["invited_id"] as? String ?? "",
            category: data["category"] as? String ?? "",
            difficulty: data["difficulty"] as? String ?? "",
            currentQuestionIndex: data["current_question_index"] as? Int ?? 0,
            playerScores: playerScores,
            questions: data["questions"] as? [String] ?? []
        )
    }
} 