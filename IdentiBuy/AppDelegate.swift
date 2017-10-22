//
//  AppDelegate.swift
//  IdentiBuy
//
//  Created by Wilson Ding on 10/22/17.
//  Copyright © 2017 Wilson Ding. All rights reserved.
//

import UIKit
import Clarifai_Apple_SDK

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        guard
            let path = Bundle.main.path(forResource: "Keys", ofType: "plist"),
            let keys = NSDictionary(contentsOf: URL(fileURLWithPath: path))
            else {
                print("Error: No Keys.plist file found. Please add one containing the Clarifai API Key.")
                return false
        }

        if let clarifaiKey = keys["ClarifaiKey"] {
            Clarifai.sharedInstance().start(apiKey: clarifaiKey as! String)
        }

        return true
    }
}

