//
//  Config.swift
//  refillr
//
//  Created by Abby Ressner on 8/11/25.
//

import Foundation

enum AppConfig {
    static var proxyBaseURL: URL {
        let s = Bundle.main.object(forInfoDictionaryKey: "PROXY_BASE_URL") as? String
        return URL(string: s ?? "https://refillr-proxy.vercel.app")!
    }
}
