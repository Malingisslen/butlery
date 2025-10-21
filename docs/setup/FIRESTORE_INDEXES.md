# Firestore Index Requirements

## User Search Functionality

The enhanced user search functionality requires the following Firestore composite indexes for optimal performance:

### Collection: `public_profiles`
**Composite Index for Name Search:**
- `isSearchable` (Ascending)
- `displayNameLower` (Ascending)

**Composite Index for Email Search:**
- `allowEmailSearch` (Ascending)  
- `email` (Ascending)

**Index Definitions for Firebase Console:**
```
Collection ID: public_profiles
Index 1:
  - isSearchable: Ascending
  - displayNameLower: Ascending

Index 2:
  - allowEmailSearch: Ascending
  - email: Ascending
```

### Friend Request Collections
**Collection: `friend_requests`**
- No additional indexes needed (uses simple queries)

**Collection: `group_invitations`**
- No additional indexes needed (uses simple queries)

### Fallback Strategy
If the composite index is not available, the search implementation includes comprehensive fallback logic:

1. **Primary (Indexed Search)**: Uses composite index for optimal performance
2. **Fallback Search**: Queries `isSearchable = true` and filters in-memory
3. **Basic Search**: Minimal query with client-side filtering as last resort

### Performance Impact
- **With Index**: Sub-second search response times
- **Without Index**: 2-5 second response times depending on collection size
- **Graceful Degradation**: Search functionality remains available even without indexes

### Firebase Console Setup
1. Go to Firebase Console → Firestore → Indexes
2. Click "Create Index"
3. Collection ID: `public_profiles`
4. Add fields: `isSearchable` (Ascending), `displayNameLower` (Ascending)
5. Enable index

### Error Monitoring
The search implementation includes comprehensive error logging that will identify missing indexes:
- `AppLogger.warning` for fallback usage
- `AppLogger.error` for search failures
- Performance metrics tracking for optimization

## Implementation Status
✅ Enhanced search with fallback logic implemented
✅ Error handling and logging added
✅ Production-ready graceful degradation
⚠️ Composite index needs manual setup in Firebase Console