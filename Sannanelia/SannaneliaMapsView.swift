//
//  SannaneliaMapsView.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 08.11.26.
//

import CoreLocation
import MapKit
import Observation
import SwiftUI

// MARK: - Search Service

@MainActor
@Observable
final class MapsSearchService: NSObject, MKLocalSearchCompleterDelegate {

    private let completer = MKLocalSearchCompleter()

    private(set) var suggestions: [MKLocalSearchCompletion] = []
    private(set) var isCompleting = false

    override init() {
        super.init()

        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(_ text: String, region: MKCoordinateRegion?) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            clear()
            return
        }

        if let region {
            completer.region = region
        }

        suggestions = []
        isCompleting = true
        completer.queryFragment = query
    }

    func clear() {
        completer.cancel()
        completer.queryFragment = ""
        suggestions = []
        isCompleting = false
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
        isCompleting = false
    }

    func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: Error
    ) {
        suggestions = []
        isCompleting = false
    }
}

// MARK: - Map Style

private enum SannaneliaMapStyle: String, CaseIterable, Identifiable {
    case standard
    case satellite
    case hybrid

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .standard: "Standard"
        case .satellite: "Satellite"
        case .hybrid: "Hybrid"
        }
    }

    var symbol: String {
        switch self {
        case .standard: "map"
        case .satellite: "globe.europe.africa"
        case .hybrid: "square.3.layers.3d"
        }
    }

    var style: MapStyle {
        switch self {
        case .standard:
            .standard(elevation: .realistic)
        case .satellite:
            .imagery(elevation: .realistic)
        case .hybrid:
            .hybrid(elevation: .realistic)
        }
    }
}

// MARK: - Map Result

private struct SannaneliaMapResult: Identifiable {
    let id = UUID()
    let item: MKMapItem

    var name: String {
        item.name ?? String(localized: "Place")
    }

    var address: String {
        item.placemark.title ?? ""
    }

    var coordinate: CLLocationCoordinate2D {
        item.placemark.coordinate
    }
}

// MARK: - Main View

struct SannaneliaMapsView: View {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @State private var camera: MapCameraPosition = .automatic
    @State private var searchService = MapsSearchService()

    @State private var searchText = ""
    @State private var results: [SannaneliaMapResult] = []
    @State private var selectedPlace: SannaneliaMapResult?

    @State private var selectedStyle: SannaneliaMapStyle = .standard

    @State private var isSearching = false
    @State private var searchError = false
    @State private var showingSuggestions = false

    @State private var searchTask: Task<Void, Never>?
    @State private var searchGeneration = 0

    @FocusState private var searchFocused: Bool

    var body: some View {
        mapView
            .safeAreaInset(edge: .top, spacing: 0) {
                searchHeader
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomPanel
            }
            .sheet(item: $selectedPlace) { result in
                SannaneliaPlaceDetailsView(place: result.item)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .alert(
                "Search unavailable",
                isPresented: $searchError
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please try another search.")
            }
            .onChange(of: searchText) { _, value in
                handleTextChange(value)
            }
            .onChange(of: searchFocused) { _, focused in
                if focused && !searchText.isEmpty {
                    showingSuggestions = true
                    searchService.update(
                        searchText,
                        region: camera.region
                    )
                } else if !focused {
                    showingSuggestions = false
                    searchService.clear()
                }
            }
            .onDisappear {
                cancelSearch()
                searchService.clear()
            }
    }

    // MARK: - Map

    private var mapView: some View {
        Map(position: $camera) {
            ForEach(results) { result in
                Annotation(
                    result.name,
                    coordinate: result.coordinate
                ) {
                    MapMarkerButton(result: result) {
                        select(result)
                    }
                }
            }

            UserAnnotation()
        }
        .mapStyle(selectedStyle.style)
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
        }
    }

    // MARK: - Search Header

    private var searchHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                searchField

