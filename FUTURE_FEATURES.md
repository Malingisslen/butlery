# BUTLERY - FUTURE FEATURES

**Last Updated:** 2025-12-26
**Status:** Planned / Not Implemented
**Source:** creative_ideas.md + comprehensive analysis gaps + platform analysis
**Total Features:** 45
**Total Estimated Effort:** ~2,053 hours (~51 weeks)

---

## Priority Overview

### First Fixes - Social Platform Polish (~317 hours)
Quick wins to polish the social platform experience.

| # | Feature | Effort | Description |
|---|---------|--------|-------------|
| 1 | Missing Delete UI | ~16 hrs | Add delete buttons for comments, notifications, ratings, templates |
| 2 | Standard Platform Features | ~84 hrs | Account settings, help, undo, onboarding, search history |
| 3 | Basic UX Controls | ~26 hrs | Bulk operations, view modes, image crop/rotate |
| 4 | Comment Reactions | ~19 hrs | Emoji reactions beyond likes on recipe comments |
| 5 | Message Reactions | ~21 hrs | Quick emoji responses in chat messages |
| 6 | Chat Polls | ~29 hrs | Create polls for group decisions in conversations |
| 7 | Enhanced Group Chats | ~46 hrs | Rich group messaging with roles, pins, mentions |
| 33 | Favorites/Bookmarks System | ~18 hrs | Quick-access bookmarking for frequently used recipes |
| 37 | Shopping List Category Grouping | ~34 hrs | Collapsible category sections (HIGH PRIORITY) |
| 41 | Social Login | ~24 hrs | Google/Apple Sign-in (HIGH PRIORITY for conversion) |

### Platform & Retention Features (~136 hours)
App experience improvements for activation and retention.

| # | Feature | Effort | Description |
|---|---------|--------|-------------|
| 26 | Empty State Helpers | ~29 hrs | Actionable prompts on all empty screens |
| 27 | Notification Preferences | ~33 hrs | Granular per-type notification controls |
| 28 | Re-engagement Onboarding | ~36 hrs | Welcome back flow for returning users |
| 29 | Personalized Push Timing | ~38 hrs | ML-based optimal notification delivery |

### Recipe Enhancement Features (~788 hours)
Features that enhance the core recipe experience.

| # | Feature | Effort | Description |
|---|---------|--------|-------------|
| 1 | Flavor Fingerprint | ~98 hrs | AI learns your taste preferences over time |
| 5 | Educational Mode | ~68 hrs | Learn why each cooking step matters |
| 7 | Auto-Scale Intelligence | ~52 hrs | Smart non-linear recipe scaling |
| 8 | Recipe Debugger | ~60 hrs | Diagnose and fix cooking failures |
| 10 | Culinary Skills Academy | ~92 hrs | Comprehensive technique training |
| 11 | Recipe Narration Mode | ~60 hrs | Audio storytelling for recipes |
| 19 | Flavor Experiment Lab | ~52 hrs | Guided taste discovery experiments |
| 34 | Cooking Mode | ~52 hrs | Step-by-step hands-free cooking (HIGH VALUE) |
| 39 | Recipe Reviews | ~46 hrs | Detailed reviews with text, photos, verified badges |
| 40 | Follow System | ~58 hrs | Asymmetric follow model for creator profiles |
| 42 | Recipe Collections | ~26 hrs | Themed recipe curation with social sharing |
| 43 | Recipe Attribution & Remixing | ~24 hrs | Track original recipe and remix chain |

### Meal Planning & Efficiency Features (~314 hours)
Features to optimize meal planning and preparation.

| # | Feature | Effort | Description |
|---|---------|--------|-------------|
| 3 | Seasonal Ingredient Alerts | ~50 hrs | What's in season in your region |
| 6 | Batch Prep Optimizer | ~52 hrs | Smart prep consolidation for weekly menu |
| 9 | Cost-Per-Serving Calculator | ~56 hrs | Budget tracking for every recipe |
| 20 | Smart Portion Advisor | ~48 hrs | Learn actual consumption patterns |
| 35 | Dietary Restrictions Profile | ~42 hrs | Filter menu generation by dietary preferences |
| 36 | Menu Templates | ~38 hrs | Pre-built menu templates and community library |
| 38 | Smart Shopping Suggestions | ~28 hrs | Autocomplete and one-tap add from history |

### Social & Family Features (~234 hours)
Features for social engagement and family cooking.

