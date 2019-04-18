//
//  SQLiteCodable.swift
//  Codable
//
//  Created by tian on 2019/4/8.
//  Copyright © 2019 tian. All rights reserved.
//

import UIKit
import GRDB

public protocol SQLiteCodable: Codable, FetchableRecord, PersistableRecord {
    
    init()
    //是否公用数据库，如果是，只区分setEnvironment(_:)，不区分initPrivate(_:)
    //如果不是，都区分，默认为false
    static func isPublicDatabase() -> Bool
    
    //类版本号，类结构发生变化一定要改变此值，默认A0，不可包含'.'
    static func databaseVersion() -> String
    
    func declareKeys(mapper: SQLiteMapper)
}

extension SQLiteCodable {
    
    public static func isPublicDatabase() -> Bool {
        return false
    }
    
    public static func tableName() -> String {
        let tbn = String(describing: type(of: Self.self)).components(separatedBy: ".").first?.lowercased() ?? "\(arc4random())"
        //00为内置版本，重大升级用
        return tbn + "_" + databaseVersion()
    }
    
    public static func databaseVersion() -> String {
        return "A0"
    }
    
    static var databaseTableName: String {
        return tableName()
    }
    
    public func declareKeys(mapper: SQLiteMapper) {}
}


//MARK: - 创建删除
extension SQLiteCodable {
    static func databasePath() -> String {
        let dbName = self.isPublicDatabase() ? SQLiteManager.publicDatabase : SQLiteManager.privateDatabase
        return (SQLiteManager.databaseFolder as NSString).appendingPathComponent(dbName)
    }
    
    public static func sqliteQueue(readonly: Bool = false) throws -> DatabaseQueue {
        var config = Configuration()
        if SQLiteManager.debug { config.trace = { print($0) } }
        config.readonly = readonly
        config.label = databasePath().toSQLiteMD5().lowercased()
        return try DatabaseQueue(path: databasePath(), configuration: config)
    }
    
    public static func createTableIfNotExists(_ db: Database) throws {
        if try db.tableExists(databaseTableName) == false {
            let columns = getSQLiteColumns()
            try db.create(table: databaseTableName, ifNotExists: true, body: { (t) in
                for col in columns {
                    col.create(t)
                }
            })
        }
    }
}

//MARK: - 增加
extension SQLiteCodable {
    public static func insert(_ models: [SQLiteCodable], update: Bool = false) {
        do {
            let dbQueue = try sqliteQueue()
            try dbQueue.write { db in
                try createTableIfNotExists(db)
                if update {
                    for model in models {
                        try model.save(db)
                    }
                } else {
                    for model in models {
                        try model.insert(db)
                    }
                }
            }
        } catch { print(error) }
    }
}

//MARK: - 删除
extension SQLiteCodable {
    public static func delete(_ models: [SQLiteCodable]) {
        do {
            let dbQueue = try sqliteQueue()
            try dbQueue.write { db in
                for model in models {
                    try model.delete(db)
                }
            }
        } catch { print(error) }
    }
}

//MARK: - 修改
extension SQLiteCodable {
    public static func update(_ models: [SQLiteCodable]) {
        do {
            let dbQueue = try sqliteQueue()
            try dbQueue.write { db in
                for model in models {
                    try model.update(db)
                }
            }
        } catch { print(error) }
    }
}

//MARK: - 查询
extension SQLiteCodable {
    public static func selectOne(ascending: Bool = false) -> Self? {
        do {
            let dbQueue = try sqliteQueue()
            return try dbQueue.read { (db) -> Self? in
                if ascending {
                    if let row = try Row.fetchOne(db, sql: "SELECT * FROM \(databaseTableName) ORDER BY ROWID DESC") {
                        return Self.init(row: row)
                    } else {
                        return nil
                    }
                } else {
                    return try Self.fetchOne(db)
                }
            }
        } catch {
            print(error)
            return nil
        }
    }
}
