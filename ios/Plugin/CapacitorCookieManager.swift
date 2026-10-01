import Foundation
import Capacitor

public class CapacitorCookieManager {
    public func encode(_ value: String) -> String {
        return value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
    
    public func decode(_ value: String) -> String {
        return value.removingPercentEncoding ?? value
    }
    
    public func setCookie(_ url: URL, _ key: String, _ value: String) {
        let jar = HTTPCookieStorage.shared
        let field = ["Set-Cookie": "\(key)=\(value)"]
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: field, for: url)
        jar.setCookies(cookies, for: url, mainDocumentURL: url)
    }
    
    public func getCookie(_ url: URL, _ key: String) -> HTTPCookie? {
        return getCookies(url).first(where: { cookie in cookie.name == key })
    }
    
    public func getCookies(_ url: URL) -> [HTTPCookie] {
        let jar = HTTPCookieStorage.shared
        guard let cookies = jar.cookies(for: url) else { return [] }

        return cookies
    }
    
    public func deleteCookie(_ url: URL, _ key: String) {
        let jar = HTTPCookieStorage.shared
        let cookie = jar.cookies(for: url)?.first(where: { (cookie) -> Bool in
          return cookie.name == key
        })

        if cookie != nil { jar.deleteCookie(cookie!) }
    }
    
    public func clearCookies(_ url: URL) {
        let jar = HTTPCookieStorage.shared
        jar.cookies(for: url)?.forEach({ (cookie) in jar.deleteCookie(cookie) })
    }
    
    public func clearAllCookies() {
        let jar = HTTPCookieStorage.shared
        jar.cookies?.forEach({ (cookie) in jar.deleteCookie(cookie) })
    }
}
