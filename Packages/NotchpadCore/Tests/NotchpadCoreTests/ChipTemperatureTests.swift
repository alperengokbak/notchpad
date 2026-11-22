import Testing
@testable import NotchpadCore

@Test func averagesTdieSensors() {
    #expect(ChipTemperature.average([("PMU tdie1", 50), ("PMU tdie2", 54), ("gas gauge battery", 30)]) == 52)
}

@Test func keepsDuplicateSensorNames() {
    // This M1 Pro reports every tdie name twice (two PMUs); both readings count.
    #expect(ChipTemperature.average([("PMU tdie1", 40), ("PMU tdie1", 50), ("PMU tdie2", 60)]) == 50)
}

@Test func ignoresOtherPmuSensors() {
    #expect(ChipTemperature.average([("PMU tdie0", 40), ("PMU tdev6", 90), ("PMU tcal", 52)]) == 40)
}

@Test func fallsBackToMtrSensors() {
    #expect(ChipTemperature.average([("pACC MTR Temp Sensor0", 61.4), ("eACC MTR Temp Sensor1", 58.2)]) == 60)
}

@Test func dropsInvalidValues() {
    #expect(ChipTemperature.average([("PMU tdie1", 0), ("PMU tdie2", 48), ("PMU tdie3", 65535)]) == 48)
}

@Test func nilWhenNothingUsable() {
    #expect(ChipTemperature.average([("gas gauge battery", 30)]) == nil)
    #expect(ChipTemperature.average([]) == nil)
}
