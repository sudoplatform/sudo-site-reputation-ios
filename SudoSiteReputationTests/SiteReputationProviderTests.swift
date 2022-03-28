//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import SudoSiteReputation

class SiteReputationProviderTests: XCTestCase {

    var instanceUnderTest: SiteReputationProvider!

    var maliciousListOne: [String] = [
        "malware.com",
        "http://phishing.com"
    ]

    var maliciousListTwo: [String] = [
        "http://virus.com/bad_virus.html",
        "fishing.com/lost_credit_card.html"
    ]

    override func setUpWithError() throws {

        let rulesets: [SiteReputationRuleset] = [maliciousListOne, maliciousListTwo].map { list in
            let rules = list.compactMap({SiteReputationRule(urlString: $0)})
            return SiteReputationRuleset(key: "key",
                                                       category: "category",
                                                       name: "name",
                                                       rules: rules)
        }
        instanceUnderTest = SiteReputationProvider(rulesets: rulesets)
    }

    // An input url and the rule both must have a host, so we check only those cases
    // where either has or doesn't have a path. There are four cases to check:

    func test_inputHasPath_and_ruleHasPath() {

        let testURL = "malware.com/foo/bar/baz/virus.exe"
        let engine = SiteReputationProvider(urls: [testURL])

        // base case, testURL should be malware
        XCTAssertEqual(engine.check(url: testURL), .specificResource)

        // url has a known malware url combined with a suffix. This is a different resource.
        XCTAssertEqual(engine.check(url: testURL + "/blog/index.html") , nil)

        // test url is a prefix of the known malware url
        XCTAssertEqual(engine.check(url: testURL + "malware.com/foo/bar/baz/") == nil, true)

        // random safe url is safe
        XCTAssertEqual(engine.check(url: "google.com") == nil, true)
    }

    func test_inputHasPath_and_ruleHasNilPath() {
        let domain = "malware.com"
        let fullTestURL = domain + "/foo/bar/baz/virus.exe"
        let engine = SiteReputationProvider(urls: [domain])

        // base case. domain should be malware
        XCTAssertEqual(engine.check(url: domain), .domain)

        // domain of test url is known to be malicious, entire domain should be blocked and path ignored.
        XCTAssertEqual(engine.check(url: fullTestURL), .domain)

        // random safe url is safe
        XCTAssertEqual(engine.check(url: "google.com") == nil, true)
    }

    func test_inputNilPath_and_ruleHasPath() {
        let domain = "malware.com"
        let rule = domain + "/foo/bar/baz/virus.exe"
        let engine = SiteReputationProvider(urls: [rule])

        // base case. rule url should be malware
        XCTAssertEqual(engine.check(url: rule), .specificResource)

        // This is the shared hosting provider having a customer serving malware.
        // Domain itself should not be malware
        XCTAssertEqual(engine.check(url: domain) == nil, true)

        // random safe url is safe
        XCTAssertEqual(engine.check(url: "google.com") == nil, true)
    }

    func test_input_and_rule_hasNilPath() {
        let domain = "malware.com"
        let engine = SiteReputationProvider(urls: [domain])

        XCTAssertEqual(engine.check(url: domain), .domain)
        XCTAssertEqual(engine.check(url: "google.com") == nil, true)
    }

    func test_empty_rulesets_no_match() {
        XCTAssertNil(SiteReputationProvider(rulesets: []).check(url: "google.com"))
    }

    func test_will_check_all_lists() {
        // Ensure items from both lists can be confirmed as malicious
        XCTAssertTrue(instanceUnderTest.check(url: maliciousListOne.first!) == .domain)
        XCTAssertTrue(instanceUnderTest.check(url: maliciousListOne.last!) == .domain)

        XCTAssertTrue(instanceUnderTest.check(url: maliciousListTwo.first!) == .specificResource)
        XCTAssertTrue(instanceUnderTest.check(url: maliciousListTwo.last!) == .specificResource)
    }

    func test_subdomains() {
        let domain = "malware.com"
        let engine = SiteReputationProvider(urls: [domain])
        XCTAssertTrue(engine.check(url: "infected.subdomain.malware.com") == .subdomain)
        XCTAssertTrue(engine.check(url: "infected.subdomain.malware.com/index.html") == .subdomain)
    }
}

extension SiteReputationProvider {

    convenience init(urls: [String]) {
        self.init(
            rulesets: [SiteReputationRuleset(
                key: "",
                category: "",
                name: "",
                rules: urls.compactMap({SiteReputationRule(urlString: $0)})
            )]
        )
    }
}
