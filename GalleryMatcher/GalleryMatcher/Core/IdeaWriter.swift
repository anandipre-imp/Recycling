import Foundation

/// Writes titles and hooks without any language model, so every iPhone gets good copy —
/// not just the ones with Apple Intelligence.
///
/// Each theme has several templates. Placeholders are filled from what we know about the
/// clips; templates that need something we don't have (e.g. a place name) are skipped.
/// The choice is seeded by the group's videos, so the same group always reads the same
/// way while different groups get variety.
enum IdeaWriter {
    struct Context {
        var theme: Theme
        var place: String?
        var startDate: Date?
        var clipCount: Int
        var hasPeople: Bool
        /// Stable per group; picks which template variant is used.
        var seed: Int
    }

    private struct Copy {
        let titles: [String]
        let hooks: [String]
    }

    /// Placeholders: {place}, {month} ("July"), {year}, {count}.
    private static let copy: [String: Copy] = [
        "travel": Copy(
            titles: ["{place} in {count} clips", "{place}, {month} {year}", "Trip recap: {place}", "{month} trip recap", "Out of office, {year}"],
            hooks: ["POV: you finally booked the trip", "{place} in 30 seconds", "Save this for your next trip to {place}", "Take me back to {month}"]
        ),
        "beach": Copy(
            titles: ["Beach days in {place}", "Salt water, {month} {year}", "Beach days", "Shoreline diaries"],
            hooks: ["Take me back to {place}", "My happy place, in 30 seconds", "Sound on for the waves", "This is your sign to book the beach"]
        ),
        "food": Copy(
            titles: ["Everything I ate in {place}", "What I ate in {month}", "The {month} food diary", "Eating my way through {place}"],
            hooks: ["Rating everything I ate in {place}", "Don't watch this hungry", "{count} bites, zero regrets", "Save this for your next food spot"]
        ),
        "pets": Copy(
            titles: ["Pet moments, {month} {year}", "The main character", "{count} reasons I love this pet", "Pet cam: {month}"],
            hooks: ["My pet is the main character, here's proof", "Wait for the last one", "Rate this good behaviour out of 10", "Unpaid actor, best performance"]
        ),
        "fitness": Copy(
            titles: ["Workout montage, {month}", "Training diary: {month} {year}", "Showing up", "Gym recap"],
            hooks: ["Consistency looks like this", "{count} sessions in 30 seconds", "Small wins add up", "No days off (almost)"]
        ),
        "nature": Copy(
            titles: ["Into the wild: {place}", "Outside in {month}", "Nature reset", "Trails of {place}"],
            hooks: ["Your nature reset for today", "Go outside, it's worth it", "{place} doesn't look real", "Breathe in"]
        ),
        "party": Copy(
            titles: ["The night in {place}", "{month} highlights", "Best night of {year}", "Event recap"],
            hooks: ["Best night of the year, no contest", "You had to be there", "Wait for the last clip", "Recap for the group chat"]
        ),
        "goldenhour": Copy(
            titles: ["Golden hour in {place}", "{month} sunsets", "Chasing sunsets", "Golden hour diaries"],
            hooks: ["Chasing sunsets in {place}", "Sound on, slow down", "No filter needed", "Every sunset from {month}"]
        ),
        "city": Copy(
            titles: ["A day in {place}", "{place} city walk", "City diaries, {month}", "Walking the city"],
            hooks: ["Come walk {place} with me", "A day in the city, in 30 seconds", "Save this for your {place} list", "City energy"]
        ),
        "people": Copy(
            titles: ["My people, {month} {year}", "Moments with my people", "Us in {place}", "Core memories"],
            hooks: ["My favourite people in one video", "Core memories unlocked", "Send this to the group chat", "The people who make it fun"]
        ),
        "winter": Copy(
            titles: ["Snow days in {place}", "Winter {year}", "Winter wonderland", "Snow diaries"],
            hooks: ["Snow days in {place}", "Winter, in 30 seconds", "Cold hands, full heart", "Who else misses the snow?"]
        ),
        Themes.fallback.name: Copy(
            titles: ["{month} {year} highlights", "{place} highlights", "Highlights", "Camera roll dump"],
            hooks: ["A few moments worth sharing", "Camera roll dump, {month} edition", "Little moments from {place}", "Things I didn't post"]
        ),
    ]

    static func title(_ context: Context) -> String {
        let templates = copy[context.theme.name]?.titles ?? []
        return pick(templates, context: context, offset: 0) ?? context.theme.title
    }

    static func hook(_ context: Context) -> String {
        var templates = copy[context.theme.name]?.hooks ?? []
        if context.hasPeople, context.theme.name != "people" {
            templates.append("Tag who was there")
        }
        return pick(templates, context: context, offset: 1) ?? context.theme.hook
    }

    /// Deterministic seed from the video ids (Swift's `hashValue` changes every launch).
    static func seed(for ids: [String]) -> Int {
        ids.joined().unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fff_ffff }
    }

    private static func pick(_ templates: [String], context: Context, offset: Int) -> String? {
        let values = placeholderValues(context)
        let usable = templates.filter { template in
            values.allSatisfy { key, value in value != nil || !template.contains(key) }
        }
        guard !usable.isEmpty else { return nil }
        var text = usable[(context.seed + offset) % usable.count]
        for (key, value) in values {
            if let value { text = text.replacingOccurrences(of: key, with: value) }
        }
        return text
    }

    private static func placeholderValues(_ context: Context) -> [String: String?] {
        [
            "{place}": context.place,
            "{month}": context.startDate?.formatted(.dateTime.month(.wide)),
            "{year}": context.startDate?.formatted(.dateTime.year()),
            "{count}": context.clipCount > 1 ? String(context.clipCount) : nil,
        ]
    }
}