                mapStyleMenu
            }

            if showingSuggestions && !searchText.isEmpty {
                suggestionsPanel
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(
                "Search places or addresses",
                text: $searchText
            )
            .focused($searchFocused)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .onSubmit {
                performSearch(searchText)
            }

            if isSearching {
                ProgressView()
            } else if !searchText.isEmpty {
                Button {
                    clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 16)
        )
    }

    // MARK: - Map Style Menu

    private var mapStyleMenu: some View {
        Menu {
            Picker("Map style", selection: $selectedStyle) {
                ForEach(SannaneliaMapStyle.allCases) { style in
                    Label {
                        Text(style.title)
                    } icon: {
                        Image(systemName: style.symbol)
                    }
                    .tag(style)
                }
            }
        } label: {
            Image(systemName: selectedStyle.symbol)
                .font(.title3)
                .frame(width: 50, height: 50)
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: 16)
                )
        }
        .accessibilityLabel("Map style")
    }

    // MARK: - Suggestions

    private var suggestionsPanel: some View {
        VStack(spacing: 0) {
            if searchService.suggestions.isEmpty {
                Button {
                    performSearch(searchText)
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(
                    Array(searchService.suggestions.prefix(6).indices),
                    id: \.self
                ) { index in
                    let suggestion = searchService.suggestions[index]

                    SuggestionRow(
                        title: suggestion.title,
                        subtitle: suggestion.subtitle
                    ) {
                        performSearch(suggestion)
                    }

                    if index < min(searchService.suggestions.count, 6) - 1 {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
        }
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 16)
        )
    }

    // MARK: - Bottom Panel

    @ViewBuilder
    private var bottomPanel: some View {
        if !results.isEmpty && !showingSuggestions && selectedPlace == nil {
            resultsPanel
        }
    }

    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Places")
                    .font(.headline)

                Spacer()

                Text(results.count, format: .number)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(results) { result in
                        MapResultCard(result: result) {
                            select(result)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Search Actions

    private func handleTextChange(_ text: String) {
        cancelSearch()

        let query = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !query.isEmpty else {
            showingSuggestions = false
            searchService.clear()
            return
        }

        if searchFocused {
            showingSuggestions = true
            searchService.update(
                query,
                region: camera.region
            )
        }
    }

    private func performSearch(_ input: String) {
        let query = input.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !query.isEmpty else { return }

        cancelSearch()

        let generation = searchGeneration

        searchFocused = false
        showingSuggestions = false
        searchService.clear()
        isSearching = true

        searchTask = Task { @MainActor in
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.resultTypes = [.address, .pointOfInterest]

            if let region = camera.region {
                request.region = region
            }

            await executeSearch(
                request: request,
                generation: generation
            )
        }
    }

    private func performSearch(_ completion: MKLocalSearchCompletion) {
        let title = completion.title
        let subtitle = completion.subtitle

        searchText = title

        cancelSearch()

        let generation = searchGeneration

        searchFocused = false
        showingSuggestions = false
        searchService.clear()
        isSearching = true

        searchTask = Task { @MainActor in
            let request = MKLocalSearch.Request(completion: completion)

            await executeSearch(
                request: request,
                generation: generation
            )
        }

        _ = subtitle
    }

    @MainActor
    private func executeSearch(
        request: MKLocalSearch.Request,
        generation: Int
    ) async {
        do {
            let response = try await MKLocalSearch(
                request: request
            ).start()

            guard !Task.isCancelled,
                generation == searchGeneration
            else {
                return
            }

            results = response.mapItems.map {
                SannaneliaMapResult(item: $0)
            }

            selectedPlace = nil

            if let first = results.first {
                focus(on: first)
            }
        } catch {
            guard !Task.isCancelled,
                generation == searchGeneration
            else {
                return
            }

            searchError = true
        }

        if generation == searchGeneration {
            isSearching = false
            searchTask = nil
        }
    }

    // MARK: - Camera

    private func focus(on result: SannaneliaMapResult) {
        let region = MKCoordinateRegion(
            center: result.coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: 0.035,
                longitudeDelta: 0.035
            )
        )

        if reduceMotion {
            camera = .region(region)
        } else {
            withAnimation(.easeInOut(duration: 0.35)) {
                camera = .region(region)
            }
        }
    }

    private func select(_ result: SannaneliaMapResult) {
        searchFocused = false
        showingSuggestions = false
        focus(on: result)
        selectedPlace = result
    }

    // MARK: - Cleanup

    private func cancelSearch() {
        searchGeneration += 1
        searchTask?.cancel()
        searchTask = nil
        isSearching = false
    }

    private func clearSearch() {
        cancelSearch()

        searchText = ""
        results = []
        selectedPlace = nil
        showingSuggestions = false

        searchService.clear()
    }
}

// MARK: - Marker Button

private struct MapMarkerButton: View {
    let result: SannaneliaMapResult
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.red)
                .background(.white, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(result.name)
    }
}

// MARK: - Suggestion Row

private struct SuggestionRow: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "mappin")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.medium))

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.left")
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Result Card

private struct MapResultCard: View {
    let result: SannaneliaMapResult
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(result.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(result.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(
                width: 190,
                height: 62,
                alignment: .leading
            )
            .padding(12)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Place Details

private struct SannaneliaPlaceDetailsView: View {
    let place: MKMapItem

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                placeInformation
                placeActions
            }
            .navigationTitle("Place details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var placeInformation: some View {
        Section {
            LabeledContent("Name") {
                Text(place.name ?? "Place")
            }

            if let address = place.placemark.title {
                LabeledContent("Address") {
                    Text(address)
                        .multilineTextAlignment(.trailing)
                }
            }

            if let phone = place.phoneNumber {
                LabeledContent("Phone") {
                    Text(phone)
                }
            }

            if let url = place.url {
                Link(destination: url) {
                    Label("Website", systemImage: "globe")
                }
            }
        }
    }

    private var placeActions: some View {
        Section {
            Button {
                openDirections()
            } label: {
                Label(
                    "Directions",
                    systemImage: "arrow.triangle.turn.up.right.diamond"
                )
            }

            Button {
                place.openInMaps()
            } label: {
                Label("Open in Apple Maps", systemImage: "map")
            }
        }
    }

    private func openDirections() {
        place.openInMaps(
            launchOptions: [
                MKLaunchOptionsDirectionsModeKey:
                    MKLaunchOptionsDirectionsModeDriving
            ]
        )
    }
}

#Preview {
    SannaneliaMapsView()
}
