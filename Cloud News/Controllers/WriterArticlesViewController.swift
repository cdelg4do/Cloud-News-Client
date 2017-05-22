//
//  WriterArticlesViewController.swift
//  Cloud News
//
//  Created by Carlos Delgado on 30/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//
//  This controller is in charge of showing the list of articles (published, submitted or draft) written by the user.
//  Facebook login and logout are performed from this controller.


import UIKit


class WriterArticlesViewController: UIViewController {
    
    var appClient: MSClient                     // Azure Mobile client
    var articleList: [DatabaseRecord]? = []     // List of articles to show in the table
    var thumbsCache = [String:UIImage]()        // Thumbnails cache
    var sessionInfo: SessionInfo?               // Info about the current user session
    var currentArticleStatus: ArticleStatus = ArticleStatus.draft   // Table will show articles in this status (default: draft)
    
    
    //MARK: UI elements
    
    let indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)  // Table activity indicator
    let emptyLabel = UILabel()  // Label to show in case the table is empty
    
    var refreshControl: UIRefreshControl?
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var btnDraft: UIBarButtonItem!
    @IBOutlet weak var btnSubmitted: UIBarButtonItem!
    @IBOutlet weak var btnPublished: UIBarButtonItem!
    
    
    //MARK: Initializers
    
    init(client: MSClient) {
        
        self.appClient = client
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    //MARK: controller lifecycle events
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        
        // If there is an active session, load the articles
        // If not, first try to log in with Facebook credentials and then load the articles
        if let _ = appClient.currentUser    {   loadArticles(originIsPullRefresh: false) }
        else                                {   loginWithFacebookThenLoadArticles()   }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        thumbsCache.removeAll()
    }
    
    
    //MARK: Actions from the UI elements
    
    // 'Draft' button -> load the user's drafts
    @IBAction func btnDraftAction(_ sender: AnyObject) {
        currentArticleStatus = .draft
        loadArticles(originIsPullRefresh: false)
    }
    
    // 'Submitted' button -> load the user's submitted articles
    @IBAction func btnSubmittedAction(_ sender: AnyObject) {
        currentArticleStatus = .submitted
        loadArticles(originIsPullRefresh: false)
    }
    
    // 'Published' button -> load the user's published articles
    @IBAction func btnPublishedAction(_ sender: AnyObject) {
        currentArticleStatus = .published
        loadArticles(originIsPullRefresh: false)
    }
}


// MARK: class extensions

// Implementation of the TableViewDataSource protocol
extension WriterArticlesViewController: UITableViewDataSource {
    
    // Number of sections: 1 (0 if no data to show)
    func numberOfSections(in tableView: UITableView) -> Int {
        
        if (articleList?.isEmpty)!  {   return 0    }
        else                        {   return 1    }
    }
    
