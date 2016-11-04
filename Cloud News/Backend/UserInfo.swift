//
//  UserInfo.swift
//  Cloud News
//
//  Created by Carlos Delgado on 30/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//
//  Esta clase almacena los datos publicados en el perfil de un usuario de facebook.
//  Se utiliza para mostrar alguna información del usuario en pantalla (su nombre, etc)


import Foundation


class UserInfo {
    
    let userId: String
    let fullName: String
    let email: String
    let link: URL
    
    init(id: String, fullName: String, email: String, link: URL) {
        
        self.userId = id
        self.fullName = fullName
        self.email = email
        self.link = link
    }
    
    class func validate(_ json: JsonElement) -> UserInfo? {
        
        let usr, full, mail, urlString: String?
        let url: URL?
        
        do {
            // Campos que obligatoriamente debe contener el json
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
