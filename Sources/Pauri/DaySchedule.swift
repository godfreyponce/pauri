import Foundation

/// The send orb's ten scenes, in the order they come through the day.
enum OrbScene: CaseIterable, Sendable {
    case blueHour, dawn, meadow, seaside, sky, golden, harbor, town, forest, moon
}

struct Place: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
}

/// Sunrise and sunset in local hours, such as 6.5 for 6:30.
struct SunTimes: Equatable, Sendable {
    var rise: Double
    var set: Double

    /// For a time zone that zone.tab does not list.
    static let clockOnly = SunTimes(rise: 6.5, set: 19)
}

/// Which scene the send orb shows at a given time and place. Ported from `design-directions/issue-10.html`.
enum DaySchedule {
    static let zoneTabPath = "/usr/share/zoneinfo/zone.tab"
    static let fadeHours = 40.0 / 60

    private static let zoneTab = try? String(contentsOfFile: zoneTabPath, encoding: .utf8)

    /// The sun at the Mac's time zone's place today, read from zone.tab, so no location permission is needed.
    static func currentSun(now: Date = .now, timeZone: TimeZone = .current) -> SunTimes {
        guard let zoneTab, let place = place(for: timeZone.identifier, zoneTab: zoneTab) else { return .clockOnly }
        return sunTimes(at: place, on: now, in: timeZone)
    }

    /// The hours since local midnight.
    static func hour(of date: Date, in timeZone: TimeZone) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return date.timeIntervalSince(calendar.startOfDay(for: date)) / 3600
    }

    /// NOAA's approximate sunrise and sunset for the local day that holds `date`.
    static func sunTimes(at place: Place, on date: Date, in timeZone: TimeZone) -> SunTimes {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = timeZone
        let day = local.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let midnight = utc.date(from: day)!
        let dayOfYear = Double(utc.ordinality(of: .day, in: .year, for: midnight)! - 1)

        let g = 2 * Double.pi / 365 * dayOfYear
        let eqTime = 229.18 * (0.000075 + 0.001868 * cos(g) - 0.032077 * sin(g)
            - 0.014615 * cos(2 * g) - 0.040849 * sin(2 * g))
        let decl = 0.006918 - 0.399912 * cos(g) + 0.070257 * sin(g) - 0.006758 * cos(2 * g)
            + 0.000907 * sin(2 * g) - 0.002697 * cos(3 * g) + 0.00148 * sin(3 * g)
        let lat = place.latitude * .pi / 180
        let cosHa = cos(90.833 * .pi / 180) / (cos(lat) * cos(decl)) - tan(lat) * tan(decl)
        let ha = acos(min(1, max(-1, cosHa))) * 180 / .pi

        func localHour(utcMinutes: Double) -> Double {
            hour(of: midnight.addingTimeInterval(utcMinutes * 60), in: timeZone)
        }
        return SunTimes(rise: localHour(utcMinutes: 720 - 4 * (place.longitude + ha) - eqTime),
                        set: localHour(utcMinutes: 720 - 4 * (place.longitude - ha) - eqTime))
    }

    /// When each scene starts. Daytime scenes sit at fractions of the day, so a short winter day keeps them in order.
    static func starts(_ sun: SunTimes) -> [(hour: Double, scene: OrbScene)] {
        let day = sun.set - sun.rise, night = 24 - day
        return [
            (sun.rise - 1.25, .blueHour),
            (sun.rise - 0.25, .dawn),
            (sun.rise + 0.08 * day, .meadow),
            (sun.rise + 0.25 * day, .seaside),
            (sun.rise + 0.45 * day, .sky),
            (sun.rise + 0.70 * day, .golden),
            (sun.rise + 0.88 * day, .harbor),
            (sun.set + 0.25, .town),
            (sun.set + 1.25, .forest),
            (sun.set + 0.4 * night, .moon),
        ]
    }

    /// Opacity per scene at `hour`: the current scene, cross-fading into the next one before it starts.
    /// The fade is 40 minutes, or 60% of the current scene when that is shorter.
    static func weights(atHour hour: Double, starts: [(hour: Double, scene: OrbScene)]) -> [OrbScene: Double] {
        var current = starts.count - 1
        for k in starts.indices where wrap(hour - starts[k].hour) < wrap(hour - starts[current].hour) {
            current = k
        }
        let next = starts[(current + 1) % starts.count]
        let untilNext = wrap(next.hour - hour)
        let fade = min(fadeHours, 0.6 * wrap(next.hour - starts[current].hour))
        let mix = untilNext < fade ? 1 - untilNext / fade : 0
        var weights = [starts[current].scene: 1 - mix]
        if mix > 0 { weights[next.scene, default: 0] += mix }
        return weights
    }

    /// `hours` folded into 0..<24.
    static func wrap(_ hours: Double) -> Double {
        let r = hours.truncatingRemainder(dividingBy: 24)
        return r < 0 ? r + 24 : r
    }

    /// The place zone.tab gives for a time zone, from its ISO 6709 column such as `+1924-09909`.
    static func place(for identifier: String, zoneTab: String) -> Place? {
        for line in zoneTab.split(separator: "\n") where !line.hasPrefix("#") {
            let fields = line.split(separator: "\t")
            guard fields.count >= 3, fields[2] == identifier else { continue }
            let coordinates = Array(fields[1])
            guard let split = coordinates.indices.dropFirst().first(where: { "+-".contains(coordinates[$0]) }),
                  let latitude = angle(coordinates[..<split], degreeDigits: 2),
                  let longitude = angle(coordinates[split...], degreeDigits: 3) else { return nil }
            return Place(latitude: latitude, longitude: longitude)
        }
        return nil
    }

    /// `±DDMM` or `±DDMMSS` (three degree digits for longitude) in degrees.
    private static func angle(_ text: ArraySlice<Character>, degreeDigits: Int) -> Double? {
        guard let sign = text.first, "+-".contains(sign) else { return nil }
        let digits = text.dropFirst().compactMap(\.wholeNumberValue)
        guard digits.count == text.count - 1, [degreeDigits + 2, degreeDigits + 4].contains(digits.count) else { return nil }
        func number(_ range: Range<Int>) -> Double { Double(range.reduce(0) { $0 * 10 + digits[$1] }) }
        let degrees = number(0..<degreeDigits)
        let minutes = number(degreeDigits..<degreeDigits + 2)
        let seconds = digits.count > degreeDigits + 2 ? number(degreeDigits + 2..<digits.count) : 0
        return (sign == "-" ? -1 : 1) * (degrees + minutes / 60 + seconds / 3600)
    }
}
