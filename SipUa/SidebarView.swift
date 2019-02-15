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
    func sidebarDidSelectOldRow()
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

struct SidebarViewRow {
    static var rowSelect:Int = 1
}

class SidebarView: UIView,UITableViewDelegate,UITableViewDataSource {
    
    var titleArr = [String]()
    weak var delegate: SidebarViewDelegate?
    
    override init(frame: CGRect) {
        super.init(frame:frame)
        self.backgroundColor = UIColor.custom_white
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
            cell.backgroundColor = UIColor.custom_lightGreen
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
            if indexPath.row == SidebarViewRow.rowSelect {
                cell.backgroundColor = UIColor.custom_lightGreen
                cell.textLabel?.textColor = UIColor.custom_white
            }else{
                cell.backgroundColor = UIColor.custom_white
                cell.textLabel?.textColor = UIColor.custom_black
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row != SidebarViewRow.rowSelect {
            SidebarViewRow.rowSelect = indexPath.row
            self.delegate?.sidebarDidSelectRow(row:Row(row:indexPath.row))
        }else{
            self.delegate?.sidebarDidSelectOldRow()
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 0 {
            return 150
        } else {
            return 60
        }
    }
    
}
