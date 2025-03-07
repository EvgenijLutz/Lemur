//
//  LemurError.swift
//  Lemur
//
//  Created by Evgenij Lutz on 02.03.25.
//

import Foundation


enum LemurError: Error, Sendable {
    case cannotCreateTexture
    case couldNotGetTextureContentsToCopy
    
    case cannotCreateBuffer
    case couldNotGetBufferContentsToCopy
}
