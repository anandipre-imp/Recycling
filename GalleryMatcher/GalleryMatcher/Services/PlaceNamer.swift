import CoreLocation

/// Turns a group's GPS position into a town/city name for titles ("Beach days in Tulum").
/// Works on every iPhone. Only the coordinate is sent to Apple's geocoder — never a video —
/// and the user can switch this off in the Library tab.
actor PlaceNamer: PlaceNaming {
    private var cache: [String: String?] = [:]

    func placeName(latitude: Double, longitude: Double) async -> String? {
        // ~1 km buckets, so a whole trip's clips share one lookup.
        let key = String(format: "%.2f,%.2f", latitude, longitude)
        if let cached = cache[key] { return cached }

        guard let placemarks = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude))
        else { return nil } // Offline or rate-limited: don't cache, try again next search.

        let placemark = placemarks.first
        let name = placemark?.locality ?? placemark?.administrativeArea ?? placemark?.country
        cache[key] = .some(name)
        return name
    }
}
