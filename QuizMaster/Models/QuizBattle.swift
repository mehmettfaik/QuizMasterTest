import Foundation
import FirebaseFirestore

enum BattleStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
    case completed = "completed"
    case ongoing = "ongoing"
}

struct QuizBattle: Codable {
    let id: String
    let challengerId: String
    let challengerName: String
    let opponentId: String
    let opponentName: String
    let category: String
    let difficulty: String
    let status: BattleStatus
    let createdAt: Date
    let quizId: String?
    let challengerScore: Int?
    let opponentScore: Int?
    let currentQuestionIndex: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case challengerId = "challenger_id"
        case challengerName = "challenger_name"
        case opponentId = "opponent_id"
        case opponentName = "opponent_name"
        case category
        case difficulty
        case status
        case createdAt = "created_at"
        case quizId = "quiz_id"
        case challengerScore = "challenger_score"
        case opponentScore = "opponent_score"
        case currentQuestionIndex = "current_question_index"
    }
    
    static func from(_ document: DocumentSnapshot) -> QuizBattle? {
        guard let data = document.data() else { return nil }
        
        let timestamp = data["created_at"] as? Timestamp ?? Timestamp(date: Date())
        
        return QuizBattle(
            id: document.documentID,
            challengerId: data["challenger_id"] as? String ?? "",
            challengerName: data["challenger_name"] as? String ?? "",
            opponentId: data["opponent_id"] as? String ?? "",
            opponentName: data["opponent_name"] as? String ?? "",
            category: data["category"] as? String ?? "",
            difficulty: data["difficulty"] as? String ?? "",
            status: BattleStatus(rawValue: data["status"] as? String ?? "pending") ?? .pending,
            createdAt: timestamp.dateValue(),
            quizId: data["quiz_id"] as? String,
            challengerScore: data["challenger_score"] as? Int,
            opponentScore: data["opponent_score"] as? Int,
            currentQuestionIndex: data["current_question_index"] as? Int
        )
    }
} 