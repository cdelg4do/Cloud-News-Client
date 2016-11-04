//
//  Errors.swift
//  Cloud News
//
//  Created by Carlos Delgado on 28/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//
//  Este fichero contiene definiciones de errores para
//  el lanzamiento de excepciones personalizada en la aplicación.
//  Se derivan de Error para que puedan ser devueltas con throw().


import Foundation


// MARK: JSON Errors

enum JsonError: Error {
    
    case wrongJSONFieldFormat
    case missingJSONField
    case nilJSONObject
}
