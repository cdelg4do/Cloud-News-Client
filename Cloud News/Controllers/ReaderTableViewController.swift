//
//  ReaderTableViewController.swift
//  Cloud News
//
//  Created by Carlos Delgado on 27/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//
//  This controller is in charge to show the list of published news.
//  (no authentication required to visualize this list)

import UIKit


class ReaderTableViewController: UITableViewController {
    
    var appClient: MSClient                 // Azure Mobile client
    var newsList: [DatabaseRecord]? = []    // List of news to show
    var thumbsCache = [String:UIImage]()    // Thumbnails cache (by url)
    var writersCache = [String:String]()    // Author names cache (by user id)
    
    let indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)  // Table activity indicator
    let emptyLabel = UILabel()              // Label to show, in case the table is empty
    
    
    //MARK: Initializers
    
    init(client: MSClient) {
        
        self.appClient = client
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: controller lifecycle events
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        loadNews(originIsPullRefresh: false)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        thumbsCache.removeAll()
        writersCache.removeAll()
    }
    

    //MARK: - Table view data source

    // Number of sections: 1 (or 0 if there are no data to show)
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        if (newsList?.isEmpty)! {   return 0    }
        else                    {   return 1    }
    }
    
    // Number of rows in a section: as many as published news (or 0 if there are no data to show)
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if (newsList?.isEmpty)! {   return 0                    }
        else                    {   return (newsList?.count)!   }
    }
    
    
    // Setup of table cells (will show the news title, the author name, the publication date and a thumbnail image)
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Get the news data for the given position
        let thisNews = newsList?[indexPath.row]
        
        let newsId = thisNews?["id"] as! String?
        let newsTitle = thisNews?["title"] as! String?
        let newsWriterId = thisNews?["writer"] as! String?
        let newsDate = thisNews?["publishedAt"] as! NSDate?
        let hasImage = thisNews?["hasImage"] as! Bool?
        let imageName = thisNews?["imageName"] as! String?
        
        // Get the cell for this element
        let cellId = "newsCell"
        
        var cell = tableView.dequeueReusableCell(withIdentifier: cellId)
        if cell == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: cellId)
        }
        
        // View setup (background, title, author name & date)
        cell?.backgroundColor = Utils.colorForTableRow(atIndex: indexPath.row)
        
        cell?.textLabel?.numberOfLines = 3
        cell?.textLabel?.lineBreakMode = .byTruncatingTail
        cell?.textLabel?.text = newsTitle!
        
        cell?.detailTextLabel?.text = "\(Utils.dateToString(newsDate!))"
        
        // Attempt to get the author name (look it up in the cache first, then from the Facebook Graph API)
        if let cachedName = writersCache[newsId!] {
            cell?.detailTextLabel?.text = "\(cachedName), \(Utils.dateToString(newsDate!))"
        }
        else {
            Utils.asyncGetFacebookUserInfo(userId: newsWriterId!, withClient: appClient) { (user: UserInfo?) in
                
                if user != nil {
                    
                    let name = user!.fullName
                    self.writersCache[newsId!] = name   // store the provided name in the cache, for future use
                    
                    DispatchQueue.main.async {
                        cell?.detailTextLabel?.text = "\(name), \(Utils.dateToString(newsDate!))"
                    }
                }
            }
        }
        
        
        // If there is an image associated to this news, show its thumbnail (look it up in the cache first, then download it)
        if hasImage! {
            
            cell?.imageView?.image = Utils.resizeImage(fromImage: UIImage(named: "news_placeholder.png")!, toFixedWidth: 70, toFixedHeight: 70)
            
            if let cachedImage = thumbsCache[newsId!] {
                cell?.imageView?.image = cachedImage
            }
            else {
                let thumbnailName = "\(imageName!)_thumb.jpg"
                
                Utils.downloadBlobImage(thumbnailName, fromContainer: Backend.newsImageContainerName, activityIndicator: nil) { (image: UIImage?) in
                    
                    if image != nil {
                        
                        self.thumbsCache[newsId!] = image!  // store the thumbnail image in the cache, for future use
                        
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
    
    
    // What to do when a cell is selected -> go to the news detail view
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let selectedNews = newsList?[indexPath.row]
        let newsId = selectedNews?["id"] as! String?
        
        let newsDetailVC = ReaderNewsDetailViewController(id: newsId!, client: appClient)
        navigationController?.pushViewController(newsDetailVC, animated: true)
    }
    
    
    //MARK: Access to the remote data
    
    // Get the news from the server and update the view
    func loadNews(originIsPullRefresh: Bool) {
        
        // If the action was NOT triggered from a pull refresh, show the activity indicator
        if !originIsPullRefresh {
            Utils.switchActivityIndicator(indicator, show: true)
        }
        
        
        // Send a request to retrieve all the published news
        
        appClient.invokeAPI(Backend.publishedNewsApiName,
                         body: nil,
                         httpMethod: "GET",
                         parameters: nil,
                         headers: nil,
                         completion: { (result, response, error) in
                            
                            // Empty the current news list
                            self.newsList?.removeAll()
                            
                            if let _ = error {
                                print("\nERROR: failed request to '\(Backend.publishedNewsApiName)':\n\(error!)\n")
                                Utils.showInfoDialog(who: self, title: "Error", message: "Unable to load the published news.")
                                
                                self.updateViewFromModel()
                                return
                            }
                            
                            print("\nResponse from '\(Backend.publishedNewsApiName)':\n\(result!)\n")
                            
                            // Transform the json response into a list of DatabaseRecord
                            // and add to the model only those valid records (with id, title, writer, image and publication data)
                            let json = result as! [DatabaseRecord]
                            
                            for news in json {
                                
                                if news["id"] == nil
                                    || news["title"] == nil
                                    || news["writer"] == nil
                                    || news["hasImage"] == nil
                                    || news["imageName"] == nil
                                    || news["publishedAt"] == nil {
                                    
                                    print("\nA Json element was discarded (missing fields)\n")
                                }
                                else {
                                    self.newsList?.append(news)
                                }
                            }
                            
                            // Update the view (in the main queue)
                            self.updateViewFromModel()
        })
    }
    
    
    // Launches the whole process of removing the image and name caches, downloading the news and updating the view
    // (to be invoked when the user starts a pull refresh)
    func pullRefreshAction() {
        
        thumbsCache.removeAll()
        writersCache.removeAll()
        loadNews(originIsPullRefresh: true)
    }
    
    
    // MARK: auxiliary functions
    
    // Initial setup of the UI elements
    func setupUI() {
        
        // Label to show in case the table is empty
        emptyLabel.text = "No news to show right now, please pull down to refresh."
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
        
        self.tableView.backgroundView = indicator   // ActivityIndicator to show while the table is loading
        title = "Latest News"                       // Title to show
    }
    
    
    // Updates the view with data from the model, in the main queue
    // (stops all activity indicators, shows the cells and the empty label if needed)
    func updateViewFromModel() {
        
        DispatchQueue.main.async {
            self.stopAllActivityIndicators()
            self.tableView.reloadData()
            self.showEmptyLabelIfNeeded()
        }
    }
    
    
    // Stops and hides all activity indicators in the table
    // (both the standard indicator and the pull refresh indicator)
    func stopAllActivityIndicators() {
        
        Utils.stopTableRefreshing(self)
        Utils.switchActivityIndicator(self.indicator, show: false)
    }
    
    
    // If the table is empty, shows the empty label on screen.
    // Otherwise, just assigns the activity indicator as the table background.
    func showEmptyLabelIfNeeded() {
        
        DispatchQueue.main.async {
            
            if (self.newsList?.isEmpty)! {
                self.tableView.backgroundView = self.emptyLabel
            }
            else {
                self.tableView.backgroundView = self.indicator
            }
        }
    }
}
