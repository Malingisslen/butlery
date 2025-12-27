# Screenshot Guidelines

## Required Sizes

### iOS App Store

| Device | Resolution | Aspect Ratio |
|--------|------------|--------------|
| iPhone 6.7" (14 Pro Max, 15 Pro Max) | 1290 x 2796 | 9:19.5 |
| iPhone 6.5" (11 Pro Max, XS Max) | 1242 x 2688 | 9:19.5 |
| iPhone 5.5" (8 Plus, 7 Plus) | 1242 x 2208 | 9:16 |
| iPad Pro 12.9" (3rd gen+) | 2048 x 2732 | 3:4 |

### Google Play Store

| Device | Resolution | Aspect Ratio |
|--------|------------|--------------|
| Phone | 1080 x 1920 (min) | 9:16 |
| 7" Tablet | 1200 x 1920 (min) | 10:16 |
| 10" Tablet | 1600 x 2560 (min) | 10:16 |

## Recommended Screens (Priority Order)

### 1. Recipe List (Main Value)
- Show 3-4 beautiful recipe cards
- Include varied food photos
- Demonstrate organization/categories

### 2. Recipe Detail
- Full recipe with appetizing photo
- Visible ingredients and instructions
- Show rating/social features

### 3. Weekly Menu
- Display a complete week view
- Show drag-and-drop capability
- Include meal variety

### 4. Shopping List
- Show categorized items
- Demonstrate check-off feature
- Include sharing indicators

### 5. Social Sharing
- Friends/groups list
- Sharing dialog
- Collaborative features

## Screenshot Best Practices

### Content
- Use realistic, high-quality food photos
- Show app with actual data (not empty states)
- Highlight key features in each screen
- Use Swedish content for sv-SE, English for en-US

### Technical
- Capture in both light and dark mode
- Ensure status bar shows full signal/battery
- Hide sensitive user data
- Use clean, professional device frames

### Device Frames
- Use official Apple/Google device frames
- Consistent frame style across all screenshots
- Consider frameless for modern look

## Screenshot Automation

Consider using:
- `fastlane snapshot` for iOS
- `fastlane screengrab` for Android
- `flutter_driver` for automated capture

## File Organization

```
screenshots/
├── sv-SE/
│   ├── iphone_6.7/
│   │   ├── 01_recipes.png
│   │   ├── 02_recipe_detail.png
│   │   ├── 03_weekly_menu.png
│   │   ├── 04_shopping_list.png
│   │   └── 05_sharing.png
│   ├── ipad_12.9/
│   └── phone/
└── en-US/
    └── ...
```