| # | Feature | Effort | Description |
|---|---------|--------|-------------|
| 2 | Family Recipe Vault | ~64 hrs | Preserve recipes with voice memoirs |
| 16 | Family Meal Converter | ~54 hrs | Convert adult recipes for babies/toddlers |
| 17 | Chef AMAs | ~66 hrs | Live Q&A with professional chefs |
| 18 | Recipe Duet Mode | ~58 hrs | Synchronized couple cooking |
| 21 | Family Meal Voting | ~56 hrs | Democratic dinner decisions |

### Utility Features (~232 hours)
Quick wins and utility enhancements.

| # | Feature | Effort | Description |
|---|---------|--------|-------------|
| 4 | Zero-Click Recipe Start | ~58 hrs | Voice-first hands-free cooking |
| 12 | Wine & Beverage Pairing | ~50 hrs | Smart drink matching for meals |
| 13 | Smart Substitution Engine | ~44 hrs | Intelligent ingredient swaps |
| 14 | Kitchen Equipment Profile | ~44 hrs | Filter recipes by your equipment |
| 15 | Recipe Carbon Calculator | ~50 hrs | Environmental impact tracking |
| 44 | Video Audio Transcription | ~30 hrs | Import recipes from videos without captions |

---

## Detailed Feature List

### 1. FLAVOR FINGERPRINT - Personal Taste AI
**Effort:** ~98 hours (2.5 week sprint)

AI learns what you actually like by tracking cooking behavior and automatically adjusts recipes to match your personal taste profile.

**Key Capabilities:**
- Behavioral tracking (completion rate, remakes, shares, abandonments)
- Taste profile (salt, spice, sweetness, fat preferences)
- Smart recipe adjustments before cooking
- "You'll love this" predictive scores
- Privacy-first on-device ML

---

### 2. FAMILY RECIPE VAULT WITH VOICE MEMOIRS
**Effort:** ~64 hours (1.5-2 week sprint)

Preserve family culinary heritage by recording loved ones telling you how to make their dishes.

**Key Capabilities:**
- Voice recording with step sync
- Handwritten recipe scanning (OCR)
- Family tree integration
- Memorial mode
- Video integration

---

### 3. SEASONAL INGREDIENT ALERTS
**Effort:** ~50 hours (1-1.5 week sprint)

Track what's in season in the user's region and suggest recipes using peak-season produce.

**Key Capabilities:**
- Location-based seasonality (Sweden-focused)
- Proactive notifications
- Gamification (streaks, badges)
- Farmers market integration
- Carbon footprint tracking

---

### 4. ZERO-CLICK RECIPE START
**Effort:** ~58 hours (1.5 week sprint)

Voice-first, hands-free recipe activation via Siri/Google Assistant.

**Key Capabilities:**
- "Hey Siri, start cooking [recipe]"
- Auto-launch cooking mode
- End-to-end voice control
- Screen wake lock
- Smart context (time of day, last recipe)

---

### 5. EDUCATIONAL MODE - Learn While You Cook
**Effort:** ~68 hours (1.5-2 week sprint)

Toggle that adds AI-generated explanations for why each step matters.

**Key Capabilities:**
- Step-level "Why?" explanations
- Technique tutorials
- Ingredient education
- Common mistake prevention
- Skill progression tracking

---

### 6. BATCH PREP OPTIMIZER
**Effort:** ~52 hours (1.5 week sprint)

AI analyzes weekly menu and groups all prep work together.

**Key Capabilities:**
- Overlapping ingredient detection
- Smart prep schedule generation
- Time savings calculation
- Storage guidance
- Re-optimization when menu changes

---

### 7. AUTO-SCALE INTELLIGENCE
**Effort:** ~52 hours (1.5 week sprint)

Smart recipe scaling with non-linear adjustments for leavening, seasoning, and timing.

**Key Capabilities:**
- Non-linear scaling rules
- Smart warnings
- Technique adjustments
- Equipment constraints
- Category-specific intelligence

---

### 8. RECIPE DEBUGGER
**Effort:** ~60 hours (1.5 week sprint)

When a recipe fails, AI diagnoses the likely cause with specific fixes.

**Key Capabilities:**
- Failure description (common issues or natural language)
- AI diagnosis with probability
- Specific actionable fixes
- Recipe annotation
- Community aggregate patterns

---

