//
//  App.swift
//  CH01_CAMetadata
//
//  Created by Oleksii Huralnyk on 11.12.2019.
//  Copyright © 2019 Oleksii Huralnyk. All rights reserved.
//

import Foundation

extension String {
    var expandingTildeInPath: String {
        return NSString(string: self).expandingTildeInPath
    }
}
