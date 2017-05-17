//
//  UserInfo.swift
//  Cloud News
//
//  Created by Carlos Delgado on 30/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//
//  This class encapsulates the info retrieved from the profile of a Facebook user.
//  It is useful to show some user information on screen (like the name, etc)


import Foundation


class UserInfo {
    
    let userId: String
    let fullName: String
    let email: String
    let link: URL
    
    // Class designated initializer
    init(id: String, fullName: String, email: String, link: URL) {
        
        self.userId = id
        self.fullName = fullName
        self.email = email
        self.link = link
    }
    
    
    // Builds a new UserInfo object from a valid JsonElement with the user data.
    // (if json is not a valid element, returns nil)
    
    class func validate(_ json: JsonElement) -> UserInfo? {
        
        let usr, full, mail, urlString: String?
        let url: URL?
        
        do {
            usr = json["id"] as? String
            full = json["name"] as? String
            mail = json["email"] as? String
            urlString = json["link"] as? String
            
            if usr == nil           { throw JsonError.missingJSONField }
            if full == nil          { throw JsonError.missingJSONField }
            if mail == nil          { throw JsonError.missingJSONField }
            if urlString == nil     { throw JsonError.missingJSONField }
            
            url = URL(string: urlString!)
            if url == nil          { throw JsonError.wrongJSONFieldFormat }
        }
        catch {
            return nil
        }
        
        return UserInfo(id: usr!, fullName: full!, email: mail!, link: url!)
    }
}