### 9. COST-PER-SERVING CALCULATOR
**Effort:** ~56 hours (1.5 week sprint)

Shows exact cost breakdown for every recipe.

**Key Capabilities:**
- Ingredient cost tracking
- Per-serving breakdown
- Budget comparisons (vs restaurant/meal kit)
- Budget-aware filtering
- Shopping optimization

---

### 10. CULINARY SKILLS ACADEMY
**Effort:** ~92 hours (2.5 week sprint)

Comprehensive technique training with videos, knife skills, and certifications.

**Key Capabilities:**
- Technique video library (200+)
- Knife skills trainer
- Professional technique unlocks
- Mise en place coach
- Skill progression and badges

---

### 11. RECIPE NARRATION MODE
**Effort:** ~60 hours (1.5 week sprint)

Podcast-style audio narration with stories, tips, and step-by-step guidance.

**Key Capabilities:**
- Multiple narration styles (story, chef tips, step-by-step)
- Variable playback speed
- Timer integration
- Offline downloads
- AI or professional voices

---

### 12. WINE & BEVERAGE PAIRING
**Effort:** ~50 hours (1-1.5 week sprint)

AI-powered pairing suggestions for wine, beer, cocktails, and non-alcoholic options.

**Key Capabilities:**
- Multiple options per dish
- "Why it works" explanations
- Shopping integration
- Menu-level pairing
- User preference learning

---

### 13. SMART SUBSTITUTION ENGINE
**Effort:** ~44 hours (1 week sprint)

Intelligent ingredient substitutions based on dietary needs and availability.

**Key Capabilities:**
- Context-aware suggestions
- Impact warnings
- Ratio adjustments
- Dietary restriction support
- Learning from user choices

---

### 14. KITCHEN EQUIPMENT PROFILE
**Effort:** ~44 hours (1 week sprint)

Filter recipes based on equipment you own.

**Key Capabilities:**
- Equipment inventory
- Recipe filtering
- Alternative method suggestions
- Wishlist for gifting
- Affiliate integration potential

---

### 15. RECIPE CARBON CALCULATOR
**Effort:** ~50 hours (1-1.5 week sprint)

Environmental impact tracking for ingredients and cooking methods.

**Key Capabilities:**
- Per-recipe carbon footprint
- Ingredient breakdown
- Lower-impact alternatives
- Menu-level analysis
- Gamification (badges, streaks)

---

### 16. FAMILY MEAL CONVERTER
**Effort:** ~54 hours (1.5 week sprint)

Convert adult recipes for babies, toddlers, and young children.

**Key Capabilities:**
- Age-appropriate modifications
- Safety warnings (choking, allergies)
- Nutritional adjustments
- Texture modifications
- Portion sizing for kids

---

### 17. CHEF AMAs
**Effort:** ~66 hours (1.5-2 week sprint)

Live Q&A sessions with professional chefs.

**Key Capabilities:**
- Scheduled live sessions
- Question submission
- Video/audio integration
- Archive for later viewing
- Chef profiles and specialties

---

### 18. RECIPE DUET MODE
**Effort:** ~58 hours (1.5 week sprint)

Synchronized couple/pair cooking with task division.

**Key Capabilities:**
- Automatic task splitting
- Real-time sync
- Independent progress tracking
- Coordination cues
- Combined timers

---

### 19. FLAVOR EXPERIMENT LAB
**Effort:** ~52 hours (1.5 week sprint)

Guided taste discovery experiments to build flavor intuition.

**Key Capabilities:**
- Structured experiments (salt levels, acid comparison)
- Observation logging
- Palate profile building
- Skill progression
- Application to cooking

---

### 20. SMART PORTION ADVISOR
**Effort:** ~48 hours (1 week sprint)

Learn actual consumption patterns to adjust recipe yields.

**Key Capabilities:**
- Leftover tracking
- Consumption pattern learning
- Automatic portion suggestions
- Waste reduction insights
- Shopping list adjustment

---

### 21. FAMILY MEAL VOTING
**Effort:** ~56 hours (1.5 week sprint)

Family members vote on dinner options.

**Key Capabilities:**
- Meal ballot creation
- Multiple voting modes (kids emoji, ranking)
- AI-powered suggestions
- Menu/shopping integration
- Gamification

---

### 22. ENHANCED GROUP CHATS
**Effort:** ~46 hours (1 week sprint)

Rich group messaging beyond basic chat.

