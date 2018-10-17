//
//  PhotoPopUp.swift
//  Pixed City
//
//  Created by Wissa Azmy on 10/17/18.
//  Copyright © 2018 Wissa Azmy. All rights reserved.
//

import UIKit

class PhotoPopUp: UIViewController {
    
    var image: UIImage!
    
    @IBOutlet weak var photoImg: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        initView()
        addSwipe()
    }
    
    
    private func addSwipe() {
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(dismissView))
        swipe.direction = .up
        self.view.addGestureRecognizer(swipe)
    }
    

    func initData(withImg img: UIImage) {
        image = img
    }
    
    
    private func initView() {
        photoImg.image = image
    }
    
    
    @objc private func dismissView() {
        dismiss(animated: true)
    }
}
