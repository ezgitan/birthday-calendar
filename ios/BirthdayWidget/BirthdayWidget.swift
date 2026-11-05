import WidgetKit
import SwiftUI

struct Person: Decodable { let name: String; let phone: String?; let month: Int; let day: Int }
struct Entry: TimelineEntry { let date: Date; let name: String; let days: Int?; let phone: String?; var needsSync: Bool = false }
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), name: "Sevdiklerin", days: 5, phone: nil) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(entry(at: Date())) }
    func entry(at date: Date) -> Entry {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let year = calendar.component(.year, from: today)
        let raw = UserDefaults(suiteName: "group.com.birthdaycalendar.shared")?.string(forKey: "birthdays")
        // Decode records independently: one legacy/malformed row must not hide all events.
        let rows = raw.flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [[String: Any]] }
        let people: [Person] = (rows ?? []).compactMap { row in
            guard let name = row["name"] as? String,
                  let month = row["month"] as? Int, (1...12).contains(month),
                  let day = row["day"] as? Int, (1...31).contains(day) else { return nil }
            let title: String
            if row["personName"] != nil { title = name }
            else {
                let type = row["type"] as? String ?? "Doğum Günü"
                let label = type == "Diğer" ? (row["customType"] as? String ?? "Özel gün") : type
                title = type == "Doğum Günü" ? "\(name) Doğum Günü" : "\(name) ile \(label)"
            }
            return Person(name: title, phone: row["phone"] as? String, month: month, day: day)
        }
        let next = people.compactMap { person -> (Person, Date)? in
            func occurrence(_ year: Int) -> Date? {
                guard let first = calendar.date(from: DateComponents(year: year, month: person.month, day: 1)),
                      let range = calendar.range(of: .day, in: .month, for: first) else { return nil }
                return calendar.date(from: DateComponents(year: year, month: person.month, day: min(person.day, range.count)))
            }
            guard var target = occurrence(year) else { return nil }
            if target < today { guard let later = occurrence(year + 1) else { return nil }; target = later }
            return (person, target)
        }.min { $0.1 < $1.1 }
        return Entry(date: date, name: next?.0.name ?? (raw == nil ? "Günlerini bağlayalım" : "Güzel günler biriktir"), days: next.flatMap { calendar.dateComponents([.day], from: today, to: $0.1).day }, phone: next?.0.phone, needsSync: raw == nil || rows == nil)
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let entries = (0..<8).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }.map { entry(at: $0) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
struct BirthdayView: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family
    private let ink = Color(red: 0.25, green: 0.20, blue: 0.32)
    private let accent = Color(red: 0.50, green: 0.38, blue: 0.66)
    var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: entry.days == nil ? "sparkles" : "gift")
                Text("iyi ki").fontWeight(.medium)
            }.font(.caption).foregroundColor(accent)
            Text(entry.name).font(.system(size: family == .systemSmall ? 17 : 20, weight: .semibold, design: .rounded))
                .foregroundColor(ink).lineLimit(2).minimumScaleFactor(0.8)
            Text(entry.days.map { $0 == 0 ? "Bugün! 🎉" : ($0 == 1 ? "Yarın! 🎈" : "\($0) gün kaldı") }
                 ?? (entry.needsSync ? "Eşitlemek için uygulamayı aç." : "İlk özel gününü eklemek için dokun."))
                .font(.system(size: 13)).foregroundColor(accent).lineLimit(2)
            if family != .systemSmall, let number = entry.phone, !number.isEmpty,
               let call = URL(string: "iyiki-contact://call/" + number),
               let chat = URL(string: "iyiki-contact://chat/" + number) {
                HStack(spacing: 18) {
                    Link(destination: call) { Label("Ara", systemImage: "phone") }
                    Link(destination: chat) { Label("WhatsApp", systemImage: "message") }
                }.font(.caption).foregroundColor(accent)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
    var body: some View {
        if #available(iOS 17.0, *) { content.containerBackground(Color(red: 0.957, green: 0.929, blue: 0.980), for: .widget) }
        else { content.padding().background(Color(red: 0.957, green: 0.929, blue: 0.980)) }
    }
}
@main
struct BirthdayWidget: Widget {
    let kind = "BirthdayWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { BirthdayView(entry: $0) }
            .configurationDisplayName("İyi ki").description("Sıradaki özel gün hep aklında.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
