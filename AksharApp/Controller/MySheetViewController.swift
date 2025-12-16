//
//  MySheetViewController.swift
//  AksharApp
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit

class MySheetViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        DispatchQueue.main.async {
//            self.preferredContentSize = CGSize(width: 800, height: 700)
        }
    }
    @IBOutlet weak var powerWords: UIImageView!
    @IBOutlet weak var letter6: UIImageView!
    @IBOutlet weak var letter5: UIImageView!
    
    @IBOutlet weak var letter3: UIImageView!
    
    @IBOutlet weak var letter4: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()
        letter3.layer.cornerRadius = 20
        letter4.layer.cornerRadius = 20
        letter5.layer.cornerRadius = 20
        letter6.layer.cornerRadius = 20
        powerWords.layer.cornerRadius = 20

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