**Key Capabilities:**
- Group management (roles, avatars)
- @mentions, pins, threads
- Voice messages
- Shared shopping lists
- Per-group notifications

---

### 23. CHAT POLLS
**Effort:** ~29 hours (3-4 day sprint)

Quick polls in conversations for group decisions.

**Key Capabilities:**
- Multiple poll types
- Real-time results
- Deadline support
- Menu/recipe integration
- Anonymous voting option

---

### 24. MESSAGE REACTIONS
**Effort:** ~21 hours (2-3 day sprint)

Emoji reactions on chat messages.

**Key Capabilities:**
- Quick emoji picker
- Multiple reactions per message
- Real-time sync
- Reaction notifications
- Custom quick picks

---

### 25. COMMENT REACTIONS
**Effort:** ~19 hours (2 day sprint)

Emoji reactions on recipe comments beyond likes.

**Key Capabilities:**
- Multiple emoji options
- "Helpful" marker for sorting
- "Tried this" badge
- Author reputation building
- Filter by reaction type

---

### 26. EMPTY STATE HELPERS
**Effort:** ~29 hours (3-4 day sprint)

Actionable prompts on every empty screen.

**Key Capabilities:**
- Contextual empty states
- Friendly illustrations
- Progressive disclosure
- Smart suggestions
- Success celebrations

---

### 27. RE-ENGAGEMENT ONBOARDING
**Effort:** ~36 hours (1 week sprint)

Welcome back flow for users returning after 30+ days.

**Key Capabilities:**
- Content catch-up
- What's new highlights
- Feature reminders
- Personalized re-activation
- Pick up where left off

---

### 28. PERSONALIZED PUSH TIMING
**Effort:** ~38 hours (1 week sprint)

Learn optimal notification delivery times per user.

**Key Capabilities:**
- Engagement pattern learning
- Smart scheduling
- Quiet hours
- Fallback for new users
- Continuous adaptation

---

### 29. NOTIFICATION PREFERENCES GRANULAR
**Effort:** ~33 hours (4-5 day sprint)

Fine-grained control over notification types.

**Key Capabilities:**
- Per-type toggles
- Category organization
- Channel control (push, email)
- Frequency options
- Smart presets

---

### 30. MISSING DELETE UI
**Effort:** ~16 hours (2 day sprint)

Add delete/remove UI buttons for content types that have backend delete but no user interface.

**Key Capabilities:**

**Comments (~4 hrs):**
- Delete button on own comments in recipe detail view
- Confirmation dialog with warning
- Real-time removal from comment thread
- Author-only permission (handled by existing backend)

**Notifications (~4 hrs):**
- Swipe-to-dismiss on notification items
- "Clear all" button in notifications header
- Individual delete buttons
- Bulk operations for read notifications

**Ratings (~4 hrs):**
- Remove/change rating option on recipe detail
- Confirmation before removal
- Update recipe average rating display
- History of user's ratings in profile

**Shopping Templates (~4 hrs):**
- Template management view in shopping settings
- Delete button on each template
- Rename template option
- Confirmation with template name

**Technical Notes:**
- All backend delete methods already implemented
- Only UI components needed (buttons, dialogs, handlers)
- Use existing `CommonDialogActions.showDeleteConfirmation()` pattern
- Follow existing permission validation patterns

---

### 31. STANDARD PLATFORM FEATURES
**Effort:** ~84 hours (2 week sprint)

Baseline features users assume exist in any modern app. These aren't differentiators but their absence causes frustration.

**Key Capabilities:**

**Account Settings (~10 hrs):**
- Change password while logged in (~4 hrs) - Firebase Auth method exists
- Change email address (~6 hrs) - Requires re-authentication

**Help & Support (~14 hrs):**
- Help/FAQ section (~8 hrs) - Searchable static content view
- Report bug form (~6 hrs) - Collect device info, description, screenshots

**Content UX (~30 hrs):**
- Undo delete actions (~16 hrs) - Snackbar with undo, soft delete pattern
- Recently viewed recipes (~6 hrs) - Simple history tracking (last 20)
- Duplicate import detection (~8 hrs) - Hash comparison on URL/content import

**Onboarding (~20 hrs):**
- First-time user tutorial (~16 hrs) - Welcome flow for NEW users (not re-engagement)
- Search history UI (~4 hrs) - Backend exists, need list display

