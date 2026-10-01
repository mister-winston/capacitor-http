import Foundation
import Capacitor

public class CapacitorUrlRequest: NSObject, URLSessionTaskDelegate {
    private var request: URLRequest;
    private var headers: [String:String];
    public var disableRedirects = false;
    public var disableCertificateChecks = false;
    
    enum CapacitorUrlRequestError: Error {
        case serializationError(String?)
    }

    init(_ url: URL, method: String) {
        request = URLRequest(url: url)
        request.httpMethod = method
        headers = [:]
        if let lang = Locale.autoupdatingCurrent.languageCode {
            if let country = Locale.autoupdatingCurrent.regionCode {
                headers["Accept-Language"] = "\(lang)-\(country),\(lang);q=0.5"
            } else {
                headers["Accept-Language"] = "\(lang);q=0.5"
            }
            request.addValue(headers["Accept-Language"]!, forHTTPHeaderField: "Accept-Language")
        }
    }
    
    private func getRequestDataAsJson(_ data: JSValue) throws -> Data? {
        // We need to check if the JSON is valid before attempting to serialize, as JSONSerialization.data will not throw an exception that can be caught, and will cause the application to crash if it fails.
        if JSONSerialization.isValidJSONObject(data) {
            return try JSONSerialization.data(withJSONObject: data)
        } else {
            throw CapacitorUrlRequest.CapacitorUrlRequestError.serializationError("[ data ] argument for request of content-type [ application/json ] must be serializable to JSON")
        }
    }
    
    private func getRequestDataAsFormUrlEncoded(_ data: JSValue) throws -> Data? {
        guard let obj = data as? JSObject else {
            // Throw, other data types explicitly not supported
            throw CapacitorUrlRequestError.serializationError("[ data ] argument for request with content-type [ multipart/form-data ] may only be a plain javascript object")
        }

        // URLComponents leaves characters such as "+" and "&" unescaped, so encode everything outside the unreserved set
        let unreserved = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let encode = { (value: String) -> String in
            value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value
        }

        let query = obj.map { key, value in "\(encode(key))=\(encode("\(value)"))" }.joined(separator: "&")

        return query.isEmpty ? nil : Data(query.utf8)
    }
    
    private func getRequestDataAsMultipartFormData(_ data: JSValue) throws -> Data {
        guard let obj = data as? JSObject else {
            // Throw, other data types explicitly not supported.
            throw CapacitorUrlRequestError.serializationError("[ data ] argument for request with content-type [ application/x-www-form-urlencoded ] may only be a plain javascript object")
        }
        
        let strings: [String: String] = obj.compactMapValues { any in
            any as? String
        }
        
        var data = Data()
        let boundary = UUID().uuidString
        let contentType = "multipart/form-data; boundary=\(boundary)"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        headers["Content-Type"] = contentType
        
        strings.forEach { key, value in
            data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            data.append(value.data(using: .utf8)!)
        }
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        return data
    }
    
    private func getRequestDataAsString(_ data: JSValue) throws -> Data {
        guard let stringData = data as? String else {
            throw CapacitorUrlRequestError.serializationError("[ data ] argument could not be parsed as string")
        }
        return Data(stringData.utf8)
    }

    func getRequestHeader(_ index: String) -> Any? {
        var normalized = [:] as [String:Any]
        self.headers.keys.forEach { (key: String) in
            normalized[key.lowercased()] = self.headers[key]
        }

        return normalized[index.lowercased()]
    }
    
    func getRequestData(_ body: JSValue, _ contentType: String) throws -> Data? {
        // If data can be parsed directly as a string, return that without processing.
        if let strVal = try? getRequestDataAsString(body) {
            return strVal
        } else if contentType.contains("application/json") {
            return try getRequestDataAsJson(body)
        } else if contentType.contains("application/x-www-form-urlencoded") {
            return try getRequestDataAsFormUrlEncoded(body)
        } else if contentType.contains("multipart/form-data") {
            return try getRequestDataAsMultipartFormData(body)
        } else {
            throw CapacitorUrlRequestError.serializationError("[ data ] argument could not be parsed for content type [ \(contentType) ]")
        }
    }

    public func setRequestHeaders(_ headers: [String: String]) {
        headers.keys.forEach { (key: String) in
            let value = headers[key]
            request.setValue(value!, forHTTPHeaderField: key)
            self.headers[key] = value
        }
    }
    
    public func setRequestBody(_ body: JSValue) throws {
        let contentType = self.getRequestHeader("Content-Type") as? String

        if contentType != nil {
            request.httpBody = try getRequestData(body, contentType!)
        }
    }

    /// Sets raw bytes as the request body, defaulting the content type to application/octet-stream
    public func setRequestBody(binary body: Data) {
        if self.getRequestHeader("Content-Type") == nil {
            setContentType("application/octet-stream")
        }
        request.httpBody = body
    }

    public func setContentType(_ data: String?) {
        request.setValue(data, forHTTPHeaderField: "Content-Type")
    }

    public func setTimeout(_ timeout: TimeInterval) {
        request.timeoutInterval = timeout;
    }

    public func getUrlRequest() -> URLRequest {
        return request;
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(disableRedirects ? nil : request)
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        CapacitorUrlRequest.handleServerTrust(challenge, disableCertificateChecks, completionHandler)
    }

    /// Accepts any server certificate when certificate checks are disabled, otherwise uses the default handling
    public static func handleServerTrust(_ challenge: URLAuthenticationChallenge, _ disableCertificateChecks: Bool, _ completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if disableCertificateChecks,
           challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }
        completionHandler(.performDefaultHandling, nil)
    }

    public func getUrlSession(_ call: CAPPluginCall) -> URLSession {
        disableRedirects = call.getBool("disableRedirects") ?? false
        disableCertificateChecks = call.getBool("disableCertificateChecks") ?? false
        return getUrlSession()
    }

    public func getUrlSession() -> URLSession {
        if (!disableRedirects && !disableCertificateChecks) {
            return URLSession.shared
        }
        return URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    }
}
