//
//  ExtenUIviewController.swift
//  SipUa
//
//  Created by NLDeviOS on 14/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit
import os
extension UIViewController {
    
    static var storyboardID: String {

        return "\(self)"
    }
    
    static func instantiateFromAppStoryboard(appStoryboard: AppStoryboard) -> Self {
        return appStoryboard.viewController(viewControllerClass: self)
    }
    
    func hideKeyboardWhenTappedAround(enable: Bool = true) {
        if enable {
            let tap = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
            tap.cancelsTouchesInView = false
            view.addGestureRecognizer(tap)
//            os_log("Extension : Add tap gesture", log: log_app_debug, type: .debug)
        } else {
            view.gestureRecognizers?.forEach({ (gesture: UIGestureRecognizer) in
                view.removeGestureRecognizer(gesture)
            })
//            os_log("Extension : Remove all gesture", log: log_app_debug, type: .debug)
        }
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    /**
     Add constraint from subview to superview.
     - parameters:
     - subView: a view that will be subview.
     - superView: a view that will be superview.
     */
    func fillSubViewToSuperView(subView: UIView, superView: UIView) {
        subView.translatesAutoresizingMaskIntoConstraints = false
        subView.leftAnchor.constraint(equalTo: superView.leftAnchor, constant: 0.0).isActive = true
        subView.rightAnchor.constraint(equalTo: superView.rightAnchor, constant: 0.0).isActive = true
        subView.topAnchor.constraint(equalTo: superView.topAnchor, constant: 0.0).isActive = true
        subView.bottomAnchor.constraint(equalTo: superView.bottomAnchor, constant: 0.0).isActive = true
    }
    
    /**
     Set an image to title navigation bar.
     - parameters:
     - navigationBar: a navigation bar to set image.
     - frame: an image frame to set in title navigation bar.
     - image: an image to set in title navigation bar.
     */
    func setupNavigationBarImageTitle(navigationBar: UINavigationItem, frame: CGRect, image: UIImage) {
        let iconView = UIView(frame: frame)
        let titleImageView = UIImageView(image: image.withRenderingMode(.alwaysOriginal))
        titleImageView.frame = frame
        titleImageView.contentMode = .scaleAspectFit
        iconView.addSubview(titleImageView)
        navigationBar.titleView = iconView
    }
    
}

extension UIView {
    /**
     Rotate a view.
     - parameters:
     - duration: a duration as int.
     */
    func startRotation(duration: Int) {
        let kAnimation = "rotation"
        if self.layer.animation(forKey: kAnimation) == nil {
            let animation = CABasicAnimation.init(keyPath: "transform.rotation")
            animation.duration = CFTimeInterval(duration)
            animation.repeatCount = Float.infinity
            animation.fromValue = 0.0
            animation.toValue = Float(.pi * 2.0)
            self.layer.add(animation, forKey: kAnimation)
        }
    }
    /**
     Stop view rotation.
     */
    func stopRotation() {
        let kAnimation = "rotation"
        if self.layer.animation(forKey: kAnimation) != nil {
            self.layer.removeAnimation(forKey: kAnimation)
        }
    }
}
