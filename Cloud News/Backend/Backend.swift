//
//  Backend.swift
//  Cloud News
//
//  Created by Carlos Delgado on 27/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//  
//  This file contains all the constants needed by the app to connect to the Azure backend


import Foundation


// Alias for a generic database record
// (a dictionary where the keys are Strings, and the values can be any object)
typealias DatabaseRecord = Dictionary<String, AnyObject>


// Every article must be in one of these states (this is how it appears in the database)
enum ArticleStatus: String {
    
    case draft      = "draft"
    case submitted  = "submitted"
    case published  = "published"
}


class Backend {
    
    // Url of the Azure App Service
    static let mobileAppUrlString: String = "https://cloudnews.azurewebsites.net"
    
    // Backend API endpoints
    static let publishedNewsApiName: String = "published_news"
    static let readNewsApiName: String = "read_news"
    static let readArticleApiName: String = "read_article"
    static let sessionInfoApiName: String = "session_info"
    static let myArticlesApiName: String = "my_articles"
    static let fbGraphApiName: String = "fbapigraph_query"
    
    // Database table names
    static let newsTableName: String = "News"
    
    // Azure Storage account credentials
    static let storageAccountName: String = "cloudnewsstorage"
    static let storageKeyString: String = "vvRR0VjNHq9h74OCkqS1GRhdOSsBxF10yL7JPeqib92WzU5O9O9ciBope8mSssf8Yuq/uIOQsPVrfYCcGxkLWg=="
    
    // Name of the container for the news images
    static let newsImageContainerName: String = "news-images"
}
