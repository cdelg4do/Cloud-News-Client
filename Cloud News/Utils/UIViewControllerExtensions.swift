//
//  UIViewControllerExtensions.swift
//  Cloud News
//
//  Created by Carlos Delgado on 22/05/17.
//  Copyright © 2017 cdelg4do. All rights reserved.
//
//  This file provides additional extensions to the UIViewController class.

import Foundation


extension UIViewController {
    
    // This two functions will make the keyboard to hide when the user taps anywhere in the controller (except a text box):
    
    func hideKeyboardWhenTappedAround() {
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false    // false: the tap will not interfere and cancel other interactions
        view.addGestureRecognizer(tap)
    }
    
    func dismissKeyboard() {
        view.endEditing(true)
    }
}
