//
//  SQLiteCodable.swift
//  Codable
//
//  Created by tian on 2019/4/8.
//  Copyright © 2019 tian. All rights reserved.
//

import UIKit
import GRDB

public protocol SQLiteCodable: HandyJSON {
    
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
    
    public func declareKeys(mapper: SQLiteMapper) {}
}

//MARK: - 插入
extension SQLiteCodable {
    public static func insert(_ models: [SQLiteCodable], update: Bool = true) {
        createSQLiteTable()
        for model in models {
            var attrs = getSQLiteAttributes()
            guard let dict = model.toJSON() else {
                continue
            }
            attrs = sqliteAttributesWithKeyValue(attrs: attrs, dict: dict)
            if attrs.count > 0 {
                let order = insertStatement(attrs, replace: update)
                write(order: order.0, arguments: order.1)
            }
        }
    }
    
    private static func insertStatement(_ attrs: [SQLiteAttribute], replace: Bool) -> (String, [Any]) {
        var order = "INSERT OR \(replace ? "REPLACE" : "IGNORE") INTO \(self.tableName()) ("
        var suffix = "VALUES ("
        var param: [Any] = []
        for attr in attrs {
            if let value = attr.value {
                order += "\(attr.key),"
                suffix += "?,"
                param.append(value)
            }
        }
        order = order._fromIndex(-1) + ") "
        suffix = suffix._fromIndex(-1) + ")"
        return (order + suffix, param)
    }
}

//MARK: - 删除
extension SQLiteCodable {
    public static func deleteSQLiteAll() {
        write(order: "DELETE FROM \(tableName())", arguments: [])
    }
    
    public static func deleteSQLite(_ models: [SQLiteCodable]) {
        for model in models {
            model.deleteSQLite()
        }
    }
    
    public func deleteSQLite() {
        let attrs = Self.getSQLiteAttributes()
        var condition: [String: Any] = [:]
        for attr in  attrs {
            if attr.isPrimary || attr.isUnique {
                condition[attr.key] = attr.value
                break
            }
        }
        if condition.count > 0 {
            Self.deleteSQLiteCondition(condition)
        } else {
            print("delete failed: \(self)")
        }
    }
    
    static func deleteSQLiteCondition(_ condition: [String: Any]) {
        guard condition.count > 0 else {
            print("delete failed: no condition ")
            return
        }
        let order = deleteStatement(condition: condition)
        write(order: order.0, arguments: order.1)
    }
    
    private static func deleteStatement(condition: [String: Any]) -> (String, [Any]) {
        var order = "DELETE FROM \(tableName()) WHERE"
        var param: [Any] = []
        for (k,v) in condition {
            order += " \(k) = ? AND"
            param.append(v)
        }
        order = order.prefix(order.count - 4) + ""
        return (order, param)
    }
}

//MARK: - 修改
extension SQLiteCodable {
    public func updateSQLite() {
        let attrs = Self.getSQLiteAttributes()
        var condition: [String: Any] = [:]
        var arguments: [String: Any] = [:]
        for attr in  attrs {
            if attr.isPrimary || attr.isUnique {
                condition[attr.key] = attr.value
            } else {
                arguments[attr.key] = attr.value
            }
        }
        Self.update(condition: condition, arguments: arguments)
    }
    
    static func update(condition: [String: Any], arguments: [String: Any]) {
        guard condition.count > 0,arguments.count > 0 else {
            print("update error: \(condition)->\(arguments)")
            return
        }
        var order = "UPDATE \(tableName()) SET"
        var suffix = " WHERE"
        var param = [Any]()
        for (k,v) in arguments {
            order += " \(k) = ? ,"
            param.append(v)
        }
        for (k,v) in condition {
            suffix += " \(k) = ? AND"
            param.append(v)
        }
        write(order: order._fromIndex(-2) + suffix._fromIndex(-4), arguments: param)
    }
}

//MARK: - 查询
extension SQLiteCodable {
    public static func selectOne(ascending: Bool = false, condition: [String: Any]? = nil) -> Self? {
        let order = selectStatement(condition: condition, ascending: ascending, one: true)
        if let dict = read(order: order.0, arguments: order.1, one: true) as? [String: Any] {
            return create(sqliteDict: dict)
        } else {
            return nil
        }
    }
    
    public static func selectAll(ascending: Bool = false, condition: [String: Any]? = nil) -> [Self] {
        let order = selectStatement(condition: condition, ascending: ascending, one: false)
        if let dicts = read(order: order.0, arguments: order.1, one: false) as? [[String: Any]] {
            return dicts.map({ (dict) -> Self? in
                return create(sqliteDict: dict)
            }) as? [Self] ?? []
        }
        return []
    }
    
