import OSLog
import WidgetKit
import SwiftUI


struct Entry: TimelineEntry { let date: Date; let name: String; let days: Int?; let phone: String?; var issue: String? = nil }
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), name: "Sevdiklerin", days: 5, phone: nil) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: Date(), snapshot: readSnapshot()))
    }
    private func readSnapshot() -> Result<WidgetSnapshot, WidgetStoreError> {
        do {
            let snapshot = try WidgetStore.read()
            WidgetStore.log.info("widget readOK revision=\(snapshot.revision.uuidString, privacy: .public) count=\(snapshot.events.count, privacy: .public)")
            return .success(snapshot)
        } catch {
            let reason = (error as? WidgetStoreError) ?? .readFailed
            WidgetStore.log.error("widget readFailed reason=\(reason.rawValue, privacy: .public)")
            return .failure(reason)
        }
    }
    private func entry(at date: Date, snapshot: Result<WidgetSnapshot, WidgetStoreError>) -> Entry {
        let events: [WidgetEvent]
        switch snapshot {
        case .success(let value): events = value.events
        case .failure(let reason):
            let message: String
            switch reason {
            case .groupUnavailable: message = "Ortak alan erişimi yok. İmzalama yetkisini kontrol et."
            case .snapshotMissing: message = "Eşitlemek için uygulamayı aç."
            default: message = "Kayıtlar okunamadı. Uygulamayı açıp yeniden dene."
            }
            return Entry(date: date, name: "Günlerini bağlayalım", days: nil, phone: nil, issue: message)
        }
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: date)
        let year = calendar.component(.year, from: today)
        let next = events.compactMap { person -> (WidgetEvent, Date)? in
            func occurrence(_ year: Int) -> Date? {
                guard let first = calendar.date(from: DateComponents(year: year, month: person.month, day: 1)),
                      let range = calendar.range(of: .day, in: .month, for: first) else { return nil }
                return calendar.date(from: DateComponents(year: year, month: person.month, day: min(person.day, range.count)))
            }
            guard var target = occurrence(year) else { return nil }
            if target < today { guard let later = occurrence(year + 1) else { return nil }; target = later }
            return (person, target)
        }.min { $0.1 < $1.1 }
        return Entry(date: date, name: next?.0.name ?? "Güzel günler biriktir", days: next.flatMap { calendar.dateComponents([.day], from: today, to: $0.1).day }, phone: next?.0.phone)
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let snapshot = readSnapshot()
        if case .failure = snapshot {
            let now = Date()
            completion(Timeline(entries: [entry(at: now, snapshot: snapshot)], policy: .after(now.addingTimeInterval(900))))
            return
        }
        let entries = (0..<8).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }.map { entry(at: $0, snapshot: snapshot) }
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
                 ?? (entry.issue ?? "İlk özel gününü eklemek için dokun."))
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
    let kind = WidgetStore.kind
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { BirthdayView(entry: $0) }
            .configurationDisplayName("İyi ki").description("Sıradaki özel gün hep aklında.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