**Session Management (~4 hrs):**
- Session timeout notification (~4 hrs) - User-visible warning before auto-logout

**In-app Feedback (~6 hrs):**
- Simple feedback form - Quick way to send suggestions/comments

**Technical Notes:**
- Most features are straightforward UI work
- Firebase Auth provides change password/email methods
- Follow existing dialog and form patterns
- Consider bundling related features (account settings together)

---

### 32. BASIC UX CONTROLS
**Effort:** ~26 hours (3-4 day sprint)

Essential UX controls users expect. Infrastructure exists but UI exposure missing.

**Key Capabilities:**

**Bulk Operations (~8 hrs):**
- "Select All" checkbox in lists (recipes, shopping items, messages)
- Multi-select mode with count display (e.g., "3 items selected")
- Bulk actions bar (Delete, Share, Export)
- Cancel selection mode
- Visual feedback for selected items

**View Modes (~6 hrs):**
- Grid/List toggle button in recipe lists - **responsive_grid.dart exists!**
- Compact vs Detailed view density toggle
- Persist user preference per view
- Smooth transition animation

**Image Basics (~12 hrs):**
- Crop/rotate editor before upload (~8 hrs) - Use image_cropper package
- Drag & drop image reordering (~4 hrs) - ReorderableListView integration
- Visual feedback during reorder
- Auto-save order changes

**Technical Notes:**
- Grid component already exists (responsive_grid.dart) - just add toggle UI
- DebouncedCheckbox exists - extend for multi-select
- Image reordering callbacks present (onPrimaryImageChanged)
- Follow Material Design multi-select patterns
- Save view preferences to UserPreferences

---

### 33. FAVORITES/BOOKMARKS SYSTEM
**Effort:** ~18 hours (2 day sprint)

Quick-access bookmarking for frequently used recipes.

**Key Capabilities:**
- Star/heart icon toggle on recipe cards
- "Favorites" tab in recipe list view
- Persistent favorites across devices
- Favorites count in profile
- Quick access from home screen

**Technical Notes:**
- Add `isFavorite` boolean field to Recipe model
- UserPreferences service for favorites list storage
- Real-time sync via Firestore user document
- Simple toggle with optimistic UI update

---

### 34. COOKING MODE
**Effort:** ~52 hours (1.5 week sprint)

Step-by-step hands-free cooking interface with voice commands and integrated timers.

**Key Capabilities:**
- Step-by-step navigation (previous/next)
- Voice commands ("next step", "set timer for 5 minutes")
- Integrated timers per step with notifications
- Keep screen awake during cooking
- Large text for easy reading across kitchen
- Swipe gestures for navigation
- Progress tracking (step 3 of 8)
- Quick exit to full recipe view

**Technical Notes:**
- Use speech_to_text package for voice commands
- WakelockPlus package for screen wake
- Timer service with background notifications
- Responsive design for tablet propping
- Parse timer values from instruction text
- Save cooking progress for resume

---

### 35. DIETARY RESTRICTIONS PROFILE
**Effort:** ~42 hours (1 week sprint)

User dietary preference settings to filter menu generation and recipe discovery.

**Key Capabilities:**
- Dietary preference profile in user settings:
  - Vegetarian, Vegan, Pescatarian
  - Gluten-free, Dairy-free, Nut-free
  - Low-carb, Keto, Paleo
  - Custom restrictions
- Filter AI menu generation by dietary needs
- Dietary badges on recipe cards
- Allergen warnings in recipe detail
- Recipe filtering by dietary compatibility
- Suggest substitutions for restricted ingredients

**Technical Notes:**
- Add dietaryRestrictions list to UserProfile model
- Update AI menu generation to filter recipes
- Add dietary tags to Recipe model
- Allergen detection in ingredient parsing
- UI toggles in profile settings
- Badge components for recipe cards

---

### 36. MENU TEMPLATES
**Effort:** ~38 hours (1 week sprint)

Pre-built menu templates and community-contributed menu library.

**Key Capabilities:**
- Pre-built template library:
  - "Meal Prep Sunday"
  - "Quick Weeknight Dinners"
  - "Family Breakfast Week"
  - "Vegetarian Starter Pack"
  - "Budget-Friendly Week"
- Template browser with categories
- One-tap template instantiation
- Community template submissions
- Template ratings and reviews
- Customize template after loading
- Save custom templates for sharing

