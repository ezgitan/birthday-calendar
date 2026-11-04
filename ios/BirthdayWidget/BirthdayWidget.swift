import WidgetKit
import SwiftUI

struct Person: Decodable { let name: String; let phone: String?; let month: Int; let day: Int }
struct Entry: TimelineEntry { let date: Date; let name: String; let days: Int?; let phone: String? }
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), name: "Sevdiklerin", days: 5, phone: nil) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(entry(at: Date())) }
    func entry(at date: Date) -> Entry {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let year = calendar.component(.year, from: today)
        let raw = UserDefaults(suiteName: "group.com.birthdaycalendar.shared")?.string(forKey: "birthdays") ?? "[]"
        let people = (try? JSONDecoder().decode([Person].self, from: Data(raw.utf8))) ?? []
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
        return Entry(date: date, name: next?.0.name ?? "Bir özel gün ekle", days: next.flatMap { calendar.dateComponents([.day], from: today, to: $0.1).day }, phone: next?.0.phone)
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
    var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("iyi ki • SIRADAKİ GÜZEL GÜN").font(.caption2).foregroundColor(.purple)
            Text(entry.name).font(.title3.bold()).lineLimit(2)
            Text(entry.days.map { $0 == 0 ? "Bugün kutlama zamanı!" : "\($0) gün kaldı" } ?? "Sevdiklerin hep aklında.").font(.subheadline).foregroundColor(.purple)
            if let number = entry.phone, !number.isEmpty,
               let call = URL(string: "iyiki-contact://call/" + number),
               let chat = URL(string: "iyiki-contact://chat/" + number) {
                HStack(spacing: 22) {
                    Link(destination: call) { Label("Ara", systemImage: "phone") }
                    Link(destination: chat) { Label("WhatsApp", systemImage: "message") }
                }.font(.caption)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
    var body: some View {
        if #available(iOS 17.0, *) { content.containerBackground(Color(red: 0.94, green: 0.91, blue: 0.97), for: .widget) }
        else { content.padding().background(Color(red: 0.94, green: 0.91, blue: 0.97)) }
    }
}
@main
struct BirthdayWidget: Widget {
    let kind = "BirthdayWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { BirthdayView(entry: $0) }
            .configurationDisplayName("İyi ki").description("Sıradaki özel gün hep aklında.")
            .supportedFamilies([.systemMedium])
    }
}
