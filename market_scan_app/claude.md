# Market Scan App — Codebase Analysis

**Generated:** 2026-05-31
**Flutter SDK:** >=3.0.0 <4.0.0
**Architecture:** Provider + SQLite (offline) + MongoDB REST API (online)

---

## Project Structure

```
lib/
├── main.dart                        # App entry point, providers, routes
├── controllers/
│   └── scanning_controller.dart     # Barcode scanning, cart logic, ML Kit
├── core/
│   ├── constants/
│   │   ├── app_colors.dart          # Color tokens
│   │   ├── app_strings.dart         # Arabic string constants
│   ├── models/
│   │   └── models.dart              # Product, CartItem, Sale, SalesSummary
│   ├── providers/
│   │   └── app_provider.dart        # Central state: products, cart, sales, auth
│   └── theme/
│       └── app_theme.dart           # MaterialTheme config
├── screens/
│   ├── alerts/low_stock_alerts_screen.dart
│   ├── dashboard/dashboard_screen.dart
│   ├── inventory/inventory_screen.dart
│   ├── login/login_screen.dart
│   ├── pos/
│   │   ├── pos_scanner_screen.dart  # ML Kit scanner + cart (24KB!)
│   │   └── sale_confirmation_screen.dart
│   ├── register/register_screen.dart
│   ├── reports/reports_screen.dart
│   ├── settings/settings_screen.dart
│   └── splash/splash_screen.dart
├── services/
│   ├── api_service.dart             # HTTP REST client (285 lines)
│   └── db_helper.dart               # SQLite WAL-mode local cache
└── widgets/
    ├── camera_view.dart             # Camera feed widget
    ├── main_navigation.dart         # IndexedStack nav with lazy init
    └── receipt_detail_sheet.dart    # POS receipt modal (26KB!)
```

---

## State Architecture

### AppProvider (Central State)
- Holds all products, sales, cart items in memory lists
- Two-tier data loading: API → SQLite fallback
- `_updateFilterCaches()` runs on every product change (linear scan)
- `loadDashboardStats()` fires 5 parallel API requests via `Future.wait`
- `context.watch<AppProvider>()` in `MainNavigation.build()` — **DANGEROUS**: rebuilds entire nav bar on ANY state change

### ScanningController (Scanner State)
- Separate `ChangeNotifier` for the POS screen
- Has its own `ApiService` instance (creates a second HTTP client)
- 3-tier product lookup: Memory Cache → SQLite → API
- Checkout calls `_api.checkout()` directly, then separately `AppProvider.loadDashboardStats()` is called from the screen

### Data Flow Issues Found
1. **Double `ApiService` instances**: Both `AppProvider` and `ScanningController` create their own `ApiService()` → two HTTP client connections
2. **Sequential login**: `loadSettings()` → `loadProducts()` → `loadDashboardStats()` runs **sequentially**, not in parallel
3. **`notifyListeners()` storms**: `addProduct`, `updateProduct`, `deleteProduct` each call `notifyListeners()` 2-3 times
4. **`context.watch` in MainNavigation**: The whole bottom nav rebuilds on ANY AppProvider change (cart count, products, anything)

---

## Navigation Architecture

### Current: IndexedStack with Lazy Init
```dart
// main_navigation.dart
final List<bool> _initialized = [true, false, false, false, false];
// Dashboard pre-initialized, others lazy on first tap
IndexedStack(index: _currentIndex, children: [...])
```
**Problem**: IndexedStack keeps ALL initialized screens in memory simultaneously. Once all 5 screens are visited, all 5 widget trees live in RAM.

### Screen Sizes (sizeBytes)
| Screen | Size |
|--------|------|
| pos_scanner_screen.dart | 24,292 bytes |
| receipt_detail_sheet.dart | 26,515 bytes |
| inventory_screen.dart | 19,696 bytes |
| reports_screen.dart | 16,073 bytes |
| settings_screen.dart | 18,688 bytes |
| dashboard_screen.dart | 18,769 bytes |

---

## Performance Issues Identified (Priority Order)

### 🔴 CRITICAL

1. **`context.watch<AppProvider>()` in MainNavigation** (main_navigation.dart:33)
   - Triggers full `build()` of the bottom nav bar on EVERY notifyListeners() call
   - Should be `Selector` targeting only `cartItemCount`

