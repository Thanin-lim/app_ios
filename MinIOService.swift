import Foundation
import CryptoKit

// MARK: - MinIO Service (Real S3-compatible implementation)

actor MinIOService {
    static let shared = MinIOService()

    private var host: String = "100.106.98.53:30005"
    private var accessKey: String = "minio"
    private var secretKey: String = "minio123"
    private var bucket: String = "mybucket"
    private var useHTTPS: Bool = false

    private var baseURL: String {
        let scheme = useHTTPS ? "https" : "http"
        return "\(scheme)://\(host)"
    }

    // MARK: - Connect

    func connect(host: String, accessKey: String, secretKey: String, bucket: String) async -> Bool {
        self.host = host
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.bucket = bucket
        self.useHTTPS = host.hasPrefix("https")

        let url = "\(baseURL)/\(bucket)"
        guard let request = try? await signedRequest(method: "HEAD", urlString: url, body: Data()) else {
            print("[MinIO] connect: failed to build request for \(url)")
            return false
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[MinIO] connect → status: \(status)")
            if let body = String(data: data, encoding: .utf8), !body.isEmpty {
                print("[MinIO] connect → body: \(body)")
            }
            return status == 200 || status == 301 || status == 403
        } catch {
            print("[MinIO] connect error: \(error)")
            return false
        }
    }

    // MARK: - List Objects

    func listObjects(bucket: String, prefix: String) async -> ([MinIOObject], [MinIOObject]) {
        async let current = fetchObjects(bucket: bucket, prefix: prefix, delimiter: "/")
        async let all = fetchObjects(bucket: bucket, prefix: "", delimiter: "")
        return await (current, all)
    }

    private func fetchObjects(bucket: String, prefix: String, delimiter: String) async -> [MinIOObject] {
        var queryParts = [
            "list-type=2",
            "prefix=\(prefix.s3PercentEncoded)",
        ]
        if !delimiter.isEmpty {
            queryParts.append("delimiter=\(delimiter.s3PercentEncoded)")
        }
        queryParts.sort()

        let queryString = queryParts.joined(separator: "&")
        let urlString = "\(baseURL)/\(bucket)?\(queryString)"

        guard let request = try? await signedRequest(method: "GET", urlString: urlString, body: Data()) else {
            print("[MinIO] fetchObjects: failed to build signed request")
            return []
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                print("[MinIO] listObjects HTTP \(status)")
                if let body = String(data: data, encoding: .utf8) {
                    print("[MinIO] listObjects body: \(body)")
                }
                return []
            }
            return parseListResponse(data: data, currentPrefix: prefix)
        } catch {
            print("[MinIO] listObjects error: \(error)")
            return []
        }
    }

    // MARK: - Parse S3 XML Response

    private func parseListResponse(data: Data, currentPrefix: String) -> [MinIOObject] {
        let parser = S3XMLParser(data: data, currentPrefix: currentPrefix)
        return parser.parse()
    }

    // MARK: - Build encoded URL

    func buildURL(bucket: String, key: String) -> String? {
        let cleanKey = key.hasPrefix("\(bucket)/")
            ? String(key.dropFirst(bucket.count + 1))
            : key

        let encodedKey = cleanKey
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { String($0).s3PercentEncoded }
            .joined(separator: "/")

        var components = URLComponents(string: baseURL)!
        components.percentEncodedPath = "/\(bucket)/\(encodedKey)"
        return components.url?.absoluteString
    }

    // MARK: - Put Empty Object (create folder)

    func putEmptyObject(bucket: String, key: String) async {
        let cleanKey = key.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let urlString = buildURL(bucket: bucket, key: "\(cleanKey)/") else {
            print("[MinIO] putEmptyObject: invalid URL for key \(key)")
            return
        }
        guard var request = try? await signedRequest(method: "PUT", urlString: urlString, body: Data()) else { return }
        request.setValue("0", forHTTPHeaderField: "Content-Length")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[MinIO] putEmptyObject \(key) → \(status)")
            if status != 200, let body = String(data: data, encoding: .utf8) {
                print("[MinIO] putEmptyObject body: \(body)")
            }
        } catch {
            print("[MinIO] putEmptyObject error: \(error)")
        }
    }

    // MARK: - Remove Object

    func removeObject(bucket: String, key: String) async {
        guard let urlString = buildURL(bucket: bucket, key: key) else {
            print("[MinIO] removeObject: invalid URL for key \(key)")
            return
        }
        guard let request = try? await signedRequest(method: "DELETE", urlString: urlString, body: Data()) else { return }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            print("[MinIO] removeObject \(key) → \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        } catch {
            print("[MinIO] removeObject error: \(error)")
        }
    }

    // MARK: - Copy Object
    // ใช้สำหรับ rename / move (MinIO ไม่มี native rename)

    func copyObject(bucket: String, sourceKey: String, destinationKey: String) async {
        guard let urlString = buildURL(bucket: bucket, key: destinationKey) else {
            print("[MinIO] copyObject: invalid destination URL")
            return
        }

        guard var request = try? await signedRequest(method: "PUT", urlString: urlString, body: Data()) else { return }

        let copySource = "/\(bucket)/\(sourceKey.s3PercentEncoded)"
        request.setValue(copySource, forHTTPHeaderField: "x-amz-copy-source")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[MinIO] copyObject \(sourceKey) → \(destinationKey): \(status)")
            if status != 200, let body = String(data: data, encoding: .utf8) {
                print("[MinIO] copyObject body: \(body)")
            }
        } catch {
            print("[MinIO] copyObject error: \(error)")
        }
    }

    // MARK: - Upload File

    func uploadFile(bucket: String, key: String, localURL: URL) async {
        let accessing = localURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { localURL.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: localURL) else {
            print("[MinIO] uploadFile: cannot read \(localURL)")
            return
        }
        guard let urlString = buildURL(bucket: bucket, key: key) else {
            print("[MinIO] uploadFile: invalid URL for key \(key)")
            return
        }
        guard var request = try? await signedRequest(method: "PUT", urlString: urlString, body: data) else { return }
        request.httpBody = data

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[MinIO] uploadFile \(key) → \(status)")
            if status != 200, let body = String(data: responseData, encoding: .utf8) {
                print("[MinIO] uploadFile body: \(body)")
            }
        } catch {
            print("[MinIO] uploadFile error: \(error)")
        }
    }

    // MARK: - Upload Data
    // อัปโหลดจาก Data โดยตรง (ไม่ต้องใช้ local file)

    func uploadData(
        bucket: String,
        key: String,
        data: Data,
        contentType: String = "application/octet-stream"
    ) async {
        guard let urlString = buildURL(bucket: bucket, key: key) else {
            print("[MinIO] uploadData: invalid URL for key \(key)")
            return
        }

        guard var request = try? await signedRequest(method: "PUT", urlString: urlString, body: data) else { return }
        request.httpBody = data
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[MinIO] uploadData \(key) → \(status)")
            if status != 200, let body = String(data: responseData, encoding: .utf8) {
                print("[MinIO] uploadData body: \(body)")
            }
        } catch {
            print("[MinIO] uploadData error: \(error)")
        }
    }

    // MARK: - Download Data
    // ดาวน์โหลด raw Data จาก object key

    func downloadData(bucket: String, key: String) async -> Data? {
        guard let urlString = buildURL(bucket: bucket, key: key) else {
            print("[MinIO] downloadData: invalid URL for key \(key)")
            return nil
        }

        guard let request = try? await signedRequest(method: "GET", urlString: urlString, body: Data()) else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[MinIO] downloadData \(key) → \(status), size: \(data.count) bytes")
            return status == 200 ? data : nil
        } catch {
            print("[MinIO] downloadData error: \(error)")
            return nil
        }
    }

    // MARK: - Download to File
    // ดาวน์โหลดและบันทึกไปยัง local URL

    func downloadToFile(bucket: String, key: String, destinationURL: URL) async -> Bool {
        guard let data = await downloadData(bucket: bucket, key: key) else {
            return false
        }

        do {
            try data.write(to: destinationURL)
            print("[MinIO] downloadToFile saved to \(destinationURL.path)")
            return true
        } catch {
            print("[MinIO] downloadToFile write error: \(error)")
            return false
        }
    }

    // MARK: - Object Metadata (HEAD)
    // ดึง metadata ของ object โดยไม่ดาวน์โหลด body

    func objectMetadata(bucket: String, key: String) async -> [String: String]? {
        guard let urlString = buildURL(bucket: bucket, key: key) else {
            print("[MinIO] objectMetadata: invalid URL for key \(key)")
            return nil
        }

        guard let request = try? await signedRequest(method: "HEAD", urlString: urlString, body: Data()) else {
            return nil
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200 else { return nil }

            var metadata: [String: String] = [:]
            for (key, value) in http.allHeaderFields {
                if let k = key as? String, let v = value as? String {
                    metadata[k.lowercased()] = v
                }
            }
            print("[MinIO] objectMetadata \(key): \(metadata.count) headers")
            return metadata
        } catch {
            print("[MinIO] objectMetadata error: \(error)")
            return nil
        }
    }

    // MARK: - Object Exists

    func objectExists(bucket: String, key: String) async -> Bool {
        let meta = await objectMetadata(bucket: bucket, key: key)
        return meta != nil
    }

    // MARK: - Object Size

    func objectSize(bucket: String, key: String) async -> Int64? {
        guard let meta = await objectMetadata(bucket: bucket, key: key),
              let lengthStr = meta["content-length"],
              let length = Int64(lengthStr) else { return nil }
        return length
    }

    // MARK: - Multi Delete
    // ลบหลาย object พร้อมกันด้วย S3 Multi-Object Delete API

    func deleteObjects(bucket: String, keys: [String]) async {
        guard !keys.isEmpty else { return }

        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
        xml += "<Delete>"
        for key in keys {
            xml += "<Object><Key>\(key.xmlEscaped)</Key></Object>"
        }
        xml += "</Delete>"

        let body = Data(xml.utf8)
        let md5 = Insecure.MD5.hash(data: body)
        let md5Base64 = Data(md5).base64EncodedString()

        let urlString = "\(baseURL)/\(bucket)?delete"

        guard var request = try? await signedRequest(method: "POST", urlString: urlString, body: body) else { return }
        request.httpBody = body
        request.setValue(md5Base64, forHTTPHeaderField: "Content-MD5")
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[MinIO] deleteObjects (\(keys.count) items) → \(status)")
            if status != 200, let body = String(data: data, encoding: .utf8) {
                print("[MinIO] deleteObjects body: \(body)")
            }
        } catch {
            print("[MinIO] deleteObjects error: \(error)")
        }
    }

    // MARK: - List Buckets

    func listBuckets() async -> [String] {
        let urlString = "\(baseURL)/"

        guard let request = try? await signedRequest(method: "GET", urlString: urlString, body: Data()) else {
            return []
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                print("[MinIO] listBuckets HTTP \(status)")
                return []
            }
            return parseBucketList(data: data)
        } catch {
            print("[MinIO] listBuckets error: \(error)")
            return []
        }
    }

    private func parseBucketList(data: Data) -> [String] {
        guard let xml = String(data: data, encoding: .utf8) else { return [] }
        var buckets: [String] = []
        var remaining = xml
        while let start = remaining.range(of: "<Name>"),
              let end = remaining.range(of: "</Name>") {
            let name = String(remaining[start.upperBound..<end.lowerBound])
            buckets.append(name)
            remaining = String(remaining[end.upperBound...])
        }
        print("[MinIO] listBuckets: \(buckets)")
        return buckets
    }

    // MARK: - Bucket Exists

    func bucketExists(bucket: String) async -> Bool {
        let urlString = "\(baseURL)/\(bucket)"
        guard let request = try? await signedRequest(method: "HEAD", urlString: urlString, body: Data()) else {
            return false
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return status == 200
        } catch {
            return false
        }
    }

    // MARK: - Create Bucket

    func createBucket(name: String) async -> Bool {
        let urlString = "\(baseURL)/\(name)"
        guard let request = try? await signedRequest(method: "PUT", urlString: urlString, body: Data()) else {
            return false
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[MinIO] createBucket \(name) → \(status)")
            return status == 200
        } catch {
            print("[MinIO] createBucket error: \(error)")
            return false
        }
    }

    // MARK: - Presigned GET URL

    func presignedGetURL(bucket: String, key: String, expiresIn seconds: Int) async -> URL? {
        let cleanKey = key.hasPrefix("\(bucket)/")
            ? String(key.dropFirst(bucket.count + 1))
            : key

        let encodedKey = cleanKey
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { String($0).s3PercentEncoded }
            .joined(separator: "/")

        let now = Date()
        let amzDate = amzDateString(from: now)
        let dateStamp = dateStampString(from: now)
        let region = "us-east-1"
        let service = "s3"
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let credential = "\(accessKey)/\(credentialScope)"

        let unsignedParams: [(String, String)] = [
            ("X-Amz-Algorithm", "AWS4-HMAC-SHA256"),
            ("X-Amz-Credential", credential),
            ("X-Amz-Date", amzDate),
            ("X-Amz-Expires", "\(seconds)"),
            ("X-Amz-SignedHeaders", "host"),
        ]

        let sortedParams = unsignedParams.sorted { $0.0 < $1.0 }
        let canonicalQueryString = sortedParams
            .map { "\($0.0.s3PercentEncoded)=\($0.1.s3PercentEncoded)" }
            .joined(separator: "&")

        let parsedBase = URL(string: baseURL)!
        let hostValue: String = {
            guard let port = parsedBase.port,
                  !((parsedBase.scheme == "http" && port == 80) ||
                    (parsedBase.scheme == "https" && port == 443)) else {
                return parsedBase.host!
            }
            return "\(parsedBase.host!):\(port)"
        }()

        let canonicalPath = "/\(bucket)/\(encodedKey)"

        let canonicalRequest = [
            "GET",
            canonicalPath,
            canonicalQueryString,
            "host:\(hostValue)\n",
            "host",
            "UNSIGNED-PAYLOAD"
        ].joined(separator: "\n")

        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            credentialScope,
            sha256Hash(canonicalRequest)
        ].joined(separator: "\n")

        let signingKey = getSigningKey(
            secretKey: secretKey,
            dateStamp: dateStamp,
            region: region,
            service: service
        )
        let signature = hmacSHA256(key: signingKey, data: stringToSign).hexString

        let finalQueryString = canonicalQueryString + "&X-Amz-Signature=\(signature)"
        var finalComponents = URLComponents(string: baseURL)!
        finalComponents.percentEncodedPath = canonicalPath
        finalComponents.percentEncodedQuery = finalQueryString

        print("[MinIO] presignedURL host='\(hostValue)' path='\(canonicalPath)'")
        print("[MinIO] presignedURL: \(finalComponents.url?.absoluteString ?? "nil")")
        return finalComponents.url
    }

    // MARK: - Presigned PUT URL
    // สร้าง presigned URL สำหรับ upload จาก client โดยตรง

    func presignedPutURL(bucket: String, key: String, expiresIn seconds: Int = 3600) async -> URL? {
        guard let urlString = buildURL(bucket: bucket, key: key),
              let url = URL(string: urlString) else { return nil }

        let now = Date()
        let amzDate = amzDateString(from: now)
        let dateStamp = dateStampString(from: now)
        let region = "us-east-1"
        let service = "s3"
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let credential = "\(accessKey)/\(credentialScope)"

        let params: [(String, String)] = [
            ("X-Amz-Algorithm", "AWS4-HMAC-SHA256"),
            ("X-Amz-Credential", credential),
            ("X-Amz-Date", amzDate),
            ("X-Amz-Expires", "\(seconds)"),
            ("X-Amz-SignedHeaders", "host"),
        ].sorted { $0.0 < $1.0 }

        let canonicalQuery = params
            .map { "\($0.0.s3PercentEncoded)=\($0.1.s3PercentEncoded)" }
            .joined(separator: "&")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let hostValue: String = {
            guard let port = components.port,
                  !((components.scheme == "http" && port == 80) ||
                    (components.scheme == "https" && port == 443)) else {
                return components.host ?? ""
            }
            return "\(components.host ?? ""):\(port)"
        }()

        let canonicalPath = components.percentEncodedPath

        let canonicalRequest = [
            "PUT",
            canonicalPath,
            canonicalQuery,
            "host:\(hostValue)\n",
            "host",
            "UNSIGNED-PAYLOAD"
        ].joined(separator: "\n")

        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            credentialScope,
            sha256Hash(canonicalRequest)
        ].joined(separator: "\n")

        let signingKey = getSigningKey(
            secretKey: secretKey,
            dateStamp: dateStamp,
            region: region,
            service: service
        )
        let signature = hmacSHA256(key: signingKey, data: stringToSign).hexString

        let finalQuery = canonicalQuery + "&X-Amz-Signature=\(signature)"
        var finalComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        finalComponents.percentEncodedQuery = finalQuery

        print("[MinIO] presignedPutURL: \(finalComponents.url?.absoluteString ?? "nil")")
        return finalComponents.url
    }

    // MARK: - AWS Signature V4

    func signedRequest(method: String, urlString: String, body: Data) async throws -> URLRequest {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let now = Date()
        let amzDate = amzDateString(from: now)
        let dateStamp = dateStampString(from: now)
        let region = "us-east-1"
        let service = "s3"
        let bodyHash = sha256Hash(body)

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }

        let host = components.host ?? ""
        let hostHeader: String = {
            if let port = components.port,
               !((components.scheme == "http" && port == 80) ||
                 (components.scheme == "https" && port == 443)) {
                return "\(host):\(port)"
            }
            return host
        }()

        let path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath

        let canonicalQuery: String = {
            guard let query = components.percentEncodedQuery, !query.isEmpty else { return "" }
            return query
                .split(separator: "&")
                .map { pair -> (String, String) in
                    let parts = pair.split(separator: "=", maxSplits: 1)
                    let k = String(parts[0])
                    let v = parts.count > 1 ? String(parts[1]) : ""
                    return (k, v)
                }
                .sorted { $0.0 < $1.0 }
                .map { "\($0.0)=\($0.1)" }
                .joined(separator: "&")
        }()

        let canonicalHeaders = "host:\(hostHeader)\nx-amz-content-sha256:\(bodyHash)\nx-amz-date:\(amzDate)\n"
        let signedHeaders = "host;x-amz-content-sha256;x-amz-date"

        let canonicalRequest = [
            method,
            path,
            canonicalQuery,
            canonicalHeaders,
            signedHeaders,
            bodyHash
        ].joined(separator: "\n")

        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            credentialScope,
            sha256Hash(canonicalRequest)
        ].joined(separator: "\n")

        let signingKey = getSigningKey(
            secretKey: secretKey,
            dateStamp: dateStamp,
            region: region,
            service: service
        )
        let signature = hmacSHA256(key: signingKey, data: stringToSign).hexString

        let authorization = "AWS4-HMAC-SHA256 Credential=\(accessKey)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(hostHeader, forHTTPHeaderField: "Host")
        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        request.setValue(bodyHash, forHTTPHeaderField: "x-amz-content-sha256")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")

        if !body.isEmpty {
            request.httpBody = body
        }

        return request
    }

    // MARK: - Crypto Helpers

    func sha256Hash(_ string: String) -> String {
        sha256Hash(Data(string.utf8))
    }

    func sha256Hash(_ data: Data) -> String {
        SHA256.hash(data: data).hexString
    }

    func hmacSHA256(key: Data, data: String) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let mac = HMAC<SHA256>.authenticationCode(for: Data(data.utf8), using: symmetricKey)
        return Data(mac)
    }

    func getSigningKey(secretKey: String, dateStamp: String, region: String, service: String) -> Data {
        let kSecret = Data(("AWS4" + secretKey).utf8)
        let kDate = hmacSHA256(key: kSecret, data: dateStamp)
        let kRegion = hmacSHA256(key: kDate, data: region)
        let kService = hmacSHA256(key: kRegion, data: service)
        let kSigning = hmacSHA256(key: kService, data: "aws4_request")
        return kSigning
    }

    func amzDateString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    func dateStampString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }
}

