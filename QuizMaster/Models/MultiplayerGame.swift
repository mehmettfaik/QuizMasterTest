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
    let creatorId: String
    let creatorName: String
    let invitedId: String
    let invitedName: String
    let status: GameStatus
    var currentQuestionIndex: Int
    var playerScores: [String: PlayerScore]
    let questions: [String]
    let category: String
    let difficulty: String?
    let createdAt: Date
    let responseTime: Date?
    let startTime: Date?
    var questionStartTime: Timestamp?
    
    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case creatorName = "creator_name"
        case invitedId = "invited_id"
        case invitedName = "invited_name"
        case status
        case currentQuestionIndex = "current_question_index"
        case playerScores = "player_scores"
        case questions
        case category
        case difficulty
        case createdAt = "created_at"
        case responseTime = "response_time"
        case startTime = "start_time"
        case questionStartTime = "question_start_time"
    }
    
    init(id: String, creatorId: String, creatorName: String, invitedId: String, invitedName: String, status: GameStatus, currentQuestionIndex: Int, playerScores: [String: PlayerScore], questions: [String], category: String, difficulty: String?, createdAt: Date, responseTime: Date?, startTime: Date?, questionStartTime: Timestamp?) {
        self.id = id
        self.creatorId = creatorId
        self.creatorName = creatorName
        self.invitedId = invitedId
        self.invitedName = invitedName
        self.status = status
        self.currentQuestionIndex = currentQuestionIndex
        self.playerScores = playerScores
        self.questions = questions
        self.category = category
        self.difficulty = difficulty
        self.createdAt = createdAt
        self.responseTime = responseTime
        self.startTime = startTime
        self.questionStartTime = questionStartTime
    }
    
    static func from(_ document: DocumentSnapshot) -> MultiplayerGame? {
        guard let data = document.data(),
              let id = data["id"] as? String,
              let creatorId = data["creator_id"] as? String,
              let invitedId = data["invited_id"] as? String,
              let currentQuestionIndex = data["current_question_index"] as? Int,
              let questions = data["questions"] as? [String],
              let category = data["category"] as? String,
              let statusRaw = data["status"] as? String,
              let status = GameStatus(rawValue: statusRaw) else {
            return nil
        }
        
        let creatorName = data["creator_name"] as? String ?? "Unknown"
        let invitedName = data["invited_name"] as? String ?? "Unknown"
        let difficulty = data["difficulty"] as? String
        let responseTime = (data["response_time"] as? Timestamp)?.dateValue()
        let startTime = (data["start_time"] as? Timestamp)?.dateValue()
        let questionStartTime = data["question_start_time"] as? Timestamp
        
        var playerScores: [String: PlayerScore] = [:]
        if let scoresData = data["player_scores"] as? [String: [String: Any]] {
            for (userId, scoreData) in scoresData {
                if let score = scoreData["score"] as? Int {
                    let lastAnswerTime = scoreData["last_answer_time"] as? Timestamp
                    playerScores[userId] = PlayerScore(
                        userId: userId,
                        score: score,
                        correctAnswers: 0,
                        wrongAnswers: 0
                    )
                }
            }
        }
        
        return MultiplayerGame(
            id: id,
            creatorId: creatorId,
            creatorName: creatorName,
            invitedId: invitedId,
            invitedName: invitedName,
            status: status,
            currentQuestionIndex: currentQuestionIndex,
            playerScores: playerScores,
            questions: questions,
            category: category,
            difficulty: difficulty,
            createdAt: Date(),
            responseTime: responseTime,
            startTime: startTime,
            questionStartTime: questionStartTime
        )
    }
} 