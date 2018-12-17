//
//  SQLiteManager.swift
//  BrcIot
//
//  Created by tian on 2018/12/6.
//  Copyright © 2018 tian. All rights reserved.
//

import UIKit
import CommonCrypto

public class SQLiteManager: NSObject {
    public class var publicDatabase: String { return SQLiteManager.share.publicDatabase }
    public class var privateDatabase: String? { return SQLiteManager.share.privateDatabase }
    public class var debugMode: SQLiteLogMode {
        set { SQLiteManager.share._mode = newValue }
        get { return SQLiteManager.share._mode }
    }
    public class var databaseFolder: String {
        set { SQLiteManager.share.databaseFolder = newValue }
        get { return SQLiteManager.share.databaseFolder }
    }
    
    private static let share = SQLiteManager()
    private lazy var publicDatabase: String = {
        return "public.db"
    }()
    private lazy var privateDatabase: String? = nil
    private var _mode: SQLiteLogMode = .error
    private lazy var databaseFolder: String = {
        let dir = FileManager.SearchPathDirectory.documentDirectory
        let domain = FileManager.SearchPathDomainMask.userDomainMask
        return NSSearchPathForDirectoriesInDomains(dir, domain, true).first ?? ""
    }()
    
    public class func initialize(_ identifier: String) {
        let idv = identifier.toMD5().uppercased()
        SQLiteManager.share.privateDatabase = "\(idv).db"
    }
    
    public class func prepare(_ tables: (() -> [SQLiteCodable.Type])? = nil) {
        if let allTypes = tables?() {
            for type in allTypes {
                type.createSQLiteTable()
            }
        }
    }
}

extension String {
    fileprivate func toMD5() -> String {
        let str = self.cString(using: String.Encoding.utf8)
        let strLen = CUnsignedInt(self.lengthOfBytes(using: String.Encoding.utf8))
        let digestLen = Int(CC_MD5_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<UInt8>.allocate(capacity: 16)
        CC_MD5(str!, strLen, result)
        let hash = NSMutableString()
        for i in 0 ..< digestLen {
            hash.appendFormat("%02x", result[i])
        }
        free(result)
        return String(format: hash as String)
    }
}
