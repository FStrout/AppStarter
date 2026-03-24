//
//  Item.swift
//  AppStarter
//
//  Created by Fred Strout on 3/24/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
