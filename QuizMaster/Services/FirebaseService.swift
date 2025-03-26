import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import GoogleSignIn

class FirebaseService {
    static let shared = FirebaseService()
    private let auth = Auth.auth()
    fileprivate let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    private init() {}
    
    // MARK: - Authentication
    func signUp(email: String, password: String, name: String, completion: @escaping (Result<QuizMaster.User, Error>) -> Void) {
        auth.createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let userId = result?.user.uid else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User ID not found"])))
                return
            }
            
            let userData: [String: Any] = [
                "email": email,
                "name": name,
                "avatar": "wizard",
                "total_points": 0,
                "quizzes_played": 0,
                "quizzes_won": 0,
                "language": "tr",
                "category_stats": [:] as [String: Any],
                "isOnline": true,
                "lastSeen": Timestamp(date: Date())
            ]
            
            // UserDefaults'a kullanıcı bilgilerini kaydet
            UserDefaults.standard.set(userId, forKey: "userId")
            UserDefaults.standard.set(name, forKey: "userName")
            UserDefaults.standard.set("wizard", forKey: "userAvatar")
            UserDefaults.standard.synchronize()
            
            self?.db.collection("users").document(userId).setData(userData) { error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let user = QuizMaster.User(
                    id: userId,
                    email: email,
                    name: name,
                    avatar: "wizard",
                    totalPoints: 0,
                    quizzesPlayed: 0,
                    quizzesWon: 0,
                    language: "tr",
                    categoryStats: [:],
                    isOnline: true,
                    lastSeen: Date()
                )
                completion(.success(user))
            }
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Result<QuizMaster.User, Error>) -> Void) {
        auth.signIn(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let userId = result?.user.uid else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User ID not found"])))
                return
            }
            
            self?.db.collection("users").document(userId).updateData([
                "isOnline": true,
                "lastSeen": Timestamp(date: Date())
            ])
            
            self?.db.collection("users").document(userId).getDocument { [weak self] document, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                if let userData = document?.data() {
                    UserDefaults.standard.set(userId, forKey: "userId")
                    UserDefaults.standard.set(userData["name"] as? String ?? "", forKey: "userName")
                    UserDefaults.standard.set(userData["avatar"] as? String ?? "wizard", forKey: "userAvatar")
                    UserDefaults.standard.synchronize()
                }
                
                self?.getUser(userId: userId, completion: completion)
            }
        }
    }
    
    func signOut() throws {
        if let userId = Auth.auth().currentUser?.uid {
            self.db.collection("users").document(userId).updateData([
                "isOnline": false,
                "lastSeen": Timestamp(date: Date())
            ])
        }
        try auth.signOut()
    }
    
    func signInWithGoogle(presenting: UIViewController, completion: @escaping (Result<QuizMaster.User, Error>) -> Void) {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presenting) { [weak self] result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let authentication = result?.user,
                  let idToken = authentication.idToken?.tokenString else {
                let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google authentication failed"])
                completion(.failure(error))
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                         accessToken: authentication.accessToken.tokenString)
            
            self?.auth.signIn(with: credential) { [weak self] result, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let userId = result?.user.uid else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User ID not found"])))
                    return
                }
                
                self?.db.collection("users").document(userId).getDocument { [weak self] document, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    if let document = document, document.exists {
                        let userData = document.data() ?? [:]
                        UserDefaults.standard.set(userId, forKey: "userId")
                        UserDefaults.standard.set(userData["name"] as? String ?? authentication.profile?.name ?? "", forKey: "userName")
                        UserDefaults.standard.set(userData["avatar"] as? String ?? "wizard", forKey: "userAvatar")
                        UserDefaults.standard.synchronize()
                        
                        self?.db.collection("users").document(userId).updateData([
                            "isOnline": true,
                            "lastSeen": Timestamp(date: Date())
                        ])
                        self?.getUser(userId: userId, completion: completion)
                    } else {
                        let name = authentication.profile?.name ?? ""
                        let userData: [String: Any] = [
                            "email": authentication.profile?.email ?? "",
                            "name": name,
                            "avatar": "wizard",
                            "total_points": 0,
                            "quizzes_played": 0,
                            "quizzes_won": 0,
                            "language": "tr",
                            "category_stats": [:] as [String: Any],
                            "isOnline": true,
                            "lastSeen": Timestamp(date: Date())
                        ]
                        
                        UserDefaults.standard.set(userId, forKey: "userId")
                        UserDefaults.standard.set(name, forKey: "userName")
                        UserDefaults.standard.set("wizard", forKey: "userAvatar")
                        UserDefaults.standard.synchronize()
                        
                        self?.db.collection("users").document(userId).setData(userData) { error in
                            if let error = error {
                                completion(.failure(error))
                                return
                            }
                            
                            let user = QuizMaster.User(
                                id: userId,
                                email: authentication.profile?.email ?? "",
                                name: name,
                                avatar: "wizard",
                                totalPoints: 0,
                                quizzesPlayed: 0,
                                quizzesWon: 0,
                                language: "tr",
                                categoryStats: [:],
                                isOnline: true,
                                lastSeen: Date()
                            )
                            completion(.success(user))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - User Operations
    func getUser(userId: String, completion: @escaping (Result<QuizMaster.User, Error>) -> Void) {
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists == true, let user = QuizMaster.User.from(snapshot) else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found"])))
                return
            }
            
            completion(.success(user))
        }
    }
    
    // MARK: - Leaderboard
    func getLeaderboard(completion: @escaping (Result<[QuizMaster.User], Error>) -> Void) {
        db.collection("users")
            .order(by: "total_points", descending: true)
            .limit(to: 100)
            .getDocuments(source: .default) { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let users = documents.compactMap { QuizMaster.User.from($0) }
                completion(.success(users))
            }
    }
    
    // MARK: - Profile Image
    func uploadProfileImage(userId: String, imageData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        let storageRef = storage.reference().child("profile_images/\(userId).jpg")
        
        storageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let downloadURL = url else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                    return
                }
                
                self.db.collection("users").document(userId).updateData([
                    "photoURL": downloadURL.absoluteString
                ]) { error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    completion(.success(downloadURL.absoluteString))
                }
            }
        }
    }
}

