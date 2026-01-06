# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a single-page web application for GPS track management and editing. The entire application is contained in a single [index.html](index.html) file (~5,500 lines) with no build system, no npm dependencies, and no backend server. It's a pure client-side application that runs directly in the browser.

**Technology Stack:**
- Vanilla JavaScript (no framework)
- Leaflet.js 1.9.4 for mapping
- toGeoJSON library for GPX parsing
- HTML5 + CSS3 with responsive design

**Deployment:**
- Automatically deploys to GitHub Pages on push to `main` or `master` via [.github/workflows/deploy.yml](.github/workflows/deploy.yml)
- No build step required

## Development Workflow

**Local Development:**
```bash
# Simply open the file in a browser
open index.html
# or use a simple HTTP server
python3 -m http.server 8000
```

**Testing Changes:**
- Open [index.html](index.html) in browser
- Use browser DevTools console for debugging
- Test on mobile viewport (responsive design breakpoint at 768px)

**Deployment:**
- Push to `main` or `master` branch
- GitHub Actions automatically deploys to GitHub Pages
- No manual deployment steps needed

## Architecture

### Monolithic Structure
The entire application is in [index.html](index.html) organized as:
1. **CSS (lines 14-692)**: All styles including responsive breakpoints
2. **HTML (lines 695-754)**: Minimal markup (map container, UI elements)
3. **JavaScript (lines 790-5579)**: All application logic

### Core Data Model

**Track Object Structure:**
```javascript
{
  name: string,              // Track name
  color: string,             // Hex color (#FF0000, etc.)
  geoJson: {                 // GeoJSON FeatureCollection
    type: "FeatureCollection",
    features: [              // Array of LineString features
      {
        type: "Feature",
        geometry: {
          type: "LineString",
          coordinates: [[lon, lat, elevation], ...]
        },
        properties: {
          coordTimes: [timestamp, ...],      // ISO 8601 strings
          elevations: [meters, ...],         // Elevation in meters
          segmentTypes: ['walk'|'ski'|'snowmobile', ...]
        }
      }
    ]
  }
}
```

**Global State Variables:**
- `tracks[]` - Array of track objects (source of truth)
- `trackLayers[]` - Array of Leaflet polyline arrays (visualization)
- `trackStartMarkers[]` / `trackEndMarkers[]` - Green/red markers
- `trackVisibility[]` - Boolean array for track visibility
- `selectedTrackIndex` - Currently selected track (Number or null)
- `editingTrackIndex` - Track being edited (Number or null)
- `editMarkers[]` - Draggable markers during edit mode
- `editMarkerData[]` - Metadata for edit markers
- `elevationCache` - Map for caching elevation API responses

### Key Architectural Patterns

**1. Array Index Synchronization**
All track-related arrays use the same index for the same track:
```javascript
tracks[i]              // Track data
trackLayers[i]         // Visual layers
trackStartMarkers[i]   // Start marker
trackEndMarkers[i]     // End marker
trackVisibility[i]     // Visibility state
```

**2. Edit Mode System**
- `enableTrackEditing(trackIndex)` creates draggable markers
- `editMarkers[]` stores draggable L.Marker instances
- `editMarkerData[]` stores metadata: `{trackIndex, featureIndex, coordIndex, segmentType}`
- `updateTrackGeoJSON(trackIndex)` syncs marker positions back to track data
- `disableTrackEditing(trackIndex)` removes markers and restores polylines

**3. Multi-Segment Visualization**
Tracks can have different segment types (walk/ski/snowmobile):
- Different dash patterns: walk=[3,3], ski=[8,4], snowmobile=[12,4]
- Each segment type gets its own polyline layer
- `trackLayers[i]` is an array of polylines for track `i`

**4. Data Persistence**
- `saveToSessionStorage()` - Saves entire tracks array
- `restoreFromSessionStorage()` - Loads on page load (line ~5550)
- Uses `sessionStorage` (cleared on browser close)

## Critical Functions Reference

**Track Management:**
- `loadGPX(file)` - Parse GPX file, convert to GeoJSON, add to tracks array
- `addTrack(geoJson, name, color)` - Add new track to all synchronized arrays
- `deleteTrack(trackIndex)` - Remove from all arrays, update UI
- `selectTrack(trackIndex)` - Set selected track, show details panel
- `updateMap()` - Re-render all tracks on map from tracks array
- `renderTrack(trackIndex)` - Render single track with proper segment visualization

