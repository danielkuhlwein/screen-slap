//
//  MeetingURLParserTests.swift
//  screen-slapTests
//

import XCTest
@testable import screen_slap

final class MeetingURLParserTests: XCTestCase {

    // MARK: - Zoom

    func testZoomBasicURL() {
        let text = "Join Zoom: https://zoom.us/j/1234567890"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("zoom.us"))
    }

    func testZoomWithPassword() {
        let text = "https://zoom.us/j/1234567890?pwd=abc123def"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("pwd=abc123def"))
    }

    func testZoomWebinar() {
        let text = "https://zoom.us/w/1234567890"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
    }

    func testZoomGov() {
        let text = "https://company.zoomgov.com/j/1234567890"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
    }

    func testZoomSubdomain() {
        let text = "https://company.zoom.us/j/1234567890"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
    }

    // MARK: - Google Meet

    func testGoogleMeetURL() {
        let text = "Join at https://meet.google.com/abc-defg-hij"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "meet.google.com")
    }

    // MARK: - Microsoft Teams

    func testTeamsURL() {
        let text = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc123"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("teams.microsoft.com"))
    }

    func testTeamsLiveURL() {
        let text = "https://teams.live.com/meet/9312345678"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
    }

    // MARK: - Webex

    func testWebexURL() {
        let text = "https://company.webex.com/company/j.php?MTID=abc123"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
    }

    // MARK: - Slack Huddle

    func testSlackHuddleURL() {
        let text = "https://app.slack.com/huddle/T0123ABC/C0456DEF"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
    }

    // MARK: - GoTo

    func testGoToMeetingURL() {
        let text = "https://global.gotomeeting.com/join/1234567890"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
    }

    func testGoToNewURL() {
        let text = "https://app.goto.com/meeting/1234567890"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
    }

    // MARK: - Other Providers

    func testWherebyURL() {
        let text = "https://whereby.com/my-meeting-room"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
    }

    func testSkypeURL() {
        let text = "https://join.skype.com/abc123xyz"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
    }

    func testJitsiURL() {
        let text = "https://meet.jit.si/my-meeting-room"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
    }

    func testFaceTimeURL() {
        let text = "https://facetime.apple.com/join#v=1&p=abc&k=123"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
    }

    func testDiscordURL() {
        let text = "https://discord.gg/abc123xyz"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
    }

    func testBlueJeansURL() {
        let text = "https://bluejeans.com/1234567890"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
    }

    func testChimeURL() {
        let text = "https://chime.aws/1234567890"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
    }

    func testRingCentralURL() {
        let text = "https://meetings.ringcentral.com/j/1234567890"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
    }

    // MARK: - Edge Cases

    func testNoURLReturnsNil() {
        let text = "This is just regular text with no meeting URLs"
        XCTAssertNil(MeetingURLParser.findMeetingURL(in: text))
    }

    func testNonMeetingURLReturnsNil() {
        let text = "Check out https://www.google.com for more info"
        XCTAssertNil(MeetingURLParser.findMeetingURL(in: text))
    }

    func testEmptyStringReturnsNil() {
        XCTAssertNil(MeetingURLParser.findMeetingURL(in: ""))
    }

    func testURLInHTMLContext() {
        let text = "<a href=\"https://zoom.us/j/1234567890\">Join</a>"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
    }

    func testMultipleURLsReturnsFirst() {
        let text = "Zoom: https://zoom.us/j/111 or Meet: https://meet.google.com/abc-defg-hij"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("zoom.us"))
    }

    func testURLAmidstMultilineText() {
        let text = """
        Hi team,

        Please join the meeting at https://zoom.us/j/1234567890?pwd=secret

        Thanks,
        John
        """
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("zoom.us"))
    }

    func testCaseInsensitiveMatching() {
        let text = "HTTPS://ZOOM.US/j/1234567890"
        let url = MeetingURLParser.findMeetingURL(in: text)
        XCTAssertNotNil(url)
    }

    // MARK: - Provider Detection

    func testProviderZoom() {
        let url = URL(string: "https://zoom.us/j/1234567890")!
        XCTAssertEqual(MeetingURLParser.provider(for: url), .zoom)
    }

    func testProviderZoomGov() {
        let url = URL(string: "https://company.zoomgov.com/j/1234567890")!
        XCTAssertEqual(MeetingURLParser.provider(for: url), .zoom)
    }

    func testProviderGoogleMeet() {
        let url = URL(string: "https://meet.google.com/abc-defg-hij")!
        XCTAssertEqual(MeetingURLParser.provider(for: url), .googleMeet)
    }

    func testProviderTeams() {
        let url = URL(string: "https://teams.microsoft.com/l/meetup-join/abc")!
        XCTAssertEqual(MeetingURLParser.provider(for: url), .teams)
    }

    func testProviderTeamsLive() {
        let url = URL(string: "https://teams.live.com/meet/abc")!
        XCTAssertEqual(MeetingURLParser.provider(for: url), .teams)
    }

    func testProviderWebex() {
        let url = URL(string: "https://company.webex.com/meet/abc")!
        XCTAssertEqual(MeetingURLParser.provider(for: url), .webex)
    }

    func testProviderSlack() {
        let url = URL(string: "https://app.slack.com/huddle/abc")!
        XCTAssertEqual(MeetingURLParser.provider(for: url), .slack)
    }

    func testProviderGoToMeeting() {
        let url = URL(string: "https://global.gotomeeting.com/join/abc")!
        XCTAssertEqual(MeetingURLParser.provider(for: url), .goTo)
    }

    func testProviderGoToNew() {
        let url = URL(string: "https://app.goto.com/meeting/abc")!
        XCTAssertEqual(MeetingURLParser.provider(for: url), .goTo)
    }

    func testProviderWhereby() {
        let url = URL(string: "https://whereby.com/my-room")!
        XCTAssertEqual(MeetingURLParser.provider(for: url), .whereby)
    }

    func testProviderSkype() {
        let url = URL(string: "https://join.skype.com/abc")!
        XCTAssertEqual(MeetingURLParser.provider(for: url), .skype)
    }

    func testProviderJitsi() {
        let url = URL(string: "https://meet.jit.si/my-room")!
        XCTAssertEqual(MeetingURLParser.provider(for: url), .jitsi)
    }

    func testProviderFaceTime() {
        let url = URL(string: "https://facetime.apple.com/join#abc")!
        XCTAssertEqual(MeetingURLParser.provider(for: url), .facetime)
    }

    func testProviderDiscord() {
        let url = URL(string: "https://discord.gg/abc")!
        XCTAssertEqual(MeetingURLParser.provider(for: url), .discord)
    }

    func testProviderUnknown() {
        let url = URL(string: "https://example.com/meeting")!
        XCTAssertEqual(MeetingURLParser.provider(for: url), .other)
    }

    // MARK: - MeetingProvider Properties

    func testAllProvidersHaveIcons() {
        for provider in MeetingProvider.allCases {
            XCTAssertFalse(provider.iconName.isEmpty, "\(provider.rawValue) has no icon")
        }
    }

    func testAllProvidersHaveIDs() {
        for provider in MeetingProvider.allCases {
            XCTAssertFalse(provider.id.isEmpty, "\(provider.rawValue) has no ID")
        }
    }
}
