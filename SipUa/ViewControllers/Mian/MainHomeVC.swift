//
//  MainHomeVC.swift
//  SipUa
//
//  Created by NLDeviOS on 13/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit
import JAPagerViewController

class MainHomeVC: BaseVC {

    @IBOutlet weak var view_main: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let page1 = self.storyboard?.instantiateViewController(withIdentifier: "HomeID") as! HomeVC
        page1.title = "Page1"
        
        let page2 = UIStoryboard.init(name: "History", bundle: Bundle.main).instantiateViewController(withIdentifier: "HistoryID") as! HistoryVC
        page2.title = "History"
        
        let page3 = UIStoryboard.init(name: "PhonPad", bundle: Bundle.main).instantiateViewController(withIdentifier: "PhonPadID") as! PhonPadVC
        page3.title = "PhonPad"
//        page3.
        
        let pager = JAPagerViewController(pages: [page1,page2,page3])
        
        
        addChild(pager)
        self.view_main.addSubview(pager.view)
        pager.didMove(toParent: self)
        pager.tabMenuHeight = 44 //stardard % 4 == 0
        pager.tabEqualWidth = view_main.frame.width / 3
        pager.tabItemWidthType = .equal
        pager.selectedTabTitleColor = UIColor.red
        pager.selectedTabTitleFont = UIFont.boldSystemFont(ofSize: 12)
        
        setUpView()
    }
    
    func setUpView(){

        self.addTitle(text: "Home")
        self.addHamberBar()
    }
    
}
