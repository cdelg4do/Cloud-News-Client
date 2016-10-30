//
//  UserInfo.swift
//  Cloud News
//
//  Created by Carlos Delgado on 30/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//

import Foundation


// Tipo genérico que representa a un elemento JSON
typealias JsonElement = Dictionary<String, AnyObject>


class UserInfo {
    
    let firstName: String
    let fullName: String
    let email: String
    let birthday: Date
    let link: URL
    
    init(firstName: String, fullName: String, email: String, birthday: Date, link: URL) {
        
        self.firstName = firstName
        self.fullName = fullName
        self.email = email
        self.birthday = birthday
        self.link = link
    }
    
    class func validate(_ json: JsonElement) -> UserInfo? {
        
        let name, full, mail, bdayString, urlString: String?
        let bday: Date?
        let url: URL?
        
        do {
            // Campos que obligatoriamente debe contener el json
            name = json["firstName"] as? String
            full = json["fullName"] as? String
            mail = json["email"] as? String
            bdayString = json["birthday"] as? String
            urlString = json["link"] as? String
            
            if name == nil          { throw JsonError.missingJSONField }
            if full == nil          { throw JsonError.missingJSONField }
            if mail == nil          { throw JsonError.missingJSONField }
            if bdayString == nil    { throw JsonError.missingJSONField }
            if urlString == nil     { throw JsonError.missingJSONField }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
            bday = formatter.date(from: bdayString!)
            if bday == nil          { throw JsonError.wrongJSONFieldFormat }
            
            url = URL(string: urlString!)
            if url == nil          { throw JsonError.wrongJSONFieldFormat }
        }
        catch {
            return nil
        }
        
        return UserInfo(firstName: name!, fullName: full!, email: mail!, birthday: bday!, link: url!)
    }
    
}
