import Foundation
import SwiftData

/// 输出提取配置
struct OutputExtraction: Codable, Hashable {
    var jsonPath: String      // 如 "$.Result.KeyNo"
    var variableName: String  // 如 "companyId"
}

/// 认证类型
enum APIAuthType: String, Codable, CaseIterable {
    case none = "none"
    case apiKey = "apiKey"
    case token = "token"      // 本地计算 Token（如 MD5）
    case bearer = "bearer"    // Bearer Token
    case custom = "custom"
}

/// HTTP 方法
enum HTTPMethod: String, Codable, CaseIterable {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

/// API 端点配置
@Model
final class APIEndpoint {
    var id: UUID = UUID()
    var name: String = ""
    var url: String = ""
    var methodRaw: String = "GET"
    var headersData: Data?
    var bodyTemplate: String?

    // 认证配置
    var authTypeRaw: String = "none"
    var authConfigData: Data?

    // 输出提取配置（用于组合）
    var outputExtractionsData: Data?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        name: String = "",
        url: String = "",
        method: HTTPMethod = .GET
    ) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.methodRaw = method.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Computed Properties

    var method: HTTPMethod {
        get { HTTPMethod(rawValue: methodRaw) ?? .GET }
        set { methodRaw = newValue.rawValue }
    }

    var authType: APIAuthType {
        get { APIAuthType(rawValue: authTypeRaw) ?? .none }
        set { authTypeRaw = newValue.rawValue }
    }

    var headers: [String: String] {
        get {
            guard let data = headersData else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            headersData = try? JSONEncoder().encode(newValue)
        }
    }

    var authConfig: [String: String] {
        get {
            guard let data = authConfigData else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            authConfigData = try? JSONEncoder().encode(newValue)
        }
    }

    var outputExtractions: [OutputExtraction] {
        get {
            guard let data = outputExtractionsData else { return [] }
            return (try? JSONDecoder().decode([OutputExtraction].self, from: data)) ?? []
        }
        set {
            outputExtractionsData = try? JSONEncoder().encode(newValue)
        }
    }
}

// MARK: - Export/Import

extension APIEndpoint {
    struct ExportData: Codable {
        var name: String
        var url: String
        var method: String
        var headers: [String: String]
        var bodyTemplate: String?
        var authType: String
        var authConfig: [String: String]
        var outputExtractions: [OutputExtraction]
    }

    func toExportData() -> ExportData {
        ExportData(
            name: name,
            url: url,
            method: methodRaw,
            headers: headers,
            bodyTemplate: bodyTemplate,
            authType: authTypeRaw,
            authConfig: authConfig,
            outputExtractions: outputExtractions
        )
    }

    static func fromExportData(_ data: ExportData) -> APIEndpoint {
        let endpoint = APIEndpoint(
            name: data.name,
            url: data.url,
            method: HTTPMethod(rawValue: data.method) ?? .GET
        )
        endpoint.headers = data.headers
        endpoint.bodyTemplate = data.bodyTemplate
        endpoint.authTypeRaw = data.authType
        endpoint.authConfig = data.authConfig
        endpoint.outputExtractions = data.outputExtractions
        return endpoint
    }
}
