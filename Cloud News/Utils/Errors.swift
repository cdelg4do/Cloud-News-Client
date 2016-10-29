//
//  Errors.swift
//  Cloud News
//
//  Created by Carlos Delgado on 28/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//

import Foundation


// MARK: JSON Errors
// Definiciones de los diferentes errores
// (derivados de Error para poder devolverlos con un throw)
enum JsonError: Error {
    
    case missingJSONField
    case nilJSONObject
}
