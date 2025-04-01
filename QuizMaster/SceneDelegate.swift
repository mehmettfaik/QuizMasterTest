//
//  SceneDelegate.swift
//  QuizMaster
//
//  Created by Mehmet Faik Ayhan on 8.03.2025.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private let db = Firestore.firestore()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        
        // Kullanıcının giriş durumunu kontrol et
        if Auth.auth().currentUser != nil {
            // Kullanıcı giriş yapmışsa TabBarController'ı göster
            window.rootViewController = MainTabBarController()
            if let userId = Auth.auth().currentUser?.uid {
                FirebaseService.shared.updateOnlineStatus(userId: userId, isOnline: true)
            }
        } else {
            // Kullanıcı giriş yapmamışsa LoginViewController'ı göster
            window.rootViewController = LoginViewController()
        }
        
        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
        
        // Set user as offline when scene disconnects
        if let userId = Auth.auth().currentUser?.uid {
            FirebaseService.shared.updateOnlineStatus(userId: userId, isOnline: false)
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        
        // Set user as online when scene becomes active
        if let userId = Auth.auth().currentUser?.uid {
            FirebaseService.shared.updateOnlineStatus(userId: userId, isOnline: true)
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        
        // Set user as online when app enters foreground
        if let userId = Auth.auth().currentUser?.uid {
            FirebaseService.shared.updateOnlineStatus(userId: userId, isOnline: true)
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        
        // Set user as offline when app enters background
        if let userId = Auth.auth().currentUser?.uid {
            FirebaseService.shared.updateOnlineStatus(userId: userId, isOnline: false)
        }
    }
}

// Custom TabBar class for curved design
@IBDesignable
class CustomTabBar: UITabBar {
    private var shapeLayer: CALayer?
    
    private func addShape() {
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = createPath()
        shapeLayer.strokeColor = UIColor.clear.cgColor
        shapeLayer.fillColor = UIColor.white.cgColor
        shapeLayer.lineWidth = 1.0
        
        // Shadow configuration
        shapeLayer.shadowOffset = CGSize(width: 0, height: -1)
        shapeLayer.shadowRadius = 6
        shapeLayer.shadowColor = UIColor.black.cgColor
        shapeLayer.shadowOpacity = 0.1
        
        if let oldShapeLayer = self.shapeLayer {
            self.layer.replaceSublayer(oldShapeLayer, with: shapeLayer)
        } else {
            self.layer.insertSublayer(shapeLayer, at: 0)
        }
        self.shapeLayer = shapeLayer
    }
    
    override func draw(_ rect: CGRect) {
        self.addShape()
    }
    
    func createPath() -> CGPath {
        let height: CGFloat = 42.0
        let path = UIBezierPath()
        let centerWidth = self.frame.width / 2
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: (centerWidth - height * 2), y: 0))
        
        // Daha yumuşak bir kavis için kontrol noktalarını ayarla
        path.addCurve(to: CGPoint(x: centerWidth, y: height),
                     controlPoint1: CGPoint(x: (centerWidth - 35), y: 0),
                     controlPoint2: CGPoint(x: centerWidth - 40, y: height))
        
        path.addCurve(to: CGPoint(x: (centerWidth + height * 2), y: 0),
                     controlPoint1: CGPoint(x: centerWidth + 40, y: height),
                     controlPoint2: CGPoint(x: (centerWidth + 35), y: 0))
        
        path.addLine(to: CGPoint(x: self.frame.width, y: 0))
        path.addLine(to: CGPoint(x: self.frame.width, y: self.frame.height))
        path.addLine(to: CGPoint(x: 0, y: self.frame.height))
        path.close()
        
        return path.cgPath
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !clipsToBounds && !isHidden && alpha > 0 else { return nil }
        
        // Orta butonun hit test alanını genişlet
        if let middleButton = subviews.first(where: { $0 is UIButton }) {
            let buttonPoint = convert(point, to: middleButton)
            if middleButton.point(inside: buttonPoint, with: event) {
                return middleButton
            }
        }
        
        return super.hitTest(point, with: event)
    }
}

class MainTabBarController: UITabBarController {
    private var middleButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set custom tab bar
        let customTabBar = CustomTabBar()
        self.setValue(customTabBar, forKey: "tabBar")
        
        setupTabs()
        setupAppearance()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupMiddleButton()
    }
    
    private func setupTabs() {
        let homeVC = HomeViewController()
        let searchVC = SearchViewController()
        let createVC = UIViewController() // Placeholder for middle button
        let statsVC = StatsViewController()
        let profileVC = ProfileViewController()
        
        let profileNav = UINavigationController(rootViewController: profileVC)
        
        homeVC.tabBarItem = UITabBarItem(title: "Ana Sayfa", image: UIImage(systemName: "house"), selectedImage: UIImage(systemName: "house.fill"))
        searchVC.tabBarItem = UITabBarItem(title: "Keşfet", image: UIImage(systemName: "magnifyingglass"), selectedImage: UIImage(systemName: "magnifyingglass"))
        createVC.tabBarItem = UITabBarItem(title: "", image: nil, selectedImage: nil)
        statsVC.tabBarItem = UITabBarItem(title: "İstatistik", image: UIImage(systemName: "chart.bar"), selectedImage: UIImage(systemName: "chart.bar.fill"))
        profileNav.tabBarItem = UITabBarItem(title: "Profil", image: UIImage(systemName: "person"), selectedImage: UIImage(systemName: "person.fill"))
        
        setViewControllers([homeVC, searchVC, createVC, statsVC, profileNav], animated: false)
    }
    
    private func setupAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        
        // Configure colors for tab items
        let normalColor = UIColor(red: 142/255, green: 142/255, blue: 147/255, alpha: 1)
        
        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.selected.iconColor = .primaryPurple
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.primaryPurple]

        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
    }
    
    private func setupMiddleButton() {
        // Eğer buton zaten varsa kaldır
        middleButton?.removeFromSuperview()
        
        // Buton boyutları
        let buttonSize: CGFloat = 56
        let buttonY: CGFloat = -28
        
        middleButton = UIButton(frame: CGRect(x: (view.bounds.width / 2) - (buttonSize/2),
                                            y: buttonY,
                                            width: buttonSize,
                                            height: buttonSize))
        
        // Buton tasarımı
        middleButton.backgroundColor = .primaryPurple
        middleButton.layer.cornerRadius = buttonSize/2
        
        // Gölge efekti
        middleButton.layer.shadowColor = UIColor.black.cgColor
        middleButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        middleButton.layer.shadowRadius = 8
        middleButton.layer.shadowOpacity = 0.15
        
        // Plus icon
        let plusConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        let plusImage = UIImage(systemName: "plus")?.withConfiguration(plusConfig)
        middleButton.setImage(plusImage, for: .normal)
        middleButton.tintColor = .white
        
        // Butonun z-index'ini artır
        middleButton.layer.zPosition = 100
        
        // Buton aksiyonu
        middleButton.addTarget(self, action: #selector(middleButtonAction), for: .touchUpInside)
        
        // TabBar'a ekle
        tabBar.addSubview(middleButton)
        tabBar.bringSubviewToFront(middleButton)
    }
    
    @objc private func middleButtonAction() {
        selectedIndex = 2
        let addQuestionVC = AddQuestionViewController()
        addQuestionVC.modalPresentationStyle = .fullScreen
        present(addQuestionVC, animated: true)
    }
}

// Placeholder View Controllers
class DiscoverViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
    }
}