// MARK: - Quiz Operations
extension FirebaseService {
    func getQuizzes(category: QuizCategory, difficulty: QuizDifficulty, completion: @escaping (Result<[Quiz], Error>) -> Void) {
        db.collection("quizzes")
            .whereField("category", isEqualTo: category.rawValue)
            .whereField("difficulty", isEqualTo: difficulty.rawValue)
            .getDocuments(source: .default) { [weak self] snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let quizzes = documents.compactMap { Quiz.from($0) }
                completion(.success(quizzes))
            }
    }
    
    func getQuizCategories(completion: @escaping (Result<[String], Error>) -> Void) {
        db.collection("quizzes")
            .getDocuments(source: .default) { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                // Benzersiz kategorileri al
                let categories = Array(Set(documents.compactMap { document in
                    document.data()["category"] as? String
                })).sorted()
                
                completion(.success(categories))
            }
    }
    
    func updateUserScore(userId: String, category: String, correctAnswers: Int, wrongAnswers: Int, points: Int) {
        let userRef = db.collection("users").document(userId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let userDocument: DocumentSnapshot
            do {
                try userDocument = transaction.getDocument(userRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let oldPlayed = userDocument.data()?["quizzes_played"] as? Int else {
                return nil
            }
            
            var categoryStats = userDocument.data()?["category_stats"] as? [String: [String: Any]] ?? [:]
            let currentStats = categoryStats[category] as? [String: Any] ?? [
                "correct_answers": 0,
                "wrong_answers": 0,
                "point": 0
            ]
            
            let updatedStats: [String: Any] = [
                "correct_answers": (currentStats["correct_answers"] as? Int ?? 0) + correctAnswers,
                "wrong_answers": (currentStats["wrong_answers"] as? Int ?? 0) + wrongAnswers,
                "point": (currentStats["point"] as? Int ?? 0) + points
            ]
            
            categoryStats[category] = updatedStats
            
            // Calculate total points from all categories
            var totalPoints = 0
            for (_, stats) in categoryStats {
                if let categoryPoints = stats["point"] as? Int {
                    totalPoints += categoryPoints
                }
            }
            
            transaction.updateData([
                "quizzes_played": oldPlayed + 1,
                "category_stats": categoryStats,
                "total_points": totalPoints
            ], forDocument: userRef)
            
            return nil
        }) { _, error in
            if let error = error {
                print("Error updating user score: \(error)")
            }
        }
    }
}

// MARK: - Friend Operations
extension FirebaseService {
    func sendFriendRequest(fromUserId: String, toUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let requestData: [String: Any] = [
            "fromUserId": fromUserId,
            "toUserId": toUserId,
            "status": "pending",
            "timestamp": Timestamp(date: Date())
        ]
        
        db.collection("friendRequests").addDocument(data: requestData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func getFriendRequests(forUserId userId: String, completion: @escaping (Result<[QueryDocumentSnapshot], Error>) -> Void) {
        db.collection("friendRequests")
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments(source: .default) { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                completion(.success(documents))
            }
    }
    
    func acceptFriendRequest(requestId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("friendRequests").document(requestId).updateData([
            "status": "accepted"
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func declineFriendRequest(requestId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("friendRequests").document(requestId).updateData([
            "status": "declined"
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func getFriends(forUserId userId: String, completion: @escaping (Result<[QuizMaster.User], Error>) -> Void) {
        // Get all accepted friend requests where the user is either sender or receiver
        let query1 = db.collection("friendRequests")
            .whereField("fromUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: "accepted")
        
        let query2 = db.collection("friendRequests")
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: "accepted")
        
        query1.getDocuments(source: .default) { [weak self] snapshot1, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            query2.getDocuments(source: .default) { snapshot2, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                var friendIds = Set<String>()
                
                // Extract friend IDs from requests where user is sender
                for document in snapshot1?.documents ?? [] {
                    if let toUserId = document.data()["toUserId"] as? String {
                        friendIds.insert(toUserId)
                    }
                }
                
                // Extract friend IDs from requests where user is receiver
                for document in snapshot2?.documents ?? [] {
                    if let fromUserId = document.data()["fromUserId"] as? String {
                        friendIds.insert(fromUserId)
                    }
                }
                
                // If no friends, return empty array
                if friendIds.isEmpty {
                    completion(.success([]))
                    return
                }
                
                // Get user data for all friends
                let group = DispatchGroup()
                var friends: [QuizMaster.User] = []
                var firstError: Error?
                
                for friendId in friendIds {
                    group.enter()
                    self?.getUser(userId: friendId) { result in
                        switch result {
                        case .success(let user):
                            friends.append(user)
                        case .failure(let error):
                            if firstError == nil {
                                firstError = error
                            }
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    if let error = firstError {
                        completion(.failure(error))
                    } else {
                        completion(.success(friends))
                    }
                }
            }
        }
    }
}

// MARK: - Battle Invitations
extension FirebaseService {
    func sendBattleInvitation(fromUserId: String, toUserId: String, battleId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let invitationData: [String: Any] = [
            "fromUserId": fromUserId,
            "toUserId": toUserId,
            "battleId": battleId,
            "status": "pending",
            "timestamp": Timestamp(date: Date())
        ]
        
        db.collection("battleInvitations").addDocument(data: invitationData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func getBattleInvitations(forUserId userId: String, completion: @escaping (Result<[QueryDocumentSnapshot], Error>) -> Void) {
        db.collection("battleInvitations")
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments(source: .default) { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                completion(.success(documents))
            }
    }
    
    func acceptBattleInvitation(invitationId: String, completion: @escaping (Result<String, Error>) -> Void) {
        db.collection("battleInvitations").document(invitationId).getDocument { [weak self] snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data(),
                  let battleId = data["battleId"] as? String else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Battle invitation invalid"])))
                return
            }
            
            self?.db.collection("battleInvitations").document(invitationId).updateData([
                "status": "accepted"
            ]) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(battleId))
                }
            }
        }
    }
    
    func declineBattleInvitation(invitationId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("battleInvitations").document(invitationId).updateData([
            "status": "declined"
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}

// MARK: - Online Battle Management
extension FirebaseService {
    func getOnlineUsers(excludeUserId: String, completion: @escaping (Result<[QuizMaster.User], Error>) -> Void) {
        // Get users who are online (last seen within the last 5 minutes)
        let fiveMinutesAgo = Date().addingTimeInterval(-300) // 5 minutes ago
        
        db.collection("users")
            .whereField("isOnline", isEqualTo: true)
            .getDocuments(source: .default) { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                // Filter users who are truly online (last seen within 5 minutes)
                let onlineUsers = documents.compactMap { document -> QuizMaster.User? in
                    // Skip the current user
                    if document.documentID == excludeUserId {
                        return nil
                    }
                    
                    // Check last seen timestamp
                    guard let lastSeen = document.data()["lastSeen"] as? Timestamp,
                          lastSeen.dateValue() > fiveMinutesAgo else {
                        return nil
                    }
                    
                    return QuizMaster.User.from(document)
                }
                
                completion(.success(onlineUsers))
            }
    }
    
    func createBattle(createdBy: String, category: String, difficulty: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Get questions for the selected category and difficulty
        db.collection("quizzes")
            .whereField("category", isEqualTo: category)
            .whereField("difficulty", isEqualTo: difficulty)
            .getDocuments(source: .default) { [weak self] snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let questions = snapshot?.documents.compactMap { $0.data() } ?? []
                
                if questions.isEmpty {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No questions found for the selected category and difficulty"])))
                    return
                }
                
                // Create a new battle document
                let battleData: [String: Any] = [
                    "createdBy": createdBy,
                    "status": "waiting",
                    "createdAt": Timestamp(date: Date()),
                    "category": category,
                    "difficulty": difficulty,
                    "players": [createdBy],
                    "questions": questions,
                    "currentQuestion": 0,
                    "scores": [createdBy: 0]
                ]
                
                let battleRef = self?.db.collection("battles").document()
                guard let battleId = battleRef?.documentID else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create battle document"])))
                    return
                }
                
                battleRef?.setData(battleData) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(battleId))
                    }
                }
            }
    }
    
    func observeBattle(battleId: String, completion: @escaping (Result<[String: Any], Error>) -> Void) -> ListenerRegistration {
        return db.collection("battles").document(battleId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = snapshot?.data() else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Battle not found"])))
                    return
                }
                
                completion(.success(data))
            }
    }
} 
