//
//  AppDelegate.swift
//  Examples
//
//  Created by Felici, Fabio on 08/07/2019.
//  Copyright © 2019 Fabio Felici. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow()
        let nav = UINavigationController(rootViewController: PaginationFeedbackViewController())
        window.rootViewController = nav
        self.window = window
        window.makeKeyAndVisible()
        return true
    }
}
