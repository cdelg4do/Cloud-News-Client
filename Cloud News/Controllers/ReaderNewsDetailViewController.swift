//
//  ReaderNewsDetailViewController.swift
//  Cloud News
//
//  Created by Carlos Delgado on 27/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//
//  This controller shows a read-only view of an article.
//  
//  The value of 'anonymous' in the init() determines what API will be invoked to get the remote data:
//
//  - true:     read_news       (for anonymous users, only can show published articles and increments the view counter)
//  - false:    read_articles   (for authenticated users, can any article as long as it belongs to the user, and does not increment the view counter)


import UIKit
import CoreLocation


class ReaderNewsDetailViewController: UIViewController {
    
    @IBOutlet weak var mainView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var viewsLabel: UILabel!
    @IBOutlet weak var newsImage: UIImageView!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var newsText: UITextView!
    @IBOutlet weak var imageIndicator: UIActivityIndicatorView!
   
    
    var appClient: MSClient
    var currentNewsId: String
    var currentNews: DatabaseRecord?
    let useAnonymousApi: Bool
    
    
    //MARK: Initializers
    
    init(id: String, anonymous: Bool, client: MSClient) {
        
        self.currentNewsId = id
        self.useAnonymousApi = anonymous
        self.appClient = client
        
        super.init(nibName: nil, bundle: nil)
    }
    
    convenience init(id: String, client: MSClient) {
        
        self.init(id: id, anonymous: true, client: client)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    //MARK: controller lifecycle events
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // All views in the controller will hide til the article is loaded
        Utils.changeSubviewsVisibility(ofView: mainView, hide: true)
        
        loadNewsDetail()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    
    //MARK: Acceso to the remote data
    
    // Download the article data from the server invoking the appropriate api, then show it on screen
    func loadNewsDetail() {
        
        let remoteApi: String
        
        if (useAnonymousApi)    {   remoteApi = Backend.readNewsApiName     }   // Anonymous user, published articles only
        else                    {   remoteApi = Backend.readArticleApiName  }   // Authenticated user
        
        appClient.invokeAPI(remoteApi,
                            body: nil,
                            httpMethod: "GET",
                            parameters: ["newsId": currentNewsId],
                            headers: nil,
                            completion: { (result, response, error) in
                                
                                if let _ = error {
                                    print("\nERROR: failed request to '\(remoteApi)':\n\(error)\n")
                                    Utils.showCloseControllerDialog(who: self, title: "Error", message: "Unable to retrieve remote data, please try again.")
                                    return
                                }
                                
                                print("\nResponse from '\(remoteApi)':\n\(result!)\n")
                                
                                // Transform the json response into a list of DatabaseRecord and count the results
                                let json = result as! [DatabaseRecord]
                                
                                if json.count == 0 {
                                    
                                    Utils.showCloseControllerDialog(who: self, title: "Error", message: "This article is not available anymore, please try refreshing the list.")
                                    return
                                }
                                
                                self.currentNews = json.first
                                
                                DispatchQueue.main.async    {
                                    self.syncViewFromModel()
                                }
        })
    }
    
    
    // Updates the view with the data from the model
    func syncViewFromModel() {
        
        let titleString, authorString, imageName, content: String?
        let hasImage: Bool?
        let newsDate: NSDate?
        let viewCount: Int?
        var newsLocation: CLLocation? = nil
        
        // Validate the data sent by the server
        do {
            guard let thisNews = currentNews   else { throw JsonError.nilJSONObject }
            
            titleString = thisNews["title"] as? String
            authorString = thisNews["writer"] as? String
            newsDate = thisNews["date"] as? NSDate
            viewCount = thisNews["visits"] as? Int
            content = thisNews["text"] as? String
            hasImage = thisNews["hasImage"] as? Bool
            imageName = thisNews["imageName"] as? String
            
            if titleString == nil   { throw JsonError.missingJSONField }
            if authorString == nil  { throw JsonError.missingJSONField }
            if newsDate == nil      { throw JsonError.missingJSONField }
            if viewCount == nil     { throw JsonError.missingJSONField }
            if content == nil       { throw JsonError.missingJSONField }
            if hasImage == nil      { throw JsonError.missingJSONField }
            if imageName == nil     { throw JsonError.missingJSONField }
            
            // Optional fields
            let lat = thisNews["latitude"] as? Double
            let long = thisNews["longitude"] as? Double
            
            if lat != nil && long != nil {  newsLocation = CLLocation(latitude: lat!, longitude: long!) }
        }
        catch {
            print("\nERROR The Json response sent by the server is not valid\n")
            Utils.showCloseControllerDialog(who: self, title: "Error", message: "Incorrect server response, please try again.")
            return
        }
        
        // Update the views
        titleLabel.text = titleString
        dateLabel.text = Utils.dateToString(newsDate!)
        newsText.text = content
        
        authorLabel.text = "<Resolving author name...>"   // will be resolved later
        authorLabel.alpha = 0;
        
        if useAnonymousApi  {   viewsLabel.text = "\(viewCount!+1) views"   }
        else                {   viewsLabel.text = "\(viewCount!) views"     }
        
        if newsLocation != nil  {   locationLabel.text = "Resolving location..."}
        else                    {   locationLabel.text = "(Unknown location)"   }
        
        
        // Now we can make the views visible
        Utils.changeSubviewsVisibility(ofView: mainView, hide: false)
        
        
        // Views to be updated asynchronously: author name, address and image
        
        Utils.asyncGetFacebookUserInfo(userId: authorString!, withClient: appClient) { (userInfo: UserInfo?) in
            
            if userInfo != nil {
                let authorName = userInfo!.fullName
                self.authorLabel.text = "by " + authorName
                self.authorLabel.alpha = 1;
            }
        }
        
        
        if newsLocation != nil {
            
            Utils.asyncReverseGeolocation(location: newsLocation!) { (address: String?) in
                
                if address != nil { self.locationLabel.text = address   }
                else              { self.locationLabel.text = "(Unknown location)"   }
            }
        }
        
        if hasImage! {
            
            Utils.switchActivityIndicator(imageIndicator, show: true)
            
            Utils.downloadBlobImage("\(imageName!).jpg", fromContainer: Backend.newsImageContainerName, activityIndicator: nil) { (image: UIImage?) in
                
                if image != nil {
                    
                    let resizedImage = Utils.resizeImage(image!, toSize: Utils.screenSize())
                    
                    DispatchQueue.main.async { self.newsImage.image = resizedImage }
                }
                
                Utils.switchActivityIndicator(self.imageIndicator, show: false)
            }
        }
        
        // If there is no image to show, hide and resize it to 1x1 (to save screen space)
        else {
            self.newsImage.isHidden = true
            self.newsImage.image = Utils.resizeImage(fromImage: UIImage(named: "news_placeholder.png")!, toFixedWidth: 1, toFixedHeight: 1)
        }
    }

}




