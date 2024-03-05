import Foundation

public extension Date {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    static var currentDateText: String {
        let text: String = Date.formatter.string(from: Date())
        return text
    }
}
