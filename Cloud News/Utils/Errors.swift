//
//  Errors.swift
//  Cloud News
//
//  Created by Carlos Delgado on 28/10/16.
//  Copyright © 2016 cdelg4do. All rights reserved.
//
// This file contains the definition of errors that can be thrown during the execution
// (all derived from Error, so that they can be returned with throw)

import Foundation


// MARK: JSON Errors

enum JsonError: Error {
    
    case wrongJSONFieldFormat
    case missingJSONField
    case nilJSONObject
}