**Technical Notes:**
- MenuTemplate model with metadata
- Template repository service
- Template discovery view
- Template instantiation creates Menu copy
- Community moderation for submissions
- Template analytics (usage, ratings)

---

### 37. SHOPPING LIST CATEGORY GROUPING
**Effort:** ~34 hours (4-5 day sprint)

Collapsible category sections in shopping lists for efficient in-store shopping.

**Key Capabilities:**
- Auto-categorization of items:
  - Produce, Dairy, Meat, Bakery, Frozen, Dry Goods, etc.
- Collapsible category sections
- Sort items within categories
- Custom category creation
- Drag-and-drop between categories
- Smart category learning from user corrections
- Category-based completion tracking
- Store layout customization (reorder categories)

**Technical Notes:**
- UnifiedShoppingItem already has category field (backend ready)
- CategoryGroupingWidget for list display
- Category detection service (keyword matching)
- User category preferences in UserProfile
- ML learning from user category corrections
- Real-time sync of category changes

**Priority:** HIGH - Backend exists, UI only needed

---

### 38. SMART SHOPPING SUGGESTIONS
**Effort:** ~28 hours (3-4 day sprint)

Autocomplete and intelligent item suggestions based on shopping history and recipe ingredients.

**Key Capabilities:**
- Autocomplete from user's shopping history
- Suggestions from recipe ingredients when adding to list
- One-tap add from suggestions
- Frequently purchased items
- Seasonal suggestions
- "You might also need" based on current items
- Smart quantity suggestions based on history

**Technical Notes:**
- ShoppingHistoryService tracks item additions
- Autocomplete dropdown in add item dialog
- Recipe ingredient extraction for suggestions
- Frequency analysis for popular items
- Debounced search (300ms) in item input
- Cache frequent suggestions locally

---

### 39. RECIPE REVIEWS
**Effort:** ~46 hours (1 week sprint)

Comprehensive recipe review system combining ratings, text reviews, and photos.

**Key Capabilities:**
- Rating + written review + photos (combined)
- "I cooked this" verified badge (logged cook event)
- Helpful/unhelpful voting on reviews
- Sort reviews by:
  - Most helpful
  - Most recent
  - Highest/lowest rating
- Filter reviews by rating (5-star, 4-star, etc.)
- Review photos gallery
- Review editing and deletion
- Report inappropriate reviews
- Author reputation score

**Technical Notes:**
- RecipeReview model (rating, text, imageUrls, helpfulCount, cookedVerified)
- Review repository with CRUD operations
- Helpful vote tracking per user
- Cook event tracking for verification badge
- Review moderation system
- Pagination for large review lists

---

### 40. FOLLOW SYSTEM
**Effort:** ~58 hours (1.5 week sprint)

Asymmetric follow model (in addition to friends) for creator profiles and public content.

**Key Capabilities:**
- Follow users without mutual acceptance (asymmetric)
- Follower/following counts on profiles
- Public creator profiles (different from private friends)
- Following feed (separate from friend activity)
- Follow/unfollow toggle on profiles
- Follower/following lists
- Private account option (approve followers)
- Follow notifications (optional)
- Suggested users to follow
- Creator analytics (follower growth, engagement)

