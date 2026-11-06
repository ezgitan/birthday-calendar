import Foundation
import OSLog

// Compiled into Runner and BirthdayWidget. Only widget display data crosses the sandbox boundary.
struct WidgetEvent: Codable, Equatable {
    let name: String
    let phone: String?
    let month: Int
    let day: Int

    var isValid: Bool {
        !name.isEmpty && (1...12).contains(month) && (1...31).contains(day)
    }
}

struct WidgetSnapshot: Codable {
    let schema: Int
    let revision: UUID
    let events: [WidgetEvent]
}

enum WidgetStoreError: String, Error {
    case groupUnavailable, snapshotMissing, readFailed, invalidSnapshot, writeFailed, verificationFailed
}

enum WidgetStore {
    static let group = "group.com.birthdaycalendar.shared"
    static let kind = "BirthdayWidget"
    static let log = Logger(subsystem: "com.birthdaycalendar.widgetSync", category: "snapshot")

    private static func location() throws -> URL {
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
            throw WidgetStoreError.groupUnavailable
        }
        return directory.appendingPathComponent("widget-birthdays-v1.json")
    }

    static func read() throws -> WidgetSnapshot {
        let url = try location()
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
                throw WidgetStoreError.snapshotMissing
            }
            throw WidgetStoreError.readFailed
        }
        guard let result = try? JSONDecoder().decode(WidgetSnapshot.self, from: data),
              result.schema == 1, result.events.allSatisfy({ $0.isValid }) else {
            throw WidgetStoreError.invalidSnapshot
        }
        return result
    }

    static func publish(_ data: Data) throws -> WidgetSnapshot {
        let url = try location()
        guard let events = try? JSONDecoder().decode([WidgetEvent].self, from: data),
              events.allSatisfy({ $0.isValid }) else { throw WidgetStoreError.invalidSnapshot }
        if let existing = try? read(), existing.events == events { return existing }
        let snapshot = WidgetSnapshot(schema: 1, revision: UUID(), events: events)
        do {
            try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
        } catch { throw WidgetStoreError.writeFailed }
        let confirmed = try read()
        guard confirmed.revision == snapshot.revision && confirmed.events == events else {
            throw WidgetStoreError.verificationFailed
        }
        return confirmed
    }
}
