//
//  SceneDelegate.swift
//  refillr
//
//  Created by Abby Ressner on 8/6/25.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // If the system didn’t auto-create a window from a storyboard, do it here.
        if window == nil || window?.rootViewController == nil {
            let window = UIWindow(windowScene: windowScene)

            // Try to load the initial VC from Main.storyboard
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let root = storyboard.instantiateInitialViewController() {
                window.rootViewController = root
            } else {
                // Fallback to avoid a black screen if no initial VC is set in storyboard
                let vc = UIViewController()
                vc.view.backgroundColor = .systemBackground
#if DEBUG
                let label = UILabel()
                label.text = "No initial view controller in Main.storyboard"
                label.textAlignment = .center
                label.numberOfLines = 0
                label.translatesAutoresizingMaskIntoConstraints = false
                vc.view.addSubview(label)
                NSLayoutConstraint.activate([
                    label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
                    label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
                    label.leadingAnchor.constraint(greaterThanOrEqualTo: vc.view.leadingAnchor, constant: 20),
                    label.trailingAnchor.constraint(lessThanOrEqualTo: vc.view.trailingAnchor, constant: -20)
                ])
#endif
                window.rootViewController = vc
            }

            self.window = window
            window.makeKeyAndVisible()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
