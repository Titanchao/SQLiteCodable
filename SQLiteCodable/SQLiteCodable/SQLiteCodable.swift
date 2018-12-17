//
//  SQLiteCodable.swift
//  BrcIot
//
//  Created by tian on 2018/12/11.
//  Copyright © 2018 tian. All rights reserved.
//

import UIKit
import GRDB

public protocol SQLiteCodable: SQLiteConfig, SQLiteTransformable {
    init()
    func declareKeys(mapper: SQLiteMapper)
    
}

extension SQLiteCodable {
    func declareKeys(mapper: SQLiteMapper) {}
}

extension SQLiteCodable {
    public static func insert(_ models: [SQLiteCodable], update: Bool = true) {
        for model in models {
            let attrs = getSQLiteAttributes(object: model)
            let order = insertStatement(attrs, replace: update)
            write(order: order.0, arguments: order.1)
        }
    }
    
    private static func insertStatement(_ attrs: [SQLiteAttribute], replace: Bool) -> (String, [Any]) {
        var order = "INSERT OR \(replace ? "REPLACE" : "IGNORE") INTO \(self.tableName()) ("
        var suffix = "VALUES ("
        var param: [Any] = []
        for attr in attrs {
            if let value = attr.value{
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
        let attrs = Self.getSQLiteAttributes(object: self)
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
            SQLiteLog.error("delete failed: \(self)")
        }
    }
    
    static func deleteSQLiteCondition(_ condition: [String: Any]) {
        guard condition.count > 0 else {
            SQLiteLog.error("delete failed: no condition ")
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

extension SQLiteCodable {
    public func updateSQLite() {
        let attrs = Self.getSQLiteAttributes(object: self)
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
            SQLiteLog.error("update error: \(condition)->\(arguments)")
            return
        }
        var order = "UPDATE \(tableName()) SET"
        var suffix = " WHERE"
        var param = [Any]()
        for (k,v) in arguments {
            order += " \(k) = ? AND"
            param.append(v)
        }
        for (k,v) in condition {
            suffix += " \(k) = ? AND"
            param.append(v)
        }
        write(order: order._fromIndex(-4) + suffix._fromIndex(-4), arguments: param)
    }
}

extension SQLiteCodable {
    public static func selectOne(ascending: Bool = false, condition: [String: Any]? = nil) -> Self? {
        let order = selectStatement(condition: condition, ascending: ascending, one: true)
        if let dict = read(order: order.0, arguments: order.1, one: true) as? [String: Any] {
            return sqlTransform(simple: dict)
        } else {
            return nil
        }
    }
    
    public static func selectAll(ascending: Bool = false, condition: [String: Any]? = nil) -> [Self] {
        let order = selectStatement(condition: condition, ascending: ascending, one: false)
        if let dicts = read(order: order.0, arguments: order.1, one: false) as? [[String: Any]] {
            return dicts.map({ (dict) -> Self? in
                return sqlTransform(simple: dict)
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
}

extension SQLiteCodable {
    public static func write(order: String, arguments: [Any]) {
        do {
            let dbQueue = try sqliteQueue()
            try dbQueue.write({ db in
                try db.execute(order, arguments: StatementArguments(arguments))
            })
        } catch { SQLiteLog.error(error) }
    }
    
    public static func read(order: String, arguments: [Any], one: Bool) -> Any? {
        do {
            let dbQueue = try sqliteQueue(readonly: true)
            let args = StatementArguments(arguments)
            return try dbQueue.read({ db -> Any? in
                return one ? try Row.fetchOne(db, order, arguments: args)?.toJSON() : try Row.fetchAll(db, order, arguments: args).map({ (r) -> Any in
                    return r.toJSON()
                })
            })
        } catch {
            SQLiteLog.error(error)
            return nil
        }
    }
}

extension Row {
    fileprivate func toJSON() -> [String: Any] {
        var result = [String: Any]()
        for (k,v) in self {
            result[k] = v
        }
        return result
    }
}

extension SQLiteCodable {
    private static func sqliteQueue(readonly: Bool = false) throws -> DatabaseQueue {
        var config = Configuration()
        config.trace = { SQLiteLog.verbose($0) }
        config.label = databaseName()
        config.readonly = readonly
        return try DatabaseQueue(path: databasePath(), configuration: config)
    }
    
    public static func createSQLiteTable() {
        do {
            let dbQueue = try sqliteQueue()
            try dbQueue.write { (db) in
                if try db.tableExists(tableName()) == false {
                    let attrs = getSQLiteAttributes(supplement: true)
                    try db.create(table: tableName(), ifNotExists: true, body: { (t) in
                        for attr in attrs {
                            if let ct = attr.columeType {
                                let c = t.column(attr.key, Database.ColumnType(ct))
                                if attr.isPrimary { c.primaryKey() }
                                if attr.isUnique { c.unique() }
                                if attr.isNotNull { c.notNull() }
                                if let v = attr.value,let dv = DatabaseValue(value: v) {
                                    c.defaults(to: dv)
                                }
                            }
                        }
                    })
                }
            }
        } catch { SQLiteLog.error(error) }
    }
    
    private static func dropSQLiteTable() {
        do {
            let dbQueue = try sqliteQueue()
            try dbQueue.write { (db) in
                try db.drop(table: tableName())
            }
        } catch { SQLiteLog.error(error) }
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