    private static func selectStatement(condition: [String: Any]?, ascending: Bool, one: Bool) -> (String, [Any]) {
        var order = "SELECT * FROM \(tableName())"
        var param = [Any]()
        if condition != nil {
            order += " WHERE"
            for (k,v) in condition! {
                order += " \(k) = ? AND"
                param.append(v)
            }
            order = order._fromIndex(-4)
        }
        order += " ORDER BY ROWID \(ascending ? "ASC" : "DESC")"
        order += one ? " LIMIT 0,1" : ""
        return (order, param)
    }
    
    static func create(sqliteDict: [String: Any]) -> Self? {
        let attrs = getSQLiteAttributes()
        var kattrs = [String: SQLiteAttribute]()
        for attr in attrs {
            kattrs[attr.key] = attr
        }
        
        var kv = [String: Any]()
        for (k,v) in sqliteDict {
            if let attr = kattrs[k] {
                kv[attr.dictKey] = v
            }
        }
        return Self.deserialize(from: assembleComplex(kv))
    }
}

fileprivate func sqliteAttributesWithKeyValue(attrs: [SQLiteAttribute], dict: [String: Any]) -> [SQLiteAttribute] {
    let keyValue = splitSimple(dict)
    var result = [SQLiteAttribute]()
    for attr in attrs {
        if let value = keyValue[attr.dictKey] {
            let retAttr = attr.mutableCopy()
            retAttr.value = value
            result.append(retAttr)
        }
    }
    return result
}

//MARK: - 读写操作
extension SQLiteCodable {
    public static func write(order: String, arguments: [Any]) {
        do {
            let dbQueue = try sqliteQueue()
            try dbQueue.write({ db in
                if let args = StatementArguments(arguments) {
                    try db.execute(sql: order, arguments: args)
                } else {
                    try db.execute(sql: order)
                }
            })
        } catch { print(error) }
    }
    
    public static func read(order: String, arguments: [Any], one: Bool) -> Any? {
        do {
            let dbQueue = try sqliteQueue(readonly: true)
            if let args = StatementArguments(arguments) {
                return try dbQueue.read({ db -> Any? in
                    return one ? try Row.fetchOne(db, sql: order, arguments: args)?.toJSON() : try Row.fetchAll(db, sql: order, arguments: args).map({ (r) -> Any in
                        return r.toJSON()
                    })
                })
            } else {
                return try dbQueue.read({ db -> Any? in
                    return one ? try Row.fetchOne(db, sql: order)?.toJSON() : try Row.fetchAll(db, sql: order).map({ (r) -> Any in
                        return r.toJSON()
                    })
                })
            }
        } catch {
            print(error)
            return nil
        }
    }
}

extension Row {
    fileprivate func toJSON() -> [String: Any] {
        var result = [String: Any]()
        for (k,v) in self {
            result[k] = v.storage.value
        }
        return result
    }
}

//MARK: - 创建删除
extension SQLiteCodable {
    private static func databasePath() -> String {
        let dbName = self.isPublicDatabase() ? SQLiteManager.publicDatabase : SQLiteManager.privateDatabase
        return (SQLiteManager.databaseFolder as NSString).appendingPathComponent(dbName)
    }
    
    private static func sqliteQueue(readonly: Bool = false) throws -> DatabaseQueue {
        var config = Configuration()
        if SQLiteManager.debug { config.trace = { print($0) } }
        config.readonly = readonly
        config.label = databasePath().toSQLiteMD5().lowercased()
        return try DatabaseQueue(path: databasePath(), configuration: config)
    }
    
    public static func createSQLiteTable() {
        do {
            let dbQueue = try sqliteQueue()
            try dbQueue.write({ (db) in
                if try db.tableExists(tableName()) == false {
                    let attrs = getSQLiteAttributes()
                    try db.create(table: tableName(), ifNotExists: true, body: { (t) in
                        for attr in attrs {
                            if let ct = attr.columeType {
                                let c = t.column(attr.key, Database.ColumnType(ct))
                                if attr.isPrimary { c.primaryKey() }
                                if attr.isUnique { c.unique() }
                                if attr.isNotNull,
                                    let v = attr.value,
                                    let dv = DatabaseValue(value: v) {
                                    c.notNull()
                                    c.defaults(to: dv)
                                }
                            }
                        }
                    })
                }
            })
            
        } catch { print(error) }
    }
}

fileprivate extension String {
    //index 大于等于0从左边开始，小于0从右边开始
    func _toIndex(_ index: Int) -> String {
        if index < 0 {
            return String(self.suffix(-index))
        } else {
            return String(self.prefix(index))
        }
    }
    
    //index 大于等于0从左边开始，小于0从右边开始
    func _fromIndex(_ index: Int) -> String {
        if index < 0 {
            return String(self.prefix(max(self.count + index, 0)))
        } else {
            return String(self.suffix(max(self.count - index, 0)))
        }
    }
}

