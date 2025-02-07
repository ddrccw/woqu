//
//  File.swift
//  woqu
//
//  Created by alibaba on 2025/2/6.
//

import Foundation

extension JSONSerialization.WritingOptions {
    // 兼容老版本用该值
    public static var wq_withoutEscapingSlashes: JSONSerialization.WritingOptions {
        if #available(iOS 13.0, *) {
            return JSONSerialization.WritingOptions.withoutEscapingSlashes
        } else {
            return JSONSerialization.WritingOptions(rawValue: UInt(1) << 3)
        }
    }
}

extension Dictionary {
    // Dictionary to data
    public func wq_toJSONData(options opt: JSONSerialization.WritingOptions = []) -> Data? {
        return try? JSONSerialization.data(withJSONObject: self, options: opt)
    }

    // Dictionay to String
    public func wq_toJSONString(options opt: JSONSerialization.WritingOptions = []) -> String? {
        guard let data = wq_toJSONData(options: opt) else {
            return nil
        }

        if #available(iOS 13.0, *) {
            return String(data: data, encoding: .utf8)
        } else {
            let ret = String(data: data, encoding: .utf8)
            if opt.contains(.wq_withoutEscapingSlashes),
               let ret = ret {
                return ret.wq_removingEscapingSlashes();
            }
            return ret
        }
    }

    public func wq_toDebugJSONString() -> String? {
        return wq_toJSONString(options: [.prettyPrinted, .sortedKeys])
    }
}


extension String {
    public func wq_toDictionary() -> [String: Any]? {
        guard let data = data(using: .utf8),
              data.count > 0 else {
            return nil
        }
        return data.wq_toDictionary()
    }

    public func wq_removingEscapingSlashes() -> String {
        return self.replacingOccurrences(of: "\\/", with: "/")
    }
}

extension Data {
    public func wq_toDictionary() -> [String: Any]? {
        guard let dict = try? JSONSerialization.jsonObject(with: self,
                                                           options: .mutableContainers),
              let dict = dict as? [String: Any] else {
            return nil
        }
        return dict
    }
}
