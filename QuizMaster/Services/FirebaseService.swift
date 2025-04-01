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
                    categoryStats: [:]
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
            
            self?.db.collection("users").document(userId).getDocument { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                if let userData = snapshot?.data() {
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
                                categoryStats: [:]
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
            .getDocuments { snapshot, error in
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
        // Path: aaaa/{category}/questions
        db.collection("aaaa").document(category.rawValue).collection("questions")
            .whereField("difficulty", isEqualTo: difficulty.rawValue)
            .getDocuments(source: .default) { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let questions = documents.compactMap { document -> Question? in
                    guard let question = document.data()["question"] as? String,
                          let correctAnswer = document.data()["correct_answer"] as? String,
                          let options = document.data()["options"] as? [String: String] else {
                        return nil
                    }
                    
                    // Convert options dictionary to array
                    let sortedOptions = options.sorted { $0.key < $1.key }.map { $0.value }
                    
                    return Question(
                        text: question,
                        options: sortedOptions,
                        correctAnswer: correctAnswer,
                        questionImage: nil,
                        optionImages: nil
                    )
                }
                
                // Create a single Quiz object with all questions
                let quiz = Quiz(
                    id: UUID().uuidString,
                    category: category,
                    difficulty: difficulty,
                    questions: questions,
                    timePerQuestion: 30,  // Default values
                    pointsPerQuestion: 10  // Default values
                )
                
                completion(.success([quiz]))
            }
    }
    
    func getQuizCategories(completion: @escaping (Result<[String], Error>) -> Void) {
        db.collection("aaaa")
            .getDocuments { snapshot, error in
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

// MARK: - Online and Challenge Features
extension FirebaseService {
    func updateUserOnlineStatus(isOnline: Bool) {
        guard let userId = auth.currentUser?.uid else { return }
        
        let userRef = db.collection("users").document(userId)
        userRef.updateData([
            "isOnline": isOnline,
            "lastSeen": FieldValue.serverTimestamp()
        ])
    }
    
    func listenForOnlineUsers(completion: @escaping ([User]) -> Void) -> ListenerRegistration {
        guard let currentUserId = auth.currentUser?.uid else {
            completion([])
            return db.collection("users").document("dummy").addSnapshotListener { _, _ in }
        }
        
        return db.collection("users")
            .whereField("isOnline", isEqualTo: true)
            .whereField(FieldPath.documentID(), isNotEqualTo: currentUserId)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                var users: [User] = []
                for document in documents {
                    if let id = document.documentID as String?,
                       let name = document.data()["name"] as? String,
                       let avatar = document.data()["avatar"] as? String,
                       let email = document.data()["email"] as? String {
                        
                        let totalPoints = document.data()["total_points"] as? Int ?? 0
                        let quizzesPlayed = document.data()["quizzes_played"] as? Int ?? 0
                        let quizzesWon = document.data()["quizzes_won"] as? Int ?? 0
                        let language = document.data()["language"] as? String ?? "tr"
                        
                        var categoryStats: [String: CategoryStats] = [:]
                        if let stats = document.data()["category_stats"] as? [String: [String: Any]] {
                            for (category, statData) in stats {
                                categoryStats[category] = CategoryStats(
                                    correctAnswers: statData["correct_answers"] as? Int ?? 0,
                                    wrongAnswers: statData["wrong_answers"] as? Int ?? 0,
                                    point: statData["point"] as? Int ?? 0
                                )
                            }
                        }
                        
                        let user = User(
                            id: id,
                            email: email,
                            name: name,
                            avatar: avatar,
                            totalPoints: totalPoints,
                            quizzesPlayed: quizzesPlayed,
                            quizzesWon: quizzesWon,
                            language: language,
                            categoryStats: categoryStats
                        )
                        users.append(user)
                    }
                }
                completion(users)
            }
    }

    func sendChallenge(to user: User, completion: @escaping (Result<String, Error>) -> Void) {
        guard let currentUserId = auth.currentUser?.uid else {
            completion(.failure(NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }
        
        let battleId = UUID().uuidString
        let challengeData: [String: Any] = [
            "battleId": battleId,
            "challengerId": currentUserId,
            "opponentId": user.id,
            "timestamp": FieldValue.serverTimestamp(),
            "status": "pending",
            "category": "",
            "currentQuestion": 0,
            "challengerScore": 0,
            "opponentScore": 0
        ]
        
        db.collection("battles").document(battleId).setData(challengeData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(battleId))
            }
        }
    }
    
    func listenForChallenges(completion: @escaping (String, String) -> Void) -> ListenerRegistration {
        guard let currentUserId = auth.currentUser?.uid else { 
            return db.collection("battles").document("dummy").addSnapshotListener { _, _ in }
        }
        
        return db.collection("battles")
            .whereField("opponentId", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents,
                      let challenge = documents.first,
                      let challengerId = challenge.data()["challengerId"] as? String,
                      let battleId = challenge.data()["battleId"] as? String else { return }
                
                completion(battleId, challengerId)
            }
    }
    
    func acceptChallenge(battleId: String, completion: @escaping (Bool) -> Void) {
        db.collection("battles").document(battleId).setData([
            "status": "accepted",
            "acceptedAt": FieldValue.serverTimestamp()
        ], merge: true) { error in
            completion(error == nil)
        }
    }
    
    func listenForBattleUpdates(battleId: String, completion: @escaping ([String: Any]) -> Void) -> ListenerRegistration {
        return db.collection("battles").document(battleId)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data() else { return }
                completion(data)
            }
    }
    
    func updateBattleState(battleId: String, category: String, status: String, completion: @escaping (Bool) -> Void) {
        db.collection("battles").document(battleId).updateData([
            "category": category,
            "status": status,
            "currentQuestion": 0,
            "updatedAt": FieldValue.serverTimestamp()
        ]) { error in
            completion(error == nil)
        }
    }
    
    func updateBattleScore(battleId: String, isChallenger: Bool, newScore: Int, completion: @escaping (Bool) -> Void) {
        let field = isChallenger ? "challengerScore" : "opponentScore"
        db.collection("battles").document(battleId).updateData([
            field: newScore
        ]) { error in
            completion(error == nil)
        }
    }
    
    func cancelChallenge(battleId: String) {
        db.collection("battles").document(battleId).updateData([
            "status": "cancelled",
            "cancelledAt": FieldValue.serverTimestamp()
        ])
    }
}
