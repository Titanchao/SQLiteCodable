//
//  SQLiteAttribute.swift
//  Codable
//
//  Created by tian on 2019/4/9.
//  Copyright © 2019 tian. All rights reserved.
//

import UIKit

public class SQLiteAttribute {
    
    public var key = ""
    public var dictKey = ""
    public var value: Any? = nil
    public var type: Any.Type = Any.Type.self
    public var address: UnsafeMutableRawPointer? = nil
    public var typeName: String {
        return String(describing: type).range(of: "Optional<") == nil ? String(describing: type) : String(describing: type).replacingOccurrences(of: "Optional<", with: "").replacingOccurrences(of: ">", with: "")
    }
    public var isPrimary = false
    public var isUnique = false
    public lazy var isNotNull: Bool = {
        return String(describing: type).range(of: "Optional<") == nil
    }()
    public var columeType: String? {
        return columnKeys[self.typeName]
    }
    
    public func mutableCopy() -> SQLiteAttribute {
        let attr = SQLiteAttribute()
        attr.key = self.key
        attr.dictKey = self.dictKey
        attr.type = self.type
        attr.isPrimary = self.isPrimary
        attr.isUnique = self.isUnique
        attr.isNotNull = self.isNotNull
        return attr
    }
}

class SQLiteAttributePool {
    static let share = SQLiteAttributePool()
    public lazy var workPlace: String = {
        return (Bundle.main.infoDictionary?["CFBundleExecutable"] as? String) ?? ""
    }()
    
    public var pool: [String: [SQLiteAttribute]] = [:]
}

fileprivate let kConnector = "$_"

extension SQLiteCodable {
    
    public static func getSQLiteAttributes() -> [SQLiteAttribute] {
        let object = Self.init()
        var keyValue = [String: Any]()
        if let dict = object.toJSON() {
            keyValue = splitSimple(dict)
        }
        let tn = Self.tableName()
        if let retValue = SQLiteAttributePool.share.pool[tn] {
            return retValue
        }
        let attrs = _getAttributes(object: object)
        let mapper = SQLiteMapper()
        object.declareKeys(mapper: mapper)
        var result = [SQLiteAttribute]()
        for attr in attrs {
            if attr.address == nil {
                continue
            }
            if columnKeys[attr.typeName] == nil {
                continue
            }
            if mapper.isPirmary(key: attr.address!.hashValue) {
                attr.isPrimary = true
            }
            if mapper.isUnique(key: attr.address!.hashValue) {
                attr.isUnique = true
            }
            if let defaultValue = keyValue[attr.dictKey] {
                attr.value = defaultValue
            }
            result.append(attr)
        }
        SQLiteAttributePool.share.pool[tn] = result
        return result
    }

    static func _getAttributes(object: _Transformable, prefix: String = "", realPrefix: String = "", forceNull: Bool = false) -> [SQLiteAttribute] {
        guard let attrs = _serializeAttr(object: object) as? [SQLiteAttribute] else {
            return []
        }
        var result = [SQLiteAttribute]()
        
        for attr in attrs {
            let subObj = NSClassFromString("\(SQLiteAttributePool.share.workPlace).\(attr.typeName)")?.alloc()
            if let typeValue = subObj as? SQLiteCodable {
                let keyPrefix = prefix + attr.key + kConnector
                let dictPrefix = realPrefix + attr.dictKey + kConnector
                let nullable = !attr.isNotNull
                let subAttrs = _getAttributes(object: typeValue, prefix: keyPrefix, realPrefix: dictPrefix, forceNull: nullable)
                result.append(contentsOf: subAttrs)
            } else {
                if forceNull {
                    attr.isNotNull = false
                }
                attr.key = prefix + attr.key
                attr.dictKey = realPrefix + attr.dictKey
                result.append(attr)
            }
        }
        return result
    }
}
    
extension _ExtendCustomModelType {
    
    static func _serializeAttr(object: _Transformable) -> Any? {
        
        let mirror = Mirror(reflecting: object)
        
        guard let displayStyle = mirror.displayStyle else {
            return object.plainValue()
        }
        
        switch displayStyle {
        case .class, .struct:
            let mapper = HelpingMapper()
            
            if !(object is _ExtendCustomModelType) {
                return object
            }
            
            guard let properties = getProperties(forType: type(of: object)) else {
                return nil
            }
            
            var mutableObject = object as! _ExtendCustomModelType
            let instanceIsNsObject = mutableObject.isNSObjectType()
            let head = mutableObject.headPointer()
            let bridgedProperty = mutableObject.getBridgedPropertyList()
            let propertyInfos = properties.map({ (desc) -> PropertyInfo in
                return PropertyInfo(key: desc.key, type: desc.type, address: head.advanced(by: desc.offset),
                                    bridged: instanceIsNsObject && bridgedProperty.contains(desc.key))
            })
            
            mutableObject.mapping(mapper: mapper)
            
            var requiredInfo = [String: (Any, PropertyInfo?)]()
            propertyInfos.forEach { (info) in
                requiredInfo[info.key] = (info.key, info)
            }
            
            return _serializeModelObjectAttribute(instance: mutableObject, properties: requiredInfo, mapper: mapper) as Any
        default:
            return object.plainValue()
        }
    }
    
    static func _serializeModelObjectAttribute(instance: _ExtendCustomModelType, properties: [String: (Any, PropertyInfo?)], mapper: HelpingMapper) -> [SQLiteAttribute] {
        
        var dict = [String: Any]()
        var retObj = [SQLiteAttribute]()
        for (key, property) in properties {
            var realKey = key
            var realValue = property.0
            let attr = SQLiteAttribute()
            attr.key = key
            attr.dictKey = realKey
            
            if let info = property.1 {
                attr.type = info.type
                attr.address = info.address
                if info.bridged, let _value = (instance as! NSObject).value(forKey: key) {
                    realValue = _value
                }
                
                //忽略的key
                if mapper.propertyExcluded(key: Int(bitPattern: info.address)) {
                    continue
                }
                
                if let mappingHandler = mapper.getMappingHandler(key: Int(bitPattern: info.address)) {
                    // if specific key is set, replace the label
                    if let mappingPaths = mappingHandler.mappingPaths, mappingPaths.count > 0 {
                        // take the first path, last segment if more than one
                        realKey = mappingPaths[0].segments.last!
                        attr.dictKey = realKey
                    }
                    
                    if let transformer = mappingHandler.takeValueClosure {
                        if let _transformedValue = transformer(realValue) {
                            dict[realKey] = _transformedValue
                            retObj.append(attr)
                        }
                        continue
                    }
                }
            }
            
            if let typedValue = realValue as? _Transformable {
                if let result = self._serializeAny(object: typedValue) {
                    dict[realKey] = result
                    retObj.append(attr)
                    continue
                }
            }
            
            InternalLogger.logDebug("The value for key: \(key) is not transformable type")
            retObj.append(attr)
        }
        return retObj
    }
}

fileprivate let columnKeys = ["String": "TEXT",
                              "NSString": "TEXT",
                              "NSTaggedPointerString": "TEXT",
                              "Int": "INTEGER",
                              "Int8": "INTEGER",
                              "Int16": "INTEGER",
                              "Int32": "INTEGER",
                              "Int64": "INTEGER",
                              "Double": "DOUBLE",
                              "Float": "FLOAT",
                              "CGFloat": "DOUBLE",
                              "Bool": "BOOLEAN",
                              "Date": "DATE"]


func splitSimple(_ dict: [String: Any], prefix: String = "")  -> [String: Any] {
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

func assembleComplex(_ dict: [String: Any])  -> [String: Any] {
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
