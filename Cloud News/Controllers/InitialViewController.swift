//
//  InitialViewController.swift
//  Cloud News
//
//  Created by Carlos Delgado on 26/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//
//  This is the initial controller of the app, lets the user choose to enter the reader mode
//  (to read all published news) or to enter the writer mode (to read/update his own articles).


import UIKit


class InitialViewController: UIViewController {
    
    // Azure Mobile Client
    // (initialized here, shared with all the other controllers in the app)
    var appClient: MSClient = MSClient(applicationURL: URL(string: Backend.mobileAppUrlString)!)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    
    //MARK: Actions from the UI elements
    
    // 'Read News' button -> go to the controller that shows all the news (articles already published)
    @IBAction func enterReaderMode(_ sender: AnyObject) {
        
        let readerVC = ReaderTableViewController(client: appClient)
        navigationController?.pushViewController(readerVC, animated: true)
    }
    
    // 'Write News' button -> go to the controller that shows my own articles
    @IBAction func enterWriterMode(_ sender: AnyObject) {
        
        let writerVC = WriterArticlesViewController(client: appClient)
        navigationController?.pushViewController(writerVC, animated: true)
    }
}
