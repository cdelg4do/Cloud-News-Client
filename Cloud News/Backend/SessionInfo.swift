//
//  UserInfo.swift
//  Cloud News
//
//  Created by Carlos Delgado on 30/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//
//  Esta clase representa un contenedor con los datos de una sesión activa
//  para un usuario autenticado con el provedoor externo (Facebook)

import Foundation


// Tipo genérico que representa a un elemento JSON
typealias JsonElement = Dictionary<String, AnyObject>


class SessionInfo {
    
    let userId: String
    let accessToken: String
    let firstName: String
    let fullName: String
    let email: String
    let birthday: Date
    let link: URL
    
    // Inicializador designado de la clase
    init(id: String, token: String, firstName: String, fullName: String, email: String, birthday: Date, link: URL) {
        
        self.userId = id
        self.accessToken = token
        self.firstName = firstName
        self.fullName = fullName
        self.email = email
        self.birthday = birthday
        self.link = link
    }
    
    // Devuelve un nuevo objeto de la clase con los datos del elemento json indicado,
    // si dicho elemento es correcto. Si no lo es, devuelve nil.
    class func validate(_ json: JsonElement) -> SessionInfo? {
        
        let usr, tok, name, full, mail, bdayString, urlString: String?
        let bday: Date?
        let url: URL?
        
        do {
            // Campos que obligatoriamente debe contener el json
            usr = json["id"] as? String
            tok = json["token"] as? String
            name = json["firstName"] as? String
            full = json["fullName"] as? String
            mail = json["email"] as? String
            bdayString = json["birthday"] as? String
            urlString = json["link"] as? String
            
            if usr == nil           { throw JsonError.missingJSONField }
            if tok == nil           { throw JsonError.missingJSONField }
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
            if url == nil           { throw JsonError.wrongJSONFieldFormat }
        }
        catch {
            return nil
        }
        
        return SessionInfo(id: usr!, token: tok!, firstName: name!, fullName: full!, email: mail!, birthday: bday!, link: url!)
    }
    
}