**Editing:**
- `enableTrackEditing(trackIndex)` - Create draggable markers (line ~1300)
- `disableTrackEditing(trackIndex)` - Remove markers, restore polylines
- `updateTrackGeoJSON(trackIndex)` - Sync marker positions to track data
- `deleteMarker(markerIndex)` - Delete specific point
- `deleteMarkersBeforeIndex(markerIndex)` - Delete all points before
- `deleteMarkersAfterIndex(markerIndex)` - Delete all points after
- `mergeSegments(trackIndex)` - Merge consecutive segments of same type

**Elevation & Time:**
- `setTrackElevations(trackIndex)` - Batch fetch elevations from Open-Elevation API
- `setTrackStartTime(trackIndex)` - Set start time, calculate times for all points
- `calculateAverageSpeed(track)` - Calculate speed based on distance and time
- Elevation caching: `getElevationCacheKey(coord)` uses 5 decimal precision

**Export:**
- `exportGPX(trackIndex)` - Standard GPX export
- `exportGarminGPX(trackIndex)` - Garmin-specific format with color tags

**UI State:**
- `showEditingBanner()` / `hideEditingBanner()` - Toggle edit mode banner
- `updateTrackList()` - Re-render sidebar track list
- `updateTrackMarkers(trackIndex)` - Update start/end markers

## Important Implementation Details

### Segment Types
Segments are stored in `feature.properties.segmentTypes[]` array:
- Values: `'walk'`, `'ski'`, `'snowmobile'`
- Each segment can have different speed: walk=5km/h, ski=8km/h, snowmobile=20km/h
- Visual dash patterns differ per type

### Elevation API Integration
- Uses Open-Elevation API: `https://api.open-elevation.com/api/v1/lookup`
- Batch processing: sends up to 100+ coordinates per request
- Caching with 5 decimal precision to reduce API calls
- Modal shows progress during batch elevation fetching

### Context Menus
Two types of context menus:
1. **Track Context Menu** - Right-click on track polyline
2. **Marker Context Menu** - Right-click on edit marker

Context menus are positioned absolutely and shown/hidden via JavaScript.

### Coordinate Precision
- Display: 5 decimal places (~1.1m precision)
- Elevation cache key: 5 decimal places
- Internal storage: Full precision from GPX

### Color System
10 predefined colors cycle through tracks:
```javascript
['#FF0000', '#00FF00', '#0000FF', '#FFFF00', '#FF00FF',
 '#00FFFF', '#FFA500', '#800080', '#FFC0CB', '#A52A2A']
```

## Common Patterns When Making Changes

### Adding a New Track Property
1. Add to track object creation in `loadGPX()` or `createNewTrack()`
2. Update `exportGPX()` to include in GPX output
3. Update `renderTrack()` if it affects visualization
4. Update `saveToSessionStorage()` if needed (usually automatic)

### Adding UI for New Feature
1. Add HTML elements in markup section (lines 695-754)
2. Add CSS styles (lines 14-692)
3. Add event listeners in initialization section (~line 860+)
4. Add handler function
5. Update `updateTrackList()` or `selectTrack()` if UI shows in sidebar

### Modifying Edit Mode Behavior
1. Changes usually go in `enableTrackEditing()` or marker event handlers
2. Update `updateTrackGeoJSON()` if changing how data syncs back
3. Test with multi-segment tracks (different segment types)
4. Verify markers update correctly after operations like reverse

### Working with GeoJSON
- Coordinates are `[longitude, latitude, elevation]` (note: lon/lat order!)
- Each track can have multiple features (though typically just one LineString)
- Properties are stored per-feature, not per-track
- Always preserve all three coordinate dimensions

## Debugging Tips

**Common Issues:**
- **Markers not updating**: Call `updateTrackMarkers(trackIndex)` after track changes
- **Track not visible**: Check `trackVisibility[trackIndex]` and ensure `renderTrack()` was called
- **Edit markers in wrong position**: Ensure `updateTrackGeoJSON()` was called before `disableTrackEditing()`
- **Array index mismatch**: After delete operations, verify all synchronized arrays updated

**Console Inspection:**
```javascript
// View track data
console.log(tracks[0])

// Check visibility
console.log(trackVisibility)

// Inspect edit state
console.log({editingTrackIndex, selectedTrackIndex})

// View elevation cache
console.log(elevationCache)
```

## Language & Localization

The UI is in Russian (`lang="ru"`). All UI text, button labels, and messages are in Russian. Keep this consistent when adding new UI elements.

## File Organization Rules

- **DO NOT** split [index.html](index.html) into separate files - the monolithic structure is intentional
- **DO NOT** add build tools, package.json, or bundlers
- **DO NOT** add external dependencies beyond the two CDN libraries (Leaflet, toGeoJSON)
- All changes must be made directly in [index.html](index.html)