    // Number of rows in a section: as many as articles retrieved (0 if no data to show)
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if (articleList?.isEmpty)!  {   return 0                    }
        else                        {   return (articleList?.count)!   }
    }
    
    // Setup of table cells
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Get the news data for the given position
        let article = articleList?[indexPath.row]
        
        let articleId = article?["id"] as! String?
        let articleTitle = article?["title"] as! String?
        let articleVisits = article?["visits"] as! Int?
        let articleDate = article?["date"] as! NSDate?
        let articleHasImage = article?["hasImage"] as! Bool?
        let articleImageName = article?["imageName"] as! String?
        
        let dateString = Utils.dateToString(articleDate!)
        var detailLabelText: String
        
        // Depending on the article status, the cell detail will show different information
        switch (currentArticleStatus) {
            
            case .published:    detailLabelText = "\(articleVisits!) views since \(dateString)" // view counter since article was published
                                break
            
            case .submitted:    detailLabelText = "Submitted on \(dateString)"      // date the article was submitted
                                break
        
            case .draft:        detailLabelText = "Last updated on \(dateString)"   // date the article was updated
                                break
        }
        
        // Get the cell for this element
        let cellId = "articleCell"
        
        var cell = tableView.dequeueReusableCell(withIdentifier: cellId)
        if cell == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: cellId)
        }
        
        // View setup (background, title, detail info and default image)
        cell?.backgroundColor = Utils.colorForTableRow(atIndex: indexPath.row)
        
        cell?.textLabel?.numberOfLines = 3
        cell?.textLabel?.lineBreakMode = .byTruncatingTail
        cell?.textLabel?.text = articleTitle!
        
        cell?.detailTextLabel?.text = detailLabelText
        
        // If there is an image associated to this article, show its thumbnai (look it up in the cache first, then download it)
        if articleHasImage! {
            
            cell?.imageView?.image = Utils.resizeImage(fromImage: UIImage(named: "news_placeholder.png")!, toFixedWidth: 70, toFixedHeight: 70)
            
            if let cachedImage = thumbsCache[articleId!] {
                cell?.imageView?.image = cachedImage
            }
            else {
                let thumbnailName = "\(articleImageName!)_thumb.jpg"
                
                Utils.downloadBlobImage(thumbnailName, fromContainer: Backend.newsImageContainerName, activityIndicator: nil) { (image: UIImage?) in
                    
                    if image != nil {
                        
                        self.thumbsCache[articleId!] = image!   // store the thumbnail image in the cache, for future use
                        
                        DispatchQueue.main.async {
                            cell?.imageView?.image = Utils.resizeImage(fromImage: image!, toFixedWidth: 70, toFixedHeight: 70)
                        }
                    }
                }
            }
        }
        else {
            cell?.imageView?.image = nil
        }
        
        return cell!
    }
}

// Implementation of the TableViewDelegate protocol
extension WriterArticlesViewController: UITableViewDelegate {
    
    // What to do when a cell is selected -> go to the article detail view
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let selectedNews = articleList?[indexPath.row]
        let newsId = selectedNews?["id"] as! String?
        
        // If the article is already submitted or published, use the read-only detail controller (ReaderNewsDetailViewController)
        if currentArticleStatus == .published || currentArticleStatus == .submitted {
            
            let detailVC = ReaderNewsDetailViewController(id: newsId!, anonymous: false, client: appClient)
            navigationController?.pushViewController(detailVC, animated: true)
        }

        // If the article is a draft, use the editable detail controller (ArticleEditorViewController)
        else {
         
            let detailVC = ArticleEditorViewController(id: newsId!, client: appClient, session: sessionInfo)
            navigationController?.pushViewController(detailVC, animated: true)
        }

    }
}


// MARK: Auxiliary functions

extension WriterArticlesViewController {
    
