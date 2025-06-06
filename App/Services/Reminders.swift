import EventKit
import Foundation
import OSLog
import Ontology

private let log = Logger.service("reminders")

final class RemindersService: Service {
    private let eventStore = EKEventStore()

    static let shared = RemindersService()

    var isActivated: Bool {
        get async {
            return EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
        }
    }

    func activate() async throws {
        try await eventStore.requestFullAccessToReminders()
    }

    var tools: [Tool] {
        Tool(
            name: "fetchReminders",
            description: "Get reminders from the reminders app with flexible filtering options",
            inputSchema: [
                "type": "object",
                "properties": [
                    "completed": [
                        "type": "boolean",
                        "description":
                            "If true, fetch completed reminders. If false, fetch incomplete reminders. If not specified, fetch all reminders.",
                    ],
                    "startDate": [
                        "type": "string",
                        "description":
                            "ISO date string for the start of the date range to fetch reminders from",
                    ],
                    "endDate": [
                        "type": "string",
                        "description":
                            "ISO date string for the end of the date range to fetch reminders from",
                    ],
                    "listNames": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description":
                            "Names of reminder lists to fetch from. If empty or not specified, fetches from all lists.",
                    ],
                    "searchText": [
                        "type": "string",
                        "description": "Text to search for in reminder titles",
                    ],
                ],
            ]
        ) { arguments in
            try await self.activate()

            guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
                log.error("Reminders access not authorized")
                throw NSError(
                    domain: "RemindersError", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Reminders access not authorized"]
                )
            }

            // Filter reminder lists based on provided names
            var reminderLists = self.eventStore.calendars(for: .reminder)
            if case let .array(listNames) = arguments["listNames"],
                !listNames.isEmpty
            {
                let requestedNames = Set(
                    listNames.compactMap { $0.stringValue?.lowercased() })
                reminderLists = reminderLists.filter {
                    requestedNames.contains($0.title.lowercased())
                }
            }

            // Parse dates if provided
            let dateFormatter = ISO8601DateFormatter()
            var startDate: Date? = nil
            var endDate: Date? = nil

            if case let .string(start) = arguments["startDate"] {
                startDate = dateFormatter.date(from: start)
            }
            if case let .string(end) = arguments["endDate"] {
                endDate = dateFormatter.date(from: end)
            }

            // Create predicate based on completion status
            let predicate: NSPredicate
            if case let .bool(completed) = arguments["completed"] {
                if completed {
                    predicate = self.eventStore.predicateForCompletedReminders(
                        withCompletionDateStarting: startDate,
                        ending: endDate,
                        calendars: reminderLists
                    )
                } else {
                    predicate = self.eventStore.predicateForIncompleteReminders(
                        withDueDateStarting: startDate,
                        ending: endDate,
                        calendars: reminderLists
                    )
                }
            } else {
                // If completion status not specified, use incomplete predicate as default
                predicate = self.eventStore.predicateForReminders(in: reminderLists)
            }

            // Fetch reminders
            let reminders = try await withCheckedThrowingContinuation { continuation in
                self.eventStore.fetchReminders(matching: predicate) { fetchedReminders in
                    continuation.resume(returning: fetchedReminders ?? [])
                }
            }

            // Apply additional filters
            var filteredReminders = reminders

            // Filter by search text if provided
            if case let .string(searchText) = arguments["searchText"],
                !searchText.isEmpty
            {
                filteredReminders = filteredReminders.filter {
                    $0.title?.localizedCaseInsensitiveContains(searchText) == true
                }
            }

            return filteredReminders.map { PlanAction($0) }
        }

        Tool(
            name: "createReminder",
            description: "Create a new reminder with specified properties",
            inputSchema: [
                "type": "object",
                "required": ["title"],
                "properties": [
                    "title": [
                        "type": "string",
                        "description": "The title of the reminder",
                    ],
                    "dueDate": [
                        "type": "string",
                        "description": "ISO date string for when the reminder is due",
                    ],
                    "listName": [
                        "type": "string",
                        "description":
                            "Name of the reminder list to add the reminder to (uses default if not specified)",
                    ],
                    "notes": [
                        "type": "string",
                        "description": "Additional notes for the reminder",
                    ],
                    "priority": [
                        "type": "integer",
                        "description": "Priority level (0 = none, 1 = low, 5 = medium, 9 = high)",
                        "default": 0,
                    ],
                    "alarms": [
                        "type": "array",
                        "items": ["type": "integer"],
                        "description": "Array of minutes before the due date to set alarms",
                    ],
                ],
            ]
        ) { arguments in
            try await self.activate()

            guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
                log.error("Reminders access not authorized")
                throw NSError(
                    domain: "RemindersError", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Reminders access not authorized"]
                )
            }

            let reminder = EKReminder(eventStore: self.eventStore)

            // Set required properties
            guard case let .string(title) = arguments["title"] else {
                throw NSError(
                    domain: "RemindersError", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Reminder title is required"]
                )
            }
            reminder.title = title

            // Set calendar (list)
            var calendar = self.eventStore.defaultCalendarForNewReminders()
            if case let .string(listName) = arguments["listName"] {
                if let matchingCalendar = self.eventStore.calendars(for: .reminder)
                    .first(where: { $0.title.lowercased() == listName.lowercased() })
                {
                    calendar = matchingCalendar
                }
            }
            reminder.calendar = calendar

            // Set optional properties
            if case let .string(dueDateStr) = arguments["dueDate"],
                let dueDate = ISO8601DateFormatter().date(from: dueDateStr)
            {
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second], from: dueDate)
            }

            if case let .string(notes) = arguments["notes"] {
                reminder.notes = notes
            }

            if case let .int(priority) = arguments["priority"] {
                reminder.priority = Int(priority)
            }

            // Set alarms
            if case let .array(alarmMinutes) = arguments["alarms"] {
                reminder.alarms = alarmMinutes.compactMap {
                    guard case let .int(minutes) = $0 else { return nil }
                    return EKAlarm(relativeOffset: TimeInterval(-minutes * 60))
                }
            }

            // Save the reminder
            try self.eventStore.save(reminder, commit: true)

            return PlanAction(reminder)
        }
    }
}
