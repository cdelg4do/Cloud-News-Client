//
//  File.swift
//  Cloud News
//
//  Created by Carlos Delgado on 21/05/17.
//  Copyright © 2017 cdelg4do. All rights reserved.
//  
//  This class represents a controller that shows modal a dialog with a spinner and a given message text

import Foundation


class WaitDialog: UIViewController {
    
    private let waitDialogView = WaitDialogView()
    
    
    // Initializers:
    init(message: String) {
        super.init(nibName: nil, bundle: nil)
        
        modalTransitionStyle = .crossDissolve
        modalPresentationStyle = .overFullScreen
        waitDialogView.messageLabel.text = message
        
        view = waitDialogView
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Call this to show the dialog on the parent controller
    func show(onParent parent: UIViewController?) {
        
        parent?.present(self, animated: true)
    }
    
    // Call this to dismis the dialog and, after that, execute the trailing closure
    func hide(completion: @escaping (Void) -> Void) {
        
        self.dismiss(animated: true) {
            completion()
        }
    }
    
    // Call this to dismiss the dialog (the next code sentence will NOT wait until the dialog is dismissed
    // (use hide() with completion if you want to present another controller -like a dialog box- )
    func hide() {
        
        self.dismiss(animated: true)
    }
}


// This private class defines the dialog view

private class WaitDialogView: UIView {
    
    let activityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
    let boundingBoxView = UIView(frame: CGRect.zero)
    let messageLabel = UILabel(frame: CGRect.zero)
    
    init() {
        super.init(frame: CGRect.zero)
        
        backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        
        boundingBoxView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        boundingBoxView.layer.cornerRadius = 12.0
        
        activityIndicatorView.startAnimating()
        
        messageLabel.font = UIFont.boldSystemFont(ofSize: UIFont.labelFontSize)
        messageLabel.textColor = UIColor.white
        messageLabel.textAlignment = .center
        messageLabel.shadowColor = UIColor.black
        messageLabel.shadowOffset = CGSize(width: 0.0, height: 1.0)
        messageLabel.numberOfLines = 0
        
        addSubview(boundingBoxView)
        addSubview(activityIndicatorView)
        addSubview(messageLabel)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Size and position for the boundingBoxView, the activityIndicatorView and the messageLabel
    override func layoutSubviews() {
        super.layoutSubviews()
        
        boundingBoxView.frame.size.width = 160.0
        boundingBoxView.frame.size.height = 160.0
        boundingBoxView.frame.origin.x = ceil((bounds.width / 2.0) - (boundingBoxView.frame.width / 2.0))
        boundingBoxView.frame.origin.y = ceil((bounds.height / 2.0) - (boundingBoxView.frame.height / 2.0))
        
        activityIndicatorView.frame.origin.x = ceil((bounds.width / 2.0) - (activityIndicatorView.frame.width / 2.0))
        activityIndicatorView.frame.origin.y = ceil((bounds.height / 2.0) - (activityIndicatorView.frame.height / 2.0))
        
        let messageLabelSize = messageLabel.sizeThatFits(CGSize(width: 160.0 - 20.0 * 2.0, height: CGFloat.greatestFiniteMagnitude))
        messageLabel.frame.size.width = messageLabelSize.width
        messageLabel.frame.size.height = messageLabelSize.height
        
        messageLabel.frame.origin.x = ceil((bounds.width / 2.0) - (messageLabel.frame.width / 2.0))
        messageLabel.frame.origin.y = ceil(activityIndicatorView.frame.origin.y + activityIndicatorView.frame.size.height + ((boundingBoxView.frame.height - activityIndicatorView.frame.height) / 4.0) - (messageLabel.frame.height / 2.0))
    }
}
