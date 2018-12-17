//
//  SQLiteConfig.swift
//  BrcIot
//
//  Created by tian on 2018/12/6.
//  Copyright © 2018 tian. All rights reserved.
//

import UIKit

public protocol SQLiteConfig {
    static func isPublicDatabase() -> Bool
    static func tableName() -> String
    static func databaseName() -> String
    static func databasePath() -> String
    static func databaseVersion() -> String
}

extension SQLiteConfig {
    public static func isPublicDatabase() -> Bool {
        return false
    }
    
    public static func tableName() -> String {
        let tbn = String(describing: type(of: Self.self)).components(separatedBy: ".").first?.lowercased() ?? "\(arc4random())"
        return tbn + "_" + databaseVersion()
    }
    
    public static func databaseName() -> String {
        if self.isPublicDatabase() {
            return SQLiteManager.publicDatabase
        } else {
            assert(SQLiteManager.privateDatabase != nil, "private sqlite3 need identifier")
            return SQLiteManager.privateDatabase!
        }
    }
    
    public static func databasePath() -> String {
        return (SQLiteManager.databaseFolder as NSString).appendingPathComponent(self.databaseName())
    }
    
    //don't contain '.'
    public static func databaseVersion() -> String {
        return "01"
    }
}