2. **Sequential post-login data loading** (app_provider.dart:113-122)
   - `loadSettings()` then `loadProducts()` then `loadDashboardStats()` — all sequential
   - Login feels slow because each awaits the previous
   - Fix: `Future.wait([loadSettings(), loadProducts(), loadDashboardStats()])`

3. **`completeSale()` blocks UI with `loadDashboardStats()`** (app_provider.dart:430)
   - After checkout, immediately awaits full dashboard reload before returning
   - User sees frozen screen for 1-2 seconds after every sale
   - Fix: Call `loadDashboardStats()` unawaited (fire and forget after local state update)

4. **Splash screen hardcoded 3-second wait** (splash_screen.dart:28)
   - Always waits 3 full seconds regardless of whether data is ready
   - Fix: Reduce to 1.5s max, or navigate immediately once API init is done

### 🟠 HIGH IMPACT

5. **Double HTTP clients** — `AppProvider` and `ScanningController` each instantiate `ApiService()` with their own `http.Client`. Should share a single static/singleton client.

6. **`_updateFilterCaches()` called on every mutation** (app_provider.dart:68-81)
   - Linear scan of entire product list on every add/remove/update
   - With 1000+ products, this is expensive
   - Fix: Use `compute()` isolate for large lists, or debounce

7. **`NumberFormat` re-created every build** (dashboard_screen.dart:16)
   - `final currencyFmt = NumberFormat('#,##0.00', 'ar')` inside `build()`
   - Fix: Make it a `static final` constant

8. **Reports screen hardcodes IP** (reports_screen.dart:33)
   - `Uri.parse('http://192.168.1.22:3000/api/reports/monthly/csv')` 
   - Should use `ApiService.baseUrl`

### 🟡 MEDIUM IMPACT

9. **`GridView.count` with `shrinkWrap: true`** in Dashboard
   - Forces a double-pass layout. Replace with `SliverGrid` since it's inside `CustomScrollView`

10. **`receipt_detail_sheet.dart` is 26KB** — a single widget file that does too much. The `ReceiptTeethClipper` and `DashedDivider` can be extracted but this is cosmetic.

11. **`IndexedStack` keeps all visited screens in memory** — After user visits all 5 tabs, all 5 widget trees + their states live simultaneously in RAM. For a POS device with limited RAM, this matters.

12. **No `const` constructors on `_StatCard`, `_QuickAction`** in dashboard — small miss, easy win.

13. **`loadDashboardStats()` in `addStock`** (app_provider.dart:514) — full API reload for just adding stock. Wasteful.

### 🟢 MINOR / POLISH

14. `withOpacity()` deprecated across 20+ places — should use `.withValues(alpha: x)`
15. `avoid_print` — debug prints in production code in api_service.dart (16 places)
16. `unnecessary_brace_in_string_interps` — trivial
17. `unused_local_variable 'message'` in low_stock_alerts_screen.dart

---

## Backend Analysis (Node.js Express)

| Route | File |
|-------|------|
| POST /api/auth/register | routes/auth.js |
| POST /api/auth/login | routes/auth.js |
| GET/POST /api/products | routes/products.js |
| GET/POST /api/transactions | routes/transactions.js |
| GET /api/reports/... | routes/reports.js |
| GET/PUT /api/settings | routes/settings.js |
| GET/POST /api/suppliers | routes/suppliers.js |

**Fixed Issues:** MongoDB session transactions removed (incompatible with standalone)
**Remaining:** No pagination on `GET /api/transactions` — fetches ALL transactions every dashboard load

---

## Key Dependencies

| Package | Purpose |
|---------|---------|
| provider ^6.1.2 | State management |
| shared_preferences ^2.3.3 | Persist server IP, settings |
| sqflite ^2.3.0 | Local SQLite cache (WAL mode ✅) |
| http ^1.2.0 | REST API client |
| google_mlkit_barcode_scanning ^0.12.0 | Barcode ML Kit |
| camera ^0.11.0 | Camera feed |
| fl_chart ^0.70.2 | Charts in dashboard/reports |
| audioplayers ^6.0.0 | Scan beep sound |
| vibration ^3.1.8 | Haptic feedback |
| url_launcher ^6.3.0 | CSV export |
