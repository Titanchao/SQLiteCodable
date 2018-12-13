
let kConnector = "&_"

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
