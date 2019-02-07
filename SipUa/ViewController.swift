//
//  ViewController.swift
//  SipUa
//
//  Created by NLDeviOS on 7/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var oTFoPassword: UITextField!
    
    @IBOutlet weak var oTFoPhoneNumber: UITextField!
    
    @IBOutlet weak var oRemember: UIButton!
    
    @IBOutlet weak var oULPN: UIView!
    
    @IBOutlet weak var oULPass: UIView!
    
    @IBOutlet weak var oShowPass: UIButton!
    
    @IBOutlet weak var lbPN: UILabel!
    @IBOutlet weak var lbPW: UILabel!
    
    var isShowChecked = false
    var isSaveChecked = false
    var isPressPS = false
    var isPressPN = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()

    }
    
    func setupView() {
        
        oRemember.layer.cornerRadius = oRemember.frame.width/2
        oRemember.layer.borderWidth = 2
        oRemember.layer.borderColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
        
        oShowPass.layer.cornerRadius = oShowPass.frame.height / 2
        oShowPass.layer.borderWidth = 2
        oShowPass.layer.borderColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
        
        oTFoPassword.addTarget(self, action: #selector(pressPass), for: UIControl.Event.touchDown)
        oTFoPhoneNumber.addTarget(self, action: #selector(pressPN), for: UIControl.Event.touchDown)
        
    }
    
    @objc func pressPass(textField: UITextField){
        isPressPS = !isPressPS
        if isPressPS{
            self.oULPass.layer.backgroundColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
            self.oULPN.layer.backgroundColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
            lbPN.textColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
            lbPW.textColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
            isPressPS = !isPressPS
        }
//        } else {
////        if isPressPN{
//            self.oULPass.layer.backgroundColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
//            self.oULPN.layer.backgroundColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
//        }
        
    }
    
    @objc func pressPN(textField: UITextField){
        isPressPN = !isPressPN
        if isPressPN{
            self.oULPass.layer.backgroundColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
            self.oULPN.layer.backgroundColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
            lbPW.textColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
            lbPN.textColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
            isPressPN = !isPressPN
        }

    }
    
    

    @IBAction func pressShowBtn(_ sender: UIButton) {
        isShowChecked = !isShowChecked
        if isShowChecked {
            sender.setTitle("✓", for: .normal)
            sender.setTitleColor(.white, for: .normal)
            self.oShowPass.layer.backgroundColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
            oTFoPassword.isSecureTextEntry = false
        } else {
            sender.setTitle("", for: .normal)
            sender.setTitleColor(.red, for: .normal)
            self.oShowPass.layer.backgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            oTFoPassword.isSecureTextEntry = true
        }
        
        
    }
    
    @IBAction func pressSavePassBtn(_ sender: UIButton) {
        isSaveChecked = !isSaveChecked
        if isSaveChecked{
            sender.setTitle("✓", for: .normal)
            sender.setTitleColor(.white, for: .normal)
            self.oRemember.layer.backgroundColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
        } else {
            sender.setTitle("", for: .normal)
            sender.setTitleColor(.red, for: .normal)
            self.oRemember.layer.backgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        }
        
        
    }
}

