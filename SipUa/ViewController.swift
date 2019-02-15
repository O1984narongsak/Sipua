//
//  ViewController.swift
//  SipUa
//
//  Created by NLDeviOS on 7/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit
import DropDown

class ViewController: UIViewController {

    @IBOutlet weak var oTFoPassword: UITextField!
    
    @IBOutlet weak var oTFoPhoneNumber: UITextField!
    
    @IBOutlet weak var oRemember: UIButton!
    
    @IBOutlet weak var oULPN: UIView!
    
    @IBOutlet weak var oULPass: UIView!
    
    @IBOutlet weak var oShowPass: UIButton!
    
    @IBOutlet weak var lbPN: UILabel!
    @IBOutlet weak var lbPW: UILabel!
    
    @IBOutlet weak var btnToHome: UIButton!
    @IBOutlet weak var btnBGToHome: UIView!
    //TODO: - DropDown
    @IBOutlet weak var tbList: UITableView!
    @IBOutlet weak var tbLHC: NSLayoutConstraint!
    @IBOutlet weak var btnDropDownList: UIButton!
    
    var isShowChecked = false
    var isSaveChecked = false
    var isPressPS = false
    var isPressPN = false
    
    var isShowList = false
    
    var positionPN: CGPoint!
    var positionPW: CGPoint!
    var listArr = [String]()
    
    let dropDown = DropDown()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()

    }
    
    func setupView() {
        
        positionPN = lbPN.center
        positionPW = lbPW.center
        oRemember.layer.cornerRadius = oRemember.frame.width/2
        oRemember.layer.borderWidth = 2
        oRemember.layer.borderColor = UIColor.custom_lightGreen.cgColor
        
        oShowPass.layer.cornerRadius = oShowPass.frame.height / 2
        oShowPass.layer.borderWidth = 2
        oShowPass.layer.borderColor = UIColor.custom_lightGreen.cgColor
        
        oTFoPassword.addTarget(self, action: #selector(pressPass), for: UIControl.Event.touchDown)
        oTFoPhoneNumber.addTarget(self, action: #selector(pressPN), for: UIControl.Event.touchDown)
        
        btnToHome.translatesAutoresizingMaskIntoConstraints = false
        
        tbList.delegate = self
        tbList.dataSource = self
        tbLHC.constant = 0
        tbList.isHidden = true
        
        dropDown.anchorView = btnDropDownList
        
        listArr = ["sip.linphone.org","ucc.ais.co.th"]
        dropDown.dataSource = ["sip.linphone.org","ucc.ais.co.th"]
    }
    
    @objc func pressPass(textField: UITextField){
        isPressPS = !isPressPS
        if isPressPS{
            self.oULPass.layer.backgroundColor = UIColor.custom_lightGreen.cgColor
            self.oULPN.layer.backgroundColor = UIColor.custom_black.cgColor
            lbPN.textColor = UIColor.custom_black
            lbPW.textColor = UIColor.custom_lightGreen
            UIView.animate(withDuration: 0.3, animations: {
                self.lbPN.center = self.oTFoPhoneNumber.center
                self.lbPN.font.withSize(24.0)
                self.lbPW.center = self.positionPW
                self.lbPW.font.withSize(17.0)
            })
            isPressPS = !isPressPS
        }

        
    }
    
    @objc func pressPN(textField: UITextField){
        isPressPN = !isPressPN
        if isPressPN{
            self.oULPass.layer.backgroundColor = UIColor.custom_black.cgColor
            self.oULPN.layer.backgroundColor = UIColor.custom_lightGreen.cgColor
            lbPW.textColor = UIColor.custom_black
            lbPN.textColor = UIColor.custom_lightGreen
            UIView.animate(withDuration: 0.3, animations: {
             self.lbPW.center = self.oTFoPassword.center
             self.lbPW.font.withSize(24.0)
             self.lbPN.center = self.positionPN
             self.lbPN.font.withSize(17.0)
            })
            isPressPN = !isPressPN
        }

    }
    
    

    @IBAction func pressShowBtn(_ sender: UIButton) {
        isShowChecked = !isShowChecked
        if isShowChecked {
            sender.setTitle("✓", for: .normal)
            sender.setTitleColor(.white, for: .normal)
            self.oShowPass.layer.backgroundColor = UIColor.custom_lightGreen.cgColor
            oTFoPassword.isSecureTextEntry = false
        } else {
            sender.setTitle("", for: .normal)
            sender.setTitleColor(.red, for: .normal)
            self.oShowPass.layer.backgroundColor = UIColor.custom_white.cgColor
            oTFoPassword.isSecureTextEntry = true
        }
        
        
    }
    
    @IBAction func pressSavePassBtn(_ sender: UIButton) {
        isSaveChecked = !isSaveChecked
        if isSaveChecked{
            sender.setTitle("✓", for: .normal)
            sender.setTitleColor(.white, for: .normal)
            self.oRemember.layer.backgroundColor = UIColor.custom_lightGreen.cgColor
        } else {
            sender.setTitle("", for: .normal)
            sender.setTitleColor(.red, for: .normal)
            self.oRemember.layer.backgroundColor = UIColor.custom_white.cgColor
        }
        
    }
    //TODO: - DRopDown
    
    @IBAction func selectNumberOfList(_ sender: Any) {
        dropDown.show()
        dropDown.selectionAction = { [unowned self] (index: Int, item: String) in
            print("Selected item: \(item) at index: \(index)")
            self.btnDropDownList.titleLabel?.text = item
        }
//        isShowList = !isShowList
//        if isShowList{
//            tbList.isHidden = false
//            self.tbLHC.constant = 40 * 2
//            self.view.layoutIfNeeded()
//        }else{
//            tbList.isHidden = true
//        }
    }
    
    
    
    //TODO: - Login
    @IBAction func pressToHome(_ sender: UIButton) {
        setPushAnimation()
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MainNav")
        self.present(vc, animated: true, completion: nil)
    }
    
    func setPushAnimation(){
        
        UIView.animate(withDuration: 0.3, animations: {
            self.btnToHome.alpha = 0
            self.btnToHome.center = self.btnBGToHome.center
            self.btnBGToHome.layer.backgroundColor = UIColor.custom_lightGreen.cgColor
            })
        
        
    }
}

//MARK: - UITableViewDelegate UITableViewDatasource
extension ViewController : UITableViewDelegate,UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return listArr.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "numberofrooms")
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: "numberofrooms")
            cell?.textLabel?.text = listArr[indexPath.row]
        }
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        tbList.isHidden = true
    }
}
