@testable import TokenChecker
import XCTest

final class CodexDirectUsageAPIClientTests: XCTestCase {
    func testDecodesWhamUsagePayloadUnderRateLimitKey() throws {
        let json = """
        {
          "rate_limit": {
            "primary_window": {
              "used_percent": 27.5,
              "reset_at": 1760000000
            },
            "secondary_window": {
              "used_percent": 82,
              "reset_at": 1760604800
            }
          }
        }
        """

        let dto = try JSONDecoder().decode(CodexDirectUsageDTO.self, from: Data(json.utf8))
        let usage = dto.toServiceUsage()

        XCTAssertEqual(usage.fiveHour?.utilization, 0.275)
        XCTAssertEqual(usage.fiveHour?.resetsAt.timeIntervalSince1970, 1_760_000_000)
        XCTAssertEqual(usage.weekly?.utilization, 0.82)
        XCTAssertEqual(usage.weekly?.resetsAt.timeIntervalSince1970, 1_760_604_800)
        XCTAssertNil(usage.weeklySonnet)
    }

    func testDecodesWhamUsagePayloadAtRootForCompatibility() throws {
        let json = """
        {
          "primary_window": {
            "used_percent": 10,
            "reset_at": 1760000000
          }
        }
        """

        let dto = try JSONDecoder().decode(CodexDirectUsageDTO.self, from: Data(json.utf8))
        let usage = dto.toServiceUsage()

        XCTAssertEqual(usage.fiveHour?.utilization, 0.1)
        XCTAssertNil(usage.weekly)
    }

    func testExtractsAccountIdFromIdToken() throws {
        let payload = #"{"https://api.openai.com/auth":{"chatgpt_account_id":"acct_123"}}"#
        let encoded = Data(payload.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let token = "header.\(encoded).signature"

        XCTAssertEqual(CodexDirectUsageAPIClient.extractAccountId(from: token), "acct_123")
    }
}
