//
//  SplunkViewController.swift
//  UXSDKSwiftSample
//
//  Created by Amin Hamidi, Sterling Trafford on 6/2/22.
//  Copyright © 2022 DJI. All rights reserved.
//

import UIKit
import SwiftUI

class SplunkViewController: UIViewController {

    @IBOutlet weak var theContainer : UIView!
    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 14.0, *) {
            print("Was available")
            let childView = UIHostingController(rootView: Splunk())
            addChild(childView)
            childView.view.frame = theContainer.bounds
            theContainer.addSubview(childView.view)
        } else {
            print("NOOOOOOOOOOO")
            // Fallback on earlier versions
        }
        
        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
