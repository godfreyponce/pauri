import AppKit
import Testing
@testable import Pauri

private let mexicoCity = TimeZone(identifier: "America/Mexico_City")!
private let reykjavik = TimeZone(identifier: "Atlantic/Reykjavik")!

private func noon(_ year: Int, _ month: Int, _ day: Int, in zone: TimeZone) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
}

private func minutes(_ hours: Double) -> Int { Int((hours * 60).rounded()) }

@Test func mexicoCitySunriseAndSunsetMatchTheAlmanac() {
    // 2026-11-13: sunrise 06:43, sunset 17:58 (the design page's figures for Mexico City).
    let sun = DaySchedule.sunTimes(at: Place(latitude: 19.4, longitude: -99.15),
                                   on: noon(2026, 11, 13, in: mexicoCity), in: mexicoCity)
    #expect(abs(minutes(sun.rise) - (6 * 60 + 43)) <= 5)
    #expect(abs(minutes(sun.set) - (17 * 60 + 58)) <= 5)
}

@Test func shortWinterDayKeepsTheTenFramesInOrder() {
    let sun = DaySchedule.sunTimes(at: Place(latitude: 64.15, longitude: -21.85),
                                   on: noon(2026, 11, 13, in: reykjavik), in: reykjavik)
    let starts = DaySchedule.starts(sun)
    #expect(starts.map(\.scene) == OrbScene.allCases)
    let first = starts[0].hour
    let offsets = starts.map { DaySchedule.wrap($0.hour - first) }
    #expect(offsets == offsets.sorted())
    #expect(Set(offsets).count == offsets.count)
}

@Test func scenesCrossFadeBeforeTheNextStart() {
    let starts = DaySchedule.starts(.clockOnly)
    // Meadow starts at 7:30. Twenty minutes before, dawn and meadow share the orb.
    let fading = DaySchedule.weights(atHour: 7.5 - 20.0 / 60, starts: starts)
    #expect(abs(fading[.dawn, default: 0] - 0.5) < 0.001)
    #expect(abs(fading[.meadow, default: 0] - 0.5) < 0.001)
    #expect(abs(fading.values.reduce(0, +) - 1) < 0.001)
    #expect(DaySchedule.weights(atHour: 13, starts: starts) == [.sky: 1])
    #expect(DaySchedule.weights(atHour: 2, starts: starts) == [.moon: 1])
}

@Test func timeZoneNamesItsPlaceFromZoneTab() {
    let zoneTab = """
    # comment line
    MX\t+1924-09909\tAmerica/Mexico_City\tCentral Mexico
    US\t+404251-0740023\tAmerica/New_York\tEastern (most areas)
    """
    #expect(DaySchedule.place(for: "America/Mexico_City", zoneTab: zoneTab) == Place(latitude: 19.4, longitude: -99.15))
    let newYork = DaySchedule.place(for: "America/New_York", zoneTab: zoneTab)
    #expect(abs((newYork?.latitude ?? 0) - 40.7142) < 0.001)
    #expect(abs((newYork?.longitude ?? 0) + 74.0064) < 0.001)
    #expect(DaySchedule.place(for: "Mars/Olympus_Mons", zoneTab: zoneTab) == nil)
}

@Test func theMacsZoneTabListsCommonZones() throws {
    let zoneTab = try String(contentsOfFile: DaySchedule.zoneTabPath, encoding: .utf8)
    #expect(DaySchedule.place(for: "America/Mexico_City", zoneTab: zoneTab) != nil)
    #expect(DaySchedule.place(for: "Europe/London", zoneTab: zoneTab) != nil)
}
