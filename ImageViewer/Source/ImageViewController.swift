//
//  ImageViewController.swift
//  ImageViewer
//
//  Created by Kristian Angyal on 15/07/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//

import UIKit

extension UIImageView: ItemView {}

class ImageViewController: ItemBaseController<UIImageView> {
}

class UnsupportedViewController: ImageViewController {
    var message: String? {
        didSet {
            messageLabel?.text = message
        }
    }
    var messageLabel: UILabel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let label = UILabel()
        label.text = message
        label.textColor = UIColor.white
        label.shadowColor = UIColor.black
        label.shadowOffset = CGSize(width: 1, height: 1)
        label.textAlignment = .center
        view.addSubview(label)
        
        messageLabel = label
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        messageLabel?.frame = view.bounds
    }
}
