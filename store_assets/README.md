# Store Assets

App Store and Play Store metadata and assets for Butlery.

## Directory Structure

```
store_assets/
├── metadata/
│   ├── sv-SE/          # Swedish (primary market)
│   │   ├── title.txt
│   │   ├── subtitle.txt
│   │   ├── description.txt
│   │   ├── keywords.txt
│   │   ├── release_notes.txt
│   │   └── promotional_text.txt
│   └── en-US/          # English (secondary market)
│       └── ...
└── screenshots/
    ├── README.md       # Screenshot guidelines
    └── templates/      # Device frame templates
```

## Metadata Files

| File | iOS Limit | Android Limit | Purpose |
|------|-----------|---------------|---------|
| title.txt | 30 chars | 50 chars | App name |
| subtitle.txt | 30 chars | N/A | iOS subtitle |
| description.txt | 4000 chars | 4000 chars | Full description |
| keywords.txt | 100 chars | N/A | iOS search keywords |
| release_notes.txt | 4000 chars | 500 chars | What's new |
| promotional_text.txt | 170 chars | 80 chars | Promo text |

## Usage with Fastlane

These files are structured for use with Fastlane's `deliver` and `supply` tools:

```bash
# iOS
fastlane deliver --metadata_path ./store_assets/metadata

# Android
fastlane supply --metadata_path ./store_assets/metadata
```
