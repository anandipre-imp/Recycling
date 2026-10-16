import Foundation

/// A kind of content people make, e.g. "travel recap" or "pet compilation".
///
/// `triggers` are words a user might type; `labels` are words that show up in the
/// Vision labels of matching videos. This table is what lets "trip" find beach and
/// airport videos even though no video is literally labelled "trip".
struct Theme: Hashable {
    let name: String
    let title: String
    let hook: String
    let triggers: Set<String>
    let labels: Set<String>

    /// True if a (normalized) Vision label belongs to this theme — either the whole
    /// label ("palm tree") or any word of it ("sunset sunrise" -> "sunset").
    func matches(label: String) -> Bool {
        if labels.contains(label) { return true }
        return label.split(separator: " ").contains { labels.contains(String($0)) }
    }
}

enum Themes {
    static let fallback = Theme(
        name: "highlights", title: "Highlights", hook: "A few moments worth sharing",
        triggers: [], labels: []
    )

    static let all: [Theme] = [
        Theme(
            name: "travel", title: "Travel recap", hook: "The whole trip in 30 seconds",
            triggers: ["travel", "trip", "vacation", "holiday", "getaway", "adventure", "explore", "roadtrip", "abroad", "tourist"],
            labels: ["beach", "ocean", "sea", "mountain", "airplane", "aircraft", "airport", "landmark", "monument", "cityscape",
                     "boat", "hotel", "lake", "island", "road", "tourism", "architecture", "shore", "harbour", "suitcase"]
        ),
        Theme(
            name: "beach", title: "Beach days", hook: "Take me back here",
            triggers: ["beach", "ocean", "sea", "summer", "surf", "surfing", "swim", "swimming", "island", "coast", "tropical"],
            labels: ["beach", "sand", "ocean", "sea", "shore", "water", "swimming", "surfboard", "wave", "palm", "coast", "pool"]
        ),
        Theme(
            name: "food", title: "What I ate", hook: "Everything I ate, ranked",
            triggers: ["food", "foodie", "eat", "eating", "meal", "dinner", "lunch", "breakfast", "brunch", "restaurant",
                       "cooking", "recipe", "cafe", "coffee", "dessert", "drinks"],
            labels: ["food", "meal", "dessert", "drink", "beverage", "fruit", "vegetable", "coffee", "pizza", "cake", "bread",
                     "baked", "sushi", "burger", "salad", "restaurant", "kitchen", "cooking", "plate", "wine", "cocktail", "pasta"]
        ),
        Theme(
            name: "pets", title: "Pet moments", hook: "Proof my pet is the main character",
            triggers: ["pet", "pets", "dog", "dogs", "cat", "cats", "puppy", "kitten", "animal", "animals"],
            labels: ["dog", "cat", "puppy", "kitten", "animal", "pet", "mammal", "canine", "feline", "bird", "horse"]
        ),
        Theme(
            name: "fitness", title: "Workout montage", hook: "Showing up, every day",
            triggers: ["fitness", "gym", "workout", "exercise", "training", "run", "running", "yoga", "sport", "sports", "lifting"],
            labels: ["gym", "exercise", "sport", "sports", "running", "yoga", "weightlifting", "bicycle", "cycling", "ball",
                     "soccer", "basketball", "tennis", "stadium", "dumbbell"]
        ),
        Theme(
            name: "nature", title: "Into the wild", hook: "Nature reset",
            triggers: ["nature", "outdoors", "outdoor", "hike", "hiking", "camping", "forest", "mountains", "scenery", "landscape", "trail"],
            labels: ["tree", "forest", "mountain", "plant", "flower", "grass", "sky", "cloud", "lake", "river", "waterfall",
                     "hill", "field", "landscape", "trail", "foliage", "canyon"]
        ),
        Theme(
            name: "party", title: "Event highlights", hook: "Best night of the year",
            triggers: ["party", "celebration", "birthday", "concert", "festival", "event", "wedding", "nightout", "dance", "dancing"],
            labels: ["party", "celebration", "crowd", "concert", "balloon", "cake", "candle", "dancing", "stage", "fireworks",
                     "wedding", "bride", "gift", "nightclub", "performance"]
        ),
        Theme(
            name: "goldenhour", title: "Golden hour", hook: "Chasing sunsets",
            triggers: ["sunset", "sunsets", "sunrise", "golden", "aesthetic", "sky", "dusk"],
            labels: ["sunset", "sunrise", "sky", "sun", "dusk", "horizon", "cloud"]
        ),
        Theme(
            name: "city", title: "City walk", hook: "A day in the city",
            triggers: ["city", "urban", "street", "downtown", "nightlife"],
            labels: ["cityscape", "street", "building", "skyscraper", "traffic", "bridge", "city", "downtown", "storefront"]
        ),
        Theme(
            name: "people", title: "Moments with my people", hook: "My favourite people, one video",
            triggers: ["family", "kids", "kid", "baby", "children", "friends", "people", "together", "selfie"],
            labels: ["people", "child", "baby", "adult", "group", "family", "portrait", "selfie", "smile", "toddler"]
        ),
        Theme(
            name: "winter", title: "Winter wonderland", hook: "Snow days",
            triggers: ["winter", "snow", "ski", "skiing", "snowboard", "snowboarding", "christmas", "holidays"],
            labels: ["snow", "ski", "skiing", "snowboard", "ice", "winter", "christmas", "mountain"]
        ),
    ]

    static func triggered(by term: String) -> [Theme] {
        all.filter { $0.triggers.contains(term) }
    }
}
