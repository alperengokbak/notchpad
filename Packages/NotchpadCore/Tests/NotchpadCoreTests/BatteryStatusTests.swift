import Testing
@testable import NotchpadCore

private func status(_ d: [String: Any]) -> BatteryStatus? { BatteryStatus(description: d) }

@Test func parsesOnBattery() {
    let b = status(["Current Capacity": 84, "Max Capacity": 100, "Power Source State": "Battery Power",
                    "Is Charging": false, "Time to Empty": 220])!
    #expect(b.percent == 84)
    #expect(!b.isPluggedIn)
    #expect(b.detailText == "3:40 left")
}

@Test func chargingWithTimeToFull() {
    let b = status(["Current Capacity": 60, "Max Capacity": 100, "Power Source State": "AC Power",
                    "Is Charging": true, "Time to Full Charge": 70])!
    #expect(b.isPluggedIn)
    #expect(b.isCharging)
    #expect(b.detailText == "1:10 to full")
}

@Test func detailTextForCalculatingAndPluggedInNotCharging() {
    #expect(status(["Current Capacity": 50, "Max Capacity": 100, "Power Source State": "Battery Power",
                    "Is Charging": false, "Time to Empty": -1])!.detailText == "Calculating…")
    #expect(status(["Current Capacity": 50, "Max Capacity": 100, "Power Source State": "AC Power",
                    "Is Charging": true, "Time to Full Charge": -1])!.detailText == "Charging")
    #expect(status(["Current Capacity": 100, "Max Capacity": 100, "Power Source State": "AC Power",
                    "Is Charging": false])!.detailText == "Plugged in")
}

@Test func shortTimesPadMinutes() {
    #expect(status(["Current Capacity": 10, "Max Capacity": 100, "Power Source State": "Battery Power",
                    "Is Charging": false, "Time to Empty": 5])!.detailText == "0:05 left")
}

@Test func nonHundredMaxCapacityIsScaled() {
    #expect(status(["Current Capacity": 4000, "Max Capacity": 5000, "Power Source State": "Battery Power"])!.percent == 80)
}

@Test func missingCapacityReturnsNil() {
    #expect(status([:]) == nil)
}

@Test func zeroMinutesToFullSaysCharging() {
    #expect(status(["Current Capacity": 100, "Max Capacity": 100, "Power Source State": "AC Power",
                    "Is Charging": true, "Time to Full Charge": 0])!.detailText == "Charging")
}
