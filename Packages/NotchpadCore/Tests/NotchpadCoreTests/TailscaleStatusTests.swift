import Foundation
import Testing
@testable import NotchpadCore

private func fixture() throws -> Data {
    let url = try #require(Bundle.module.url(forResource: "tailscale-status", withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

private func json(state: String) -> Data { Data(#"{"BackendState": "\#(state)"}"#.utf8) }

@Test func parsesStateAndSortsDevices() throws {
    let s = try #require(TailscaleStatus.parse(try fixture()))
    #expect(s.state == .connected)
    #expect(s.devices.map(\.name) == ["alperens-mac", "nas", "work-laptop", "iphone"])
    #expect(s.devices[0].isSelf)
    #expect(s.devices[0].ipv4 == "100.64.0.1")
    #expect(s.devices.last?.isOnline == false)
}

@Test func deviceFallsBackToDNSNameAndMissingIPv4() throws {
    let s = try #require(TailscaleStatus.parse(try fixture()))
    let nas = try #require(s.devices.first { $0.name == "nas" })
    #expect(nas.ipv4 == nil)
    #expect(!nas.isSelf)
}

@Test func backendStatesMap() {
    #expect(TailscaleStatus.parse(json(state: "Stopped"))?.state == .notConnected)
    #expect(TailscaleStatus.parse(json(state: "Starting"))?.state == .connecting)
    #expect(TailscaleStatus.parse(json(state: "NeedsLogin"))?.state == .needsLogin)
    #expect(TailscaleStatus.parse(json(state: "NeedsMachineAuth"))?.state == .needsLogin)
    #expect(TailscaleStatus.parse(json(state: "Weird"))?.state == .notConnected)
    #expect(TailscaleStatus.parse(json(state: "Stopped"))?.devices.isEmpty == true)
}

@Test func stateTextMatchesCopy() {
    #expect(TailscaleState.connected.text == "Connected")
    #expect(TailscaleState.notConnected.text == "Not connected")
    #expect(TailscaleState.connecting.text == "Connecting…")
    #expect(TailscaleState.needsLogin.text == "Log in needed")
    #expect(TailscaleState.notInstalled.text == "Tailscale isn't installed")
}

@Test func garbageJSONParsesToNil() {
    #expect(TailscaleStatus.parse(Data("nope".utf8)) == nil)
    #expect(TailscaleStatus.parse(Data("[1,2]".utf8)) == nil)
}