// MARK: - S3 XML Parser

private final class S3XMLParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    private let data: Data
    private let currentPrefix: String
    private var objects: [MinIOObject] = []

    private var currentKey = ""
    private var currentSize: Int64 = 0
    private var currentDate: Date? = nil
    private var isInContents = false
    private var isInCommonPrefixes = false
    private var buffer = ""

    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    nonisolated init(data: Data, currentPrefix: String) {
        self.data = data
        self.currentPrefix = currentPrefix
    }

    nonisolated func parse() -> [MinIOObject] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return objects
    }

    nonisolated func parser(_ parser: XMLParser, didStartElement element: String,
                            namespaceURI: String?, qualifiedName: String?,
                            attributes: [String: String] = [:]) {
        buffer = ""
        if element == "Contents"       { isInContents = true; currentSize = 0; currentKey = "" }
        if element == "CommonPrefixes" { isInCommonPrefixes = true }
    }

    nonisolated func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    nonisolated func parser(_ parser: XMLParser, didEndElement element: String,
                            namespaceURI: String?, qualifiedName: String?) {
        let value = buffer.trimmingCharacters(in: .whitespacesAndNewlines)

        if isInContents {
            switch element {
            case "Key":          currentKey = value
            case "Size":         currentSize = Int64(value) ?? 0
            case "LastModified": currentDate = dateFormatter.date(from: value)
            case "Contents":
                if !currentKey.hasSuffix("/") {
                    let displayName = currentKey.hasPrefix(currentPrefix)
                        ? String(currentKey.dropFirst(currentPrefix.count))
                        : currentKey
                    objects.append(MinIOObject(
                        name: currentKey,
                        displayName: displayName.split(separator: "/").first.map(String.init) ?? displayName,
                        isDirectory: false,
                        size: currentSize,
                        lastModified: currentDate
                    ))
                }
                isInContents = false
            default: break
            }
        }

        if isInCommonPrefixes && element == "Prefix" {
            let displayName = value.hasPrefix(currentPrefix)
                ? String(value.dropFirst(currentPrefix.count))
                : value
            let cleanName = displayName.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !cleanName.isEmpty {
                objects.append(MinIOObject(
                    name: value,
                    displayName: cleanName,
                    isDirectory: true,
                    size: 0,
                    lastModified: nil
                ))
            }
        }

        if element == "CommonPrefixes" { isInCommonPrefixes = false }
        buffer = ""
    }
}

// MARK: - Extensions

private extension Digest {
    nonisolated var hexString: String {
        makeIterator().map { String(format: "%02x", $0) }.joined()
    }
}

private extension Data {
    nonisolated var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

extension String {
    nonisolated var s3PercentEncoded: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }

    nonisolated var xmlEscaped: String {
        replacingOccurrences(of: "&",  with: "&amp;")
            .replacingOccurrences(of: "<",  with: "&lt;")
            .replacingOccurrences(of: ">",  with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'",  with: "&apos;")
    }
}
