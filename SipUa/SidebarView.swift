//
//  SidebarView.swift
//  SipUa
//
//  Created by NLDeviOS on 11/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import Foundation
import UIKit

protocol SidebarViewDelegate: class {
    func sidebarDidSelectRow(row: Row)
}

enum Row:String {
    case editProfile
    case home
    case calling_Setting
    case general_Setting
    case about
    case logout
    case none
    init(row: Int) {
        switch row {
        case 0: self = .editProfile
        case 1: self = .home
        case 2: self = .calling_Setting
        case 3: self = .general_Setting
        case 4: self = .about
        case 5: self = .logout
        default: self = .none
        }
    }
}

class SidebarView: UIView,UITableViewDelegate,UITableViewDataSource {
    var titleArr = [String]()
    
    weak var delegate: SidebarViewDelegate?
    
    override init(frame: CGRect) {
        super.init(frame:frame)
        self.backgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        self.clipsToBounds = true
        
        setupViews()
        
        titleArr = ["User name","Home","Calling Setting","General Setting","About","Log Out"]
        
        myTableView.delegate = self
        myTableView.dataSource = self
        myTableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        myTableView.tableFooterView = UIView()
        myTableView.separatorStyle = UITableViewCell.SeparatorStyle.none
        myTableView.allowsSelection = true
        myTableView.bounces = false
        myTableView.showsVerticalScrollIndicator = false
        myTableView.backgroundColor = UIColor.clear
        
    }
    
    
    func setupViews(){
        self.addSubview(myTableView)
        myTableView.topAnchor.constraint(equalTo:topAnchor).isActive = true
        myTableView.leftAnchor.constraint(equalTo:leftAnchor).isActive = true
        myTableView.rightAnchor.constraint(equalTo:rightAnchor).isActive = true
        myTableView.bottomAnchor.constraint(equalTo:bottomAnchor).isActive = true
    }
    
    let myTableView: UITableView = {
        let table = UITableView()
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titleArr.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        if indexPath.row == 0 {
            cell.backgroundColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
            let cellImg = UIImageView(frame: CGRect(x: 15, y: 10, width: 80, height: 80))
            cellImg.layer.cornerRadius = 40
            cellImg.layer.masksToBounds = true
            cellImg.contentMode = .scaleAspectFill
            cellImg.layer.masksToBounds = true
            cellImg.image = UIImage(named: "bic")
            cell.addSubview(cellImg)
            
            let cellLbl = UILabel(frame: CGRect(x: 110, y: cell.frame.height/2 - 15, width: 250, height: 30))
            cell.addSubview(cellLbl)
            cellLbl.text = titleArr[indexPath.row]
            cellLbl.font = UIFont.systemFont(ofSize: 17)
            cellLbl.textColor = UIColor.white
        } else {
            cell.textLabel?.text = titleArr[indexPath.row]
            cell.textLabel?.textColor = UIColor.black
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.delegate?.sidebarDidSelectRow(row:Row(row:indexPath.row))
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 0 {
            return 150
        } else {
            return 60
        }
    }
    
}