**Technical Notes:**
- Follow model (followerId, followedUserId, createdAt)
- FollowRepository with CRUD operations
- UserProfile updates (followerCount, followingCount, isPublic)
- Following feed service (query followed users' activity)
- Creator dashboard view for analytics
- Coexists with existing Friends system
- Privacy settings for follow visibility

---

### 41. SOCIAL LOGIN
**Effort:** ~24 hours (3 day sprint)

Google/Apple Sign-in integration to reduce registration friction and improve conversion rates.

**Key Capabilities:**
- Google Sign-in integration
- Apple Sign-in integration (iOS requirement)
- One-tap sign-in for returning users
- Account linking (social + email/password)
- Automatic profile population from social account
- Social avatar import
- Secure token handling
- Email verification bypass for social login

**Technical Notes:**
- Firebase Auth social providers (Google, Apple)
- google_sign_in Flutter package
- sign_in_with_apple Flutter package
- Social login buttons in AuthView
- Account linking service
- Profile auto-population from social data
- Handle sign-in cancellation gracefully
- Privacy compliance for social data

**Priority:** HIGH - Critical for reducing registration friction and improving conversion rates

---

### 42. RECIPE COLLECTIONS
**Effort:** ~26 hours (1 week sprint)

Themed recipe curation with collaborative collections and social discovery.

**Key Capabilities:**
- Create named collections with description and cover image
- Add/remove recipes to collections (multi-select)
- Sort recipes within collection (manual drag-and-drop)
- Section headers within collection ("Appetizers", "Mains", "Desserts")
- Public vs. private collections
- Share collections with friends
- Collaborative collections (like collaborative recipes)
- Follow other users' collections
- Fork collections to customize
- Trending collections in DiscoveryDashboard
- Featured collections (editorial picks)
- Search collections by theme
- Recommended collections based on cooking history

**Technical Notes:**
- RecipeCollection model (name, description, coverImageUrl, recipeIds[], ownerId, isPublic, memberPermissions{})
- RecipeCollectionRepository with Firestore persistence
- RecipeCollectionService coordinating CRUD operations
- RecipeCollectionViewModel with collection management
- Integration with DiscoveryService for trending collections
- UI components: CollectionCard, CollectionDetailView, CreateCollectionDialog
- Real-time collaborative editing support
- Import collection to menu integration

**Competitive Differentiation:**
- Collaborative collections (Pinterest-style for recipes)
- Social discovery of curated recipe sets
- Integration with menu planning

---

### 43. RECIPE ATTRIBUTION & REMIXING
**Effort:** ~24 hours (3 day sprint)

Track original recipe sources and remix chains to credit creators and preserve recipe origins.

**Key Capabilities:**
- Track original recipe ID when forked
- Show remix chain (e.g., "Remixed from Anna's Pasta → Erik's Carbonara")
- Credit original creator with "Remixed from X" badge
- Link to original recipe from remixed version
- Remix statistics for creators (how many times remixed)
- Block remixing option (recipe setting)
- Notify original creator when recipe is remixed
- Remix feed in DiscoveryDashboard
- "Most remixed recipes" trending section
- Attribution preserved across multiple generations

**Technical Notes:**
- Add originalRecipeId field to Recipe model
- Add remixCount field to Recipe model
- Add allowRemixing boolean to Recipe model
- Update recipe fork logic to set originalRecipeId
- RecipeAttributionService for tracking remix chains
- Recursive query for full remix chain
- UI badge components for attribution
- Notification integration for remix events
- Analytics tracking for remix behavior

**Competitive Differentiation:**
- Full attribution chain (like GitHub forking)
- Credit system for recipe creators
- Remix discovery feed

---

### 44. VIDEO AUDIO TRANSCRIPTION
**Effort:** ~30 hours (4 day sprint)

Import recipes from YouTube/TikTok/Instagram videos that don't have captions by transcribing the audio.

**Current Behavior:**
- Videos without subtitles/captions show "Videon saknar text" dialog
- User must take a screenshot manually and use Photo Import
- No automatic extraction from spoken content

**Key Capabilities:**
- Audio extraction from video URL
- Speech-to-text transcription (Whisper API or Google Speech-to-Text)
- Swedish language support (primary)
- English language support (secondary)
- Recipe text parsing from transcription
- Fallback to current photo import if transcription fails
- Progress indicator during transcription
- Cache transcriptions to avoid re-processing

**Technical Notes:**
- Use OpenAI Whisper API (~$0.006/minute) or Google Cloud Speech-to-Text
- Firebase Cloud Function for server-side audio processing
- Extract audio from video using yt-dlp (server-side)
- Support YouTube, TikTok, Instagram Reels
- Rate limiting to manage API costs
- Quality threshold - skip if audio quality too poor
- Parse recipe from transcribed text using existing LLM pipeline

**Implementation Approach:**
1. Add "Try Audio Transcription" option in needs-screenshot dialog
2. Call Cloud Function with video URL
3. Cloud Function: extract audio → transcribe → return text
4. Parse transcription with LLM for recipe extraction
5. If successful, proceed with normal import flow
6. If failed, fall back to photo import suggestion

**Cost Considerations:**
- Whisper API: ~$0.006/minute (3-min video = ~$0.02)
- Consider daily/monthly limits per user
- Could be premium-only feature

---

### 45. HOME SCREEN WIDGETS
**Effort:** ~24 hours per platform (48 hours total)

Native home screen widgets for quick recipe access and shopping list management on iOS and Android.

**iOS Implementation (WidgetKit):**
- Today's menu widget (small/medium sizes)
- Shopping list widget with checkboxes
- Quick recipe search widget
- Recent recipes widget
- Widget configuration (select which list/menu to display)
- Deep link to app on tap
- Timeline provider for automatic updates

**Android Implementation (App Widgets):**
- Glance API for modern widget development
- Today's menu widget (multiple sizes: 2x2, 4x2, 4x4)
- Shopping list widget with inline checkbox toggle
- Recipe of the day widget
- Widget configuration activity
- RemoteViews for content updates
- Pending intents for interactions

**Key Capabilities:**
- Real-time sync with app data
- Offline support with cached content
- Theme-aware (light/dark mode)
- Battery-efficient updates
- Multiple widget sizes
- User-configurable content

**Technical Notes:**
- iOS: Swift WidgetKit extension, shared app group for data
- Android: Kotlin Glance composables or traditional RemoteViews
- Shared Dart model layer for widget data
- Platform channels for native communication
- Background refresh scheduling
- Widget gallery previews

**Priority:** MEDIUM - Enhances daily engagement, competitive differentiator

---

## Implementation Priorities

### Immediate (First Fixes) - ~317 hours
1. Missing Delete UI (~16 hrs)
2. Standard Platform Features (~84 hrs)
3. Basic UX Controls (~26 hrs)
4. Comment Reactions (~19 hrs)
5. Message Reactions (~21 hrs)
6. Chat Polls (~29 hrs)
7. Enhanced Group Chats (~46 hrs)
8. Favorites/Bookmarks System (~18 hrs) **[NEW]**
9. Shopping List Category Grouping (~34 hrs) **[NEW - HIGH PRIORITY]**
10. Social Login (~24 hrs) **[NEW - HIGH PRIORITY for conversion]**

### High Priority - Platform Polish - ~136 hours
11. Empty State Helpers (~29 hrs)
12. Notification Preferences (~33 hrs)
13. Re-engagement Onboarding (~36 hrs)
14. Personalized Push Timing (~38 hrs)

### Medium Priority - Quick Wins & High Value
15. Seasonal Ingredient Alerts (~50 hrs)
16. Smart Substitution Engine (~44 hrs)
17. Kitchen Equipment Profile (~44 hrs)
18. Wine & Beverage Pairing (~50 hrs)
19. Cooking Mode (~52 hrs) **[NEW - HIGH VALUE]**
20. Dietary Restrictions Profile (~42 hrs) **[NEW]**
21. Menu Templates (~38 hrs) **[NEW]**
22. Smart Shopping Suggestions (~28 hrs) **[NEW]**
23. Recipe Collections (~26 hrs) **[NEW]**
24. Recipe Attribution & Remixing (~24 hrs) **[NEW]**

### High Impact - Core Features
25. Educational Mode (~68 hrs)
26. Recipe Debugger (~60 hrs)
27. Batch Prep Optimizer (~52 hrs)
28. Auto-Scale Intelligence (~52 hrs)

### Premium Value - Revenue Drivers
29. Flavor Fingerprint (~98 hrs)
30. Culinary Skills Academy (~92 hrs)
31. Family Recipe Vault (~64 hrs)
32. Cost-Per-Serving Calculator (~56 hrs)

### Family & Social
33. Family Meal Voting (~56 hrs)
34. Recipe Duet Mode (~58 hrs)
35. Family Meal Converter (~54 hrs)
36. Smart Portion Advisor (~48 hrs)
37. Recipe Reviews (~46 hrs) **[NEW]**
38. Follow System (~58 hrs) **[NEW]**

### Advanced Features
39. Zero-Click Recipe Start (~58 hrs)
40. Recipe Narration Mode (~60 hrs)
41. Flavor Experiment Lab (~52 hrs)
42. Recipe Carbon Calculator (~50 hrs)
43. Chef AMAs (~66 hrs)
44. Video Audio Transcription (~30 hrs)
45. Home Screen Widgets (~48 hrs) **[NEW - Platform Enhancement]**

---

## Monetization Strategy

### Free Tier
- Basic versions of most features
- Limited usage (e.g., 3 diagnoses/month, 5 narrations/month)
- Core functionality preserved

### Premium Features
- Full feature access
- Advanced capabilities (ML, analytics)
- Offline downloads
- Personalized learning
- Certifications and badges

### Subscription Tiers
- Premium: Individual features
- Family Heritage: Voice memoirs + family features
- Skills Academy: Full technique training

---

**End of Future Features Document**
