//
//  Backend.swift
//  Cloud News
//
//  Created by Carlos Delgado on 27/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//

import Foundation


// Tipo genérico que representa a un registro de la Base de datos
// (un diccionario cuyas claves son cadenas, y cuyos valores son cualquier tipo)
typealias DatabaseRecord = Dictionary<String, AnyObject>


class Backend {
    
    // Url del App Service de Azure
    static let mobileAppUrlString: String = "https://cloudnews.azurewebsites.net"
    
    // Endpoints de la API del servidor
    static let publishedNewsApiName: String = "published_news"
    static let readNewsApiName: String = "read_news"
    
    // Credenciales para la cuenta de Azure Storage
    static let storageAccountName: String = "cloudnewsstorage"
    static let storageKeyString: String = "vvRR0VjNHq9h74OCkqS1GRhdOSsBxF10yL7JPeqib92WzU5O9O9ciBope8mSssf8Yuq/uIOQsPVrfYCcGxkLWg=="
    
    // Container para las imágenes de las noticias
    static let newsImageContainerName: String = "news-images"
}
