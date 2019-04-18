//
//  SQLiteManager.swift
//  Codable
//
//  Created by tian on 2019/4/8.
//  Copyright © 2019 tian. All rights reserved.
//

import UIKit
import CommonCrypto

public class SQLiteManager: NSObject {

    public class var debug: Bool {
        set { SQLiteManager.share.debugModel = newValue }
        get { return SQLiteManager.share.debugModel }
    }
    
    //数据库存放的位置，默认为沙盒跟目录
    public class var databaseFolder: String {
        set { SQLiteManager.share.databaseFolder = newValue }
        get { return SQLiteManager.share.databaseFolder }
    }
    
    //设置环境变量，公用和私有数据库都根据值改变，一般用来区分development和distribution，默认default
    public class func setEnvironment(_ env: String) {
        SQLiteManager.share.envStr = env
    }
    
    //设置私有数据库标识，一般用来区分不同账号，
    public class func initPrivate(_ identifier: String) {
        SQLiteManager.share.privateId = identifier
    }
    
    //公用数据库文件名
    public class var publicDatabase: String {
        return SQLiteManager.share.publicDatabase
    }
    
    //私有数据库文件名
    public class var privateDatabase: String {
        return SQLiteManager.share.privateDatabase
    }
    
    //初始化数据库表，
    public class func prepare(_ tables: (() -> SQLiteCodable.Type)? = nil) {
    
    }
    
    private static let share = SQLiteManager()
    private var envStr = "default"
    private var privateId = "private"
    private var debugModel = false
    
    private lazy var databaseFolder: String = {
        let dir = FileManager.SearchPathDirectory.documentDirectory
        let domain = FileManager.SearchPathDomainMask.userDomainMask
        return NSSearchPathForDirectoriesInDomains(dir, domain, true).first ?? ""
    }()
    
    private lazy var publicDatabase: String = {
        return envStr + "_public.db"
    }()
    
    private lazy var privateDatabase: String = {
        return (envStr + privateId).toSQLiteMD5().uppercased() + ".db"
    }()
}

extension String {
    func toSQLiteMD5() -> String {
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
