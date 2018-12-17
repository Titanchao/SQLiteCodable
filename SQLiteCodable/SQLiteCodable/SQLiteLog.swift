//
//  SQLiteLog.swift
//  BrcIot
//
//  Created by tian on 2018/12/12.
//  Copyright © 2018 tian. All rights reserved.
//

import UIKit

public enum SQLiteLogMode: Int {
    case verbose = 0
    case debug = 1
    case error = 2
}

class SQLiteLog {
    class func logConsole(_ console: ((_ items: Any) -> Swift.Void)? = nil) {
        SQLiteLog.share.console = console
    }
    
    private static let share = SQLiteLog()
    private var console: ((Any) -> Swift.Void)? = nil
    
    static func error(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        if SQLiteLog.share.console != nil {
            SQLiteLog.share.console!(items)
        } else if SQLiteManager.debugMode.rawValue <= SQLiteLogMode.error.rawValue {
            print(items, separator: separator, terminator: terminator)
        }
    }
    
    static func debug(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        if SQLiteLog.share.console != nil {
            SQLiteLog.share.console!(items)
        } else if SQLiteManager.debugMode.rawValue <= SQLiteLogMode.debug.rawValue {
            print(items, separator: separator, terminator: terminator)
        }
    }
    
    static func verbose(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        if SQLiteLog.share.console != nil {
            SQLiteLog.share.console!(items)
        } else if SQLiteManager.debugMode.rawValue <= SQLiteLogMode.verbose.rawValue {
            print(items, separator: separator, terminator: terminator)
        }
    }
}
