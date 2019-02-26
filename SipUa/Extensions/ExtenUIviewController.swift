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

/* Create extension for Notification name */
extension Notification.Name {
    public static let appUpdateUI = Notification.Name("UpdateUI")
}

class RightLeftTransition: NSObject {
    
    // Duration
    var duration = 0.5
    
    // Mode
    enum SlideTransitionMode {
        case present, dismiss
    }
    
    // Default mode
    var transitionMode: SlideTransitionMode = .present
    
}

extension RightLeftTransition: UIViewControllerAnimatedTransitioning {
    
    /* Duration function */
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }
    
    /* Animation function */
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        // Create container view that act as a superview that involve in the transition
        let containerView = transitionContext.containerView
        // Get the view that we're going to present in the transition
        let toView = transitionContext.view(forKey: UITransitionContextViewKey.to)!
        // Get the view that we're going to dismiss in the transition
        let fromView = transitionContext.view(forKey: UITransitionContextViewKey.from)!
        // Create cg transform with x direction only
        let offScreenRight = CGAffineTransform(translationX: containerView.frame.width, y: 0)
        let offScreenLeft = CGAffineTransform(translationX: -containerView.frame.width, y: 0)
        // If mode is present
        if transitionMode == .present  {
            
            // Set position the presented view to off screen right
            toView.transform = offScreenRight
            // Add the presented view and the dismiss view to the view container
            containerView.addSubview(toView)
            containerView.addSubview(fromView)
            
            // Start animation with spint animation
            UIView.animate(withDuration: duration, delay: 0.0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.0, animations: {
                // Set position the dismiss view to off screen left
                fromView.transform = offScreenLeft
                // Set position the presented view to in screen
                toView.transform = CGAffineTransform.identity
            }) { (success: Bool) in
                // Telling the delegate that transition is complete
                // Delegate will call function at UI
                transitionContext.completeTransition(true)
            }
            // If mode is dismiss
        } else {
            
            // Set position the presented view to off screen left
            toView.transform = offScreenLeft
            // Add the presented view and the dismiss view to the view container
            containerView.addSubview(toView)
            containerView.addSubview(fromView)
            
            // Start animation with spint animation
            UIView.animate(withDuration: duration, delay: 0.0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.0, animations: {
                // Set position the dismiss view to off screen right
                fromView.transform = offScreenRight
                // Set position the presented view to in screen
                toView.transform = CGAffineTransform.identity
            }) { (success: Bool) in
                // Telling the delegate that transition is complete
                // Delegate will call function at UI
                transitionContext.completeTransition(true)
            }
            
        }
        
    }
    
}
