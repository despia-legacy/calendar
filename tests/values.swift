import Foundation
import CoreFoundation
import EventKit
import CoreLocation
func check(_ value: @autoclosure () throws -> Bool) rethrows { if try !value() { fatalError("invalid value accepted") } }
func reject(_ body: () throws -> Any) { do { _=try body();fatalError("invalid value accepted") } catch {} }
try check(CalendarValues.date(NSNumber(value:1700000000000)).timeIntervalSince1970 == 1700000000)
try check(CalendarValues.object("{\"title\":\"Event\"}")["title"] as? String == "Event")
for value in ["[]","null","not JSON"] { reject { try CalendarValues.object(value) } }
reject { try CalendarValues.number(NSNumber(value:true)) }
reject { try CalendarValues.number(NSNumber(value:Double.infinity)) }
reject { try CalendarValues.date("1700000000000") }
print("PASS: calendar JSON, finite coordinates and dates reject invalid values")

let relative = EKAlarm(relativeOffset: -300)
let relativeFields = CalendarValues.alarm(relative)
try check(relativeFields["minutes"] as? Double == 5)
try check(CalendarValues.makeAlarm(relativeFields).relativeOffset == -300)
let absoluteDate = Date(timeIntervalSince1970: 1700000000)
let absolute = EKAlarm(absoluteDate: absoluteDate)
let absoluteFields = CalendarValues.alarm(absolute)
check(absoluteFields["minutes"] == nil)
try check(CalendarValues.makeAlarm(absoluteFields).absoluteDate == absoluteDate)
let located = EKAlarm(relativeOffset: 0)
let location = EKStructuredLocation(title: "Alarm boundary")
location.geoLocation = CLLocation(latitude: 25.2, longitude: 55.3)
location.radius = 100
located.structuredLocation = location
located.proximity = .enter
let locationFields = CalendarValues.alarm(located)
check(locationFields["minutes"] == nil)
let locationRoundtrip = try CalendarValues.makeAlarm(locationFields)
check(locationRoundtrip.proximity == .enter)
check(locationRoundtrip.structuredLocation?.geoLocation?.coordinate.latitude == 25.2)
check(locationRoundtrip.structuredLocation?.radius == 100)
reject { try CalendarValues.makeAlarm(["ios": ["absolute_ms": "invalid"]]) }
reject { try CalendarValues.makeAlarm(["ios": ["structured_location": ["latitude": 25.2], "proximity": 1]]) }
print("PASS: native EventKit relative, absolute and location alarm round-trips")
