//
//  MUCodable.swift
//  MUBase
//
//  Created by ddrccw on 2024/5/17.
//

import Foundation

public protocol WQCodable: Codable, Sendable {
    init?(string: String)
    init?(data: Data)
    init?(dictionary: [String: Any])
    func toDictionary() -> [String: Any]?
    func toJSONData() -> Data?
}

extension WQCodable {
    // 移除泛型方法，直接返回初始化类型
    private static func decode(from data: Data) -> Self? {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(Self.self, from: data)
        } catch {
            // 错误处理，例如打印错误信息，或传递错误到调用者
            Logger.error("Decode error: \(error)")
            return nil
        }
    }

    // 从 data 初始化，处理潜在的解码错误
    public init?(data: Data) {
        guard let decodedSelf = Self.decode(from: data) else {
            return nil
        }
        self = decodedSelf
    }

    public init?(string: String) {
        guard let data = string.data(using: .utf8) else {
            return nil
        }
        self.init(data: data)
    }

    public init?(dictionary: [String: Any]) {
        // 将字典转换为 Data
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: []) else {
            return nil
        }

        guard let decodedSelf = Self.decode(from: data) else {
            return nil
        }
        self = decodedSelf
    }

    public func toDictionary() -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else {
            return nil
        }

        guard let dictionary = try? JSONSerialization.jsonObject(with: data, 
                                                                 options: .allowFragments) as? [String: Any] else {
            return nil
        }
        return dictionary
    }

    public func toJSONData() -> Data? {
        return toDictionary()?.wq_toJSONData()
    }
}
