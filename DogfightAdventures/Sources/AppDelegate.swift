//
//  AppDelegate.swift
//  Dogfight Adventures
//

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let options = DogfightLaunchOptions.fromProcessArguments()
        window.rootViewController = options.autoStarts ? GameViewController(launchOptions: options) : HomeViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
