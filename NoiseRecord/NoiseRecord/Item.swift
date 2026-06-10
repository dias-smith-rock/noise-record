//
//  Item.swift
//  NoiseRecord
//
//  Created by Rock on 10/6/2026.
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
