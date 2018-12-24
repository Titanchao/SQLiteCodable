//
//  SQLiteMill.swift
//  BrcIot
//
//  Created by tian on 2018/12/14.
//  Copyright © 2018 tian. All rights reserved.
//

import UIKit

fileprivate let kConnector = "$_"

extension SQLiteCodable {
    public func getSQLieKeyValue() -> [String: Any] {
        let attrs = Self.getSQLiteAttributes(object: self)
        var result = [String: Any]()
        for attr in attrs {
            result[attr.key] = attr.key
        }
        return result
    }
    
    func _sqlPlainValue() -> Any? {
        return Self._sqlSerializeAny(object: self)
    }
    
    static func _sqlSerializeAny(object: SQLiteTransformable) -> Any? {
        let mirror = Mirror(reflecting: object)
        guard let displayStyle = mirror.displayStyle else {
            return object.sqlPlainValue()
        }
        if displayStyle == .class {
            if !(object is SQLiteCodable) {
                return object
            }
            guard let attributes = SQLiteAttribute.getAttributes(forType: type(of: object)) else {
                return nil
            }
            var mutableObject = object as! SQLiteCodable
            let instanceIsNSObject = mutableObject.isNSObjectType()
            let head = mutableObject.headPointer()
            let bridgedAttribute = mutableObject.getBridgedAttributeList()
            let attrs = attributes.map { (attr) -> SQLiteAttribute in
                attr.address = head.advanced(by: attr.offset)
                attr.bridged = instanceIsNSObject && bridgedAttribute.contains(attr.key)
                return attr
            }
            return attrs
        } else {
            return object.sqlPlainValue()
        }
    }
    
    private static func getCreateAttributes(object: SQLiteCodable? = nil, prefix: String = "") -> [SQLiteAttribute] {
        let obj = object ?? Self.init()
        var result = [SQLiteAttribute]()
        let mapper = SQLiteMapper()
        obj.declareKeys(mapper: mapper)
        if let attrs = _sqlSerializeAny(object: obj) as? [SQLiteAttribute] {
            let work = (Bundle.main.infoDictionary?["CFBundleExecutable"] as? String) ?? ""
            for attr in attrs {
                let subObj = NSClassFromString("\(work).\(attr.typeName)")?.alloc()
                if let typeValue = subObj as? SQLiteCodable {
                    let subAttrs = getCreateAttributes(object: typeValue, prefix: prefix + attr.key + kConnector)
                    result.append(contentsOf: subAttrs)
                } else {
                    attr.key = prefix + attr.key
                    if attr.address == nil || mapper.isIgnoreKey(key: attr.address!.hashValue) {
                        continue
                    }
                    if mapper.isPirmary(key: attr.address!.hashValue) && prefix == "" {
                        attr.isPrimary = true
                    }
                    if mapper.isUnique(key: attr.address!.hashValue) {
                        attr.isUnique = true
                    }
                    result.append(attr)
                }
            }
        }
        return result
    }
    
    static func getSQLiteAttributes(object: SQLiteCodable? = nil, supplement: Bool = false) -> [SQLiteAttribute] {
        let obj = object ?? Self.init()
        let mirror = Mirror(reflecting: obj)
        let kv = getSQLiteKeyValue(mirror: mirror)
        let attrs = getCreateAttributes()
        var result = [SQLiteAttribute]()
        for attr in attrs {
            if attr.columeType == nil { continue }
            let value: Any? = kv[attr.key]
            if value != nil && String(describing: value!) != "nil" {
                attr.value = value
                result.append(attr)
            } else if supplement {
                result.append(attr)
            }
        }
        return result
    }
    
    private static func getSQLiteKeyValue(mirror: Mirror, prefix: String = "") -> [String: Any] {
        var result = [String: Any]()
        let kv = sqlReadAllChildrenFrom(mirror: mirror)
        for (k,v) in kv {
            if let obj = v as? SQLiteCodable {
                let subMirror = Mirror(reflecting: obj)
                let subKV = getSQLiteKeyValue(mirror: subMirror, prefix: prefix + k + kConnector)
                result.merge(subKV) { (_, new) in new }
            } else {
                result[prefix + k] = v
            }
        }
        return result
    }
    
