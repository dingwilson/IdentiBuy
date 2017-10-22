//
//  ProductSpecViewController.swift
//  IdentiBuy
//
//  Created by Wilson Ding on 10/22/17.
//  Copyright © 2017 Wilson Ding. All rights reserved.
//

import UIKit
import PKHUD

class ProductSpecViewController: UIViewController {

    @IBAction func didPressBuyButton(_ sender: Any) {
        HUD.flash(.progress, delay: 2.5) { finished in
            HUD.flash(.success, delay: 2.0) { finished in
                self.performSegue(withIdentifier: "unwindToVC", sender: self)
            }
        }
    }

    @IBAction func didPressBackButton(_ sender: Any) {
        self.performSegue(withIdentifier: "unwindToVC", sender: self)
    }
}