    // Login with Facebook credentials. If the login is successful, will attempt to load the articles
    func loginWithFacebookThenLoadArticles() {
        
        print("\nLogin with Facebook credentials...\n")
        
        appClient.login(withProvider: "facebook", parameters: nil, controller: self, animated: true) { (user, error) in
            
            if let _ = error {
                print("\nERROR: Unable to login into Facebook:\n\(error)\n")
                Utils.showCloseControllerDialog(who: self, title: "Login failure", message: "Unable to login with Facebook")
                return
            }
            
            print("\nSuccessful Facebook login with user id:\n\((user?.userId)!)\n")
            
            
            Utils.asyncGetCurrentSessionInfo(appClient: self.appClient) { (sessionInfo: SessionInfo?) in
                
                if sessionInfo == nil {
                    let dialogTitle = "Session error"
                    let dialogMsg = "Unable to get data from your current session, please try logging in again."
                    Utils.showCloseControllerDialog(who: self, title: dialogTitle, message: dialogMsg)
                    return
                }
                
                // Save the session info and update the view with it
                self.sessionInfo = sessionInfo
                self.setupUserUIElements()
                
                // Now we can ask the server for the user's articles
                self.loadArticles(originIsPullRefresh: false)
            }
        }
    }
    
    
    // Get the user's articles and show them
    func loadArticles(originIsPullRefresh: Bool) {
        
        // First, make sure there is an active session
        if appClient.currentUser == nil {
            self.stopAllActivityIndicators()
            
            print("\nERROR: unable to refresh table (no active session found).\n")
            Utils.showInfoDialog(who: self, title: "Not logged in", message: "Please use the Log in button at the navigation bar first.")
            return
        }
        
        
        // If the method was not invoked by a pull refresh, show the table activity indicator
        if !originIsPullRefresh {
            Utils.switchActivityIndicator(indicator, show: true)
        }
        
        
        // Send a request to retrieve the articles of the current type
        
        appClient.invokeAPI(Backend.myArticlesApiName,
                            body: nil,
                            httpMethod: "GET",
                            parameters: ["status": currentArticleStatus.rawValue],
                            headers: nil,
                            completion: { (result, response, error) in
                                
                                // Empty the current article list
                                self.articleList?.removeAll()
                                
                                if let _ = error {
                                    print("\nERROR: failed request to '\(Backend.myArticlesApiName)':\n\(error)\n")
                                    Utils.showInfoDialog(who: self, title: "Error", message: "Unable to load your " + self.currentArticleStatus.rawValue + " articles.")
                                    
                                    self.updateViewFromModel()
                                    return
                                }
                                
                                print("\nResponse from '\(Backend.myArticlesApiName)':\n\(result!)\n")
                                
                                // Transform the json response into a list of DatabaseRecord
                                // and add to the model only those valid records (with id, title, writer, image, visit counter and data)
                                let json = result as! [DatabaseRecord]
                                
                                for article in json {
                                    
                                    if article["id"] == nil
                                        || article["title"] == nil
                                        || article["hasImage"] == nil
                                        || article["imageName"] == nil
                                        || article["visits"] == nil
                                        || article["date"] == nil {
                                        
                                        print("\nA Json element was discarded (missing fields)\n")
                                    }
                                    else {
                                        self.articleList?.append(article)
                                    }
                                }
                                
                                // Update the view, in the main queue
                                self.updateViewFromModel()
        })
    }
    
    
    // Launches the whole process of removing the image cache, downloading the articles and updating the view
    // (to be invoked when the user starts a pull refresh)
    func pullRefreshAction() {
        
        thumbsCache.removeAll()
        loadArticles(originIsPullRefresh: true)
    }
    
    
    // Use this function to show some user data on screen, after a successful login (name, etc)
    func setupUserUIElements() {
        
        DispatchQueue.main.async {
            
            Utils.showInfoDialog(who: self, title: "Log in", message: "You are now connected as \((self.sessionInfo?.fullName)!). Enjoy!")
            
            // Additional setup
            // ...
        }
    }
    
    
    // Initial setup of the UI elements
    func setupUI() {
        
        // Add buttons to login/logout and to create new article to the navigation bar
        addNavigationButtons()
        
        // Label to show in case the table is empty
        emptyLabel.textColor = UIColor.gray
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = NSTextAlignment.center
        emptyLabel.sizeToFit()
        
        // RefreshControl to refresh the table by a pull refresh
        refreshControl = UIRefreshControl()
        refreshControl?.backgroundColor = UIColor.clear
        refreshControl?.tintColor = UIColor.black
        refreshControl?.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl?.addTarget(self, action: #selector(pullRefreshAction), for: UIControlEvents.valueChanged)
        tableView.addSubview(refreshControl!)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 100

        self.tableView.separatorStyle = .none
        
        self.tableView.backgroundView = indicator                       // ActivityIndicator to show while the table is loading
        title = "My " + currentArticleStatus.rawValue + " articles"     // Title to show
    }
    
    
    // Updates the view with data from the model, in the main queue
    // (stops all activity indicators, shows the title and the cells, and the empty label if needed)
    func updateViewFromModel() {
        
        DispatchQueue.main.async {
            self.stopAllActivityIndicators()
            self.title = "My " + self.currentArticleStatus.rawValue + " Articles"
            self.tableView.reloadData()
            self.showEmptyLabelIfNeeded()
            
            // Depending on the status we are looking for, enable/disable the status buttons
            if self.currentArticleStatus == .draft {
                self.btnDraft.isEnabled = false
                self.btnSubmitted.isEnabled = true
                self.btnPublished.isEnabled = true
            }
            
            if self.currentArticleStatus == .submitted {
                self.btnDraft.isEnabled = true
                self.btnSubmitted.isEnabled = false
                self.btnPublished.isEnabled = true
            }
            
            if self.currentArticleStatus == .published {
                self.btnDraft.isEnabled = true
                self.btnSubmitted.isEnabled = true
                self.btnPublished.isEnabled = false
            }
        }
    }
    
    
    // Stops and hides all activity indicators in the table
    // (both the standard indicator and the pull refresh indicator)
    func stopAllActivityIndicators() {
        
        Utils.stopTableRefreshing(refreshControl)
        Utils.switchActivityIndicator(self.indicator, show: false)
    }
    
    
    // If the table is empty, shows the empty label on screen.
    // Otherwise, just assigns the activity indicator as the table background.
    func showEmptyLabelIfNeeded() {
        
        DispatchQueue.main.async {
            
            if (self.articleList?.isEmpty)! {
                
                if self.appClient.currentUser == nil    {   self.emptyLabel.text = "Please log in to see your articles."    }
                else                                    {   self.emptyLabel.text = "No articles to show, please pull down to refresh."    }
                
                self.tableView.backgroundView = self.emptyLabel
            }
            else {
                
                self.tableView.backgroundView = self.indicator
            }
        }
    }
    
    
    // Create buttons (login/logout and new article) to the right in the navigation controller
    func addNavigationButtons() {
        
        let btn1 = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(newArticleAction))
        navigationItem.rightBarButtonItem = btn1
        
        let btn2 = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(toggleSessionAction))
        navigationItem.rightBarButtonItems?.append(btn2)
    }
    
    
    // What to do when the user clicks on the New article button
    func newArticleAction() {
        
        let editVC = ArticleEditorViewController(id: nil, client: appClient, session: sessionInfo)
        navigationController?.pushViewController(editVC, animated: true)
    }
    
    
    // What to do when the user clicks on the Session button
    func toggleSessionAction() {
        
        // If there was already a session, close it
        if let _ = appClient.currentUser {
            
            print("\nClosing the current Facebook session...\n")
            
            appClient.logout() { error in
                
                if let _ = error {
                    print("\nERROR: failed to finish the current Facebook session:\n\(error)\n")
                    Utils.showInfoDialog(who: self, title: "Log out Failure", message: "There was an error while trying to log out.")
                    return
                }
                
                // Apart from closing the session, it is necessary to remove cookies (otherwise, when clicking the session button again
                // the login dialog will not show, and it will attempt to login with the same last Facebook credentials)
                print("\nCookies about to be removed:\n")
                for value in HTTPCookieStorage.shared.cookies! {
                    print(value)
                }
                
                for c in HTTPCookieStorage.shared.cookies! {
                    HTTPCookieStorage.shared.deleteCookie(c)
                }
                
                
                print("\nCurrent session has been closed!\n")
                
                let byeMessage: String
                if self.sessionInfo != nil  {   byeMessage = "See you soon, \((self.sessionInfo?.firstName)!)! Press the upper button again to Log in."  }
                else                        {   byeMessage = "See you soon! Press the upper button again to Log in."  }
                Utils.showInfoDialog(who: self, title: "Log out", message: byeMessage)
                
                // Remove the session info and empty the article list
                self.sessionInfo = nil
                self.articleList?.removeAll()
                self.updateViewFromModel()
            }
        }
        
        // If there was not an active session, login into Facebook
        else {
            loginWithFacebookThenLoadArticles()
        }
    }
}