    static func sqlReadAllChildrenFrom(mirror: Mirror) -> [String: Any] {
        var children = [(label: String?, value: Any)]()
        let mirrorChildrenCollection = AnyRandomAccessCollection(mirror.children)!
        children += mirrorChildrenCollection
        
        var currentMirror = mirror
        while let superclassChildren = currentMirror.superclassMirror?.children {
            let randomCollection = AnyRandomAccessCollection(superclassChildren)!
            children += randomCollection
            currentMirror = currentMirror.superclassMirror!
        }
        var result = [(String, Any)]()
        children.forEach { (child) in
            if let _label = child.label {
                result.append((_label, child.value))
            }
        }
        var returnResult = [String: Any]()
        var temp: [String: AnyObject] = [:]
        for (k,v) in result {
            if String(describing: v) == "nil" {
                returnResult[k] = v
            } else {
                temp[k] = v as AnyObject
            }
        }
        for (k,v) in temp {
            returnResult[k] = v
        }
        
        return returnResult
    }
}

extension SQLiteCodable {
    static func sqlTransform(simple: [String: Any]) -> Self? {
        let dict = assembleComplex(simple)
        return _sqlTransform(dict: dict) as? Self
    }
    
    static func _sqlTransform(from object: Any) -> Self? {
        if let dict = object as? [String: Any] {
            return self._sqlTransform(dict: dict) as? Self
        }
        return nil
    }
    
    static func _sqlTransform(dict: [String: Any]) -> SQLiteCodable? {
        var instance: Self
        if let _nsType = Self.self as? NSObject.Type {
            instance = _nsType.createSQLiteInstance() as! Self
        } else {
            instance = Self.init()
        }
        _sqlTransform(dict: dict, to: &instance)
        return instance
    }
    
    static func _sqlTransform(dict: [String: Any], to instance: inout Self) {
        guard let attributes = SQLiteAttribute.getAttributes(forType: Self.self) else {
            return
        }
        let rawPointer = instance.headPointer()
        let instanceIsNsObject = instance.isNSObjectType()
        let bridgedAttributeList = instance.getBridgedAttributeList()
        for attr in attributes {
            attr.bridged = instanceIsNsObject && bridgedAttributeList.contains(attr.key)
            attr.address = rawPointer.advanced(by: attr.offset)
            if let rawValue = dict[attr.key] {
                if let convertedValue = sqlConvertValue(rawValue: rawValue, attribute: attr) {
                    sqlAssignAttribute(convertedValue: convertedValue, instance: instance, attribute: attr)
                }
            }
        }
    }
}

extension NSObject {
    static func createSQLiteInstance() -> NSObject {
        return self.init()
    }
}

fileprivate func sqlConvertValue(rawValue: Any, attribute: SQLiteAttribute) -> Any? {
    if rawValue is NSNull { return nil }
    if let transformableType = attribute.type as? SQLiteTransformable.Type {
        return transformableType.sqlTransform(from: rawValue)
    } else {
        return sqlExtensions(of: attribute.type).takeValue(from: rawValue)
    }
}

fileprivate func sqlAssignAttribute(convertedValue: Any, instance: SQLiteCodable, attribute: SQLiteAttribute) {
    if attribute.bridged {
        (instance as! NSObject).setValue(convertedValue, forKey: attribute.key)
    } else if attribute.address != nil {
        sqlExtensions(of: attribute.type).write(convertedValue, to: attribute.address!)
    }
}

fileprivate func splitSimple(_ dict: [String: Any], prefix: String = "")  -> [String: Any] {
    var result = [String: Any]()
    for (k,v) in dict {
        if let value = v as? [String: Any] {
            let temp = splitSimple(value, prefix: prefix + k + kConnector)
            result.merge(temp) { (_, new) in new }
        } else {
            result[prefix + k] = v
        }
    }
    return result
}

fileprivate func assembleComplex(_ dict: [String: Any])  -> [String: Any] {
    var result = dict
    var maxCount = 2
    repeat {
        maxCount = 0
        for (k,_) in result {
            maxCount = max(maxCount, k.components(separatedBy: kConnector).count)
        }
        if maxCount == 1 {
            continue
        }
        for (k,v) in result {
            let keys = k.components(separatedBy: kConnector)
            if keys.count == maxCount {
                result.removeValue(forKey: k)
                let sk = keys.last!
                let pk = k.replacingOccurrences(of: kConnector + sk, with: "")
                var sub = result[pk] as? [String: Any] ?? [:]
                sub[sk] = v
                result[pk] = sub
            }
        }
    } while maxCount > 2
    return result
}
