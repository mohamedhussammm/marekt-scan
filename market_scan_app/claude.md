# Market Scan App — Codebase Analysis

**Generated:** 2026-06-25
**Flutter SDK:** >=3.0.0 <4.0.0
**Architecture:** Provider + SQLite (offline-first) + MongoDB REST API (online)
**Deployment:** ngrok permanent tunnel (`anytime-font-drainable.ngrok-free.dev`)

---

## Project Structure

```
market_scan_app/lib/
├── main.dart                                  # App entry, MultiProvider setup, routes
├── controllers/
│   └── scanning_controller.dart               # Barcode scan logic, cart, ML Kit (9.7KB)
├── core/
│   ├── constants/
│   │   ├── app_colors.dart                    # Color tokens
│   │   └── app_strings.dart                   # Arabic string constants
│   ├── models/
│   │   └── models.dart                        # Product, CartItem, Sale, Shift,
│   │                                          #   PettyExpense, HeldOrder, OfflineQueueItem
│   ├── providers/
│   │   └── app_provider.dart                  # Central state (774 lines)
│   ├── theme/
│   │   └── app_theme.dart                     # MaterialTheme config
│   └── utils/
│       └── barcode_validator.dart             # Barcode format validation
├── screens/
│   ├── alerts/low_stock_alerts_screen.dart    # Paginated low-stock list
│   ├── dashboard/dashboard_screen.dart        # Stats + charts
│   ├── inventory/inventory_screen.dart        # Paginated inventory (31.9KB)
│   ├── login/login_screen.dart
│   ├── pos/
│   │   ├── pos_scanner_screen.dart            # Main POS screen (63KB — largest file!)
│   │   └── sale_confirmation_screen.dart
│   ├── register/register_screen.dart
│   ├── reports/reports_screen.dart            # Monthly reports + CSV export
│   ├── settings/settings_screen.dart
│   ├── splash/splash_screen.dart
│   └── transactions/
│       └── transaction_history_screen.dart    # Full transaction history (23.2KB)
├── services/
│   ├── api_service.dart                       # HTTP REST client — singleton http.Client (622 lines)
│   ├── db_helper.dart                         # SQLite WAL-mode local cache (261 lines)
│   └── sync_engine.dart                       # Offline-first sync queue (114 lines)
└── widgets/
    ├── camera_view.dart                        # Minimal camera feed widget
    ├── main_navigation.dart                    # PageView nav + sync FAB (332 lines)
    ├── permission_denied_widget.dart           # Role-based access denied screen
    └── receipt_detail_sheet.dart              # POS receipt modal (26.8KB)
```

---

## Data Models (`core/models/models.dart`)

| Model | Key Fields | Notes |
|-------|-----------|-------|
| `Product` | id, name, barcode, category, costPrice, sellingPrice, stockQuantity, minStockLevel, unit, imageUrl, isRegistered | `isRegistered` distinguishes global catalog vs store-specific inventory |
| `CartItem` | product, quantity, discountPercent | Computes subtotal, discountAmount, total |
| `Sale` | id, receiptNumber, items, subtotal, discount, tax, total, amountPaid, paymentMethod, type, cashierName, isOffline | `isOffline` flag set when queued locally |
| `SalesSummary` | totalRevenue, totalProfit, totalOrders, totalItemsSold, date | Used for reports |
| `Shift` | id, storeName, cashierUsername, startTime, endTime, status, startingCash, endingCash, totalSales, cashSales, cardSales | Status: `'open'` or `'closed'` |
| `PettyExpense` | id, storeName, cashierUsername, shiftId, amount, category, description, timestamp, isOffline | `isOffline` flag set when queued locally |
| `HeldOrder` | id, items, timestamp | Held orders in POS (not persisted to DB) |
| `OfflineQueueItem` | id, offlineId, operation, payload, createdAt, retries, status | Local SQLite offline queue row |

### `Product.fromJson()` field mapping (important dual-source support)
- `id` ← `json['_id'] ?? json['id'] ?? json['barcodeId']`
- `barcode` ← `json['barcodeId'] ?? json['barcode']`
- `stockQuantity` ← `json['currentStock'] ?? json['stockQuantity']`
- `minStockLevel` ← `json['minThreshold'] ?? json['minStockLevel']`
- `isRegistered` handles both `bool` (MongoDB) and `int 0/1` (SQLite)

---

## State Architecture

### AppProvider (`core/providers/app_provider.dart`) — Central State
**What it holds:**
- `_products: List<Product>` — used ONLY by POS's 3-tier lookup (no longer loaded on login; inventory screen is now self-contained)
- `_sales: List<Sale>` — last 10 transactions from `loadDashboardStats()`
- `_cart: List<CartItem>` — cart state (though POS now uses `ScanningController` cart)
- `_filteredProductsCache`, `_lowStockProductsCache`, `_categoriesCache` — O(n) computed on mutation
- Dashboard stats: `_todaySalesTotal`, `_todayOrdersCount`, `_allTimeRevenue`, `_netProfit`, `_totalOrdersCount`, `_lowStockCount`, `_totalProductsCount`, `_weeklySales`, `_topProductsList`, `_categoriesAggregationList`
- Shift: `_activeShift`, `_todayExpenses`, `_cashOnHand`, `_shiftHistory`
- Settings: `_storeName`, `_storeAddress`, `_storePhone`, `_storeEmail`, `_taxRate`, `_notificationsEnabled`, `_darkModeEnabled`
- RBAC: `_userRole` (`'admin'` | `'cashier'`), `_username`

**Key behaviors:**
- Uses **`SyncEngine.instance`** for all offline operations
- Exposes `api` getter so screens can make isolated API calls (e.g., InventoryScreen)
- `logout()` calls `_db.clearAllProducts()` — clears SQLite to isolate per-store data
- `completeSale()` is optimistic: UI updated immediately, then API called with 8s timeout; failure queues to SyncEngine
- `loadDashboardStats()` fires 5 parallel API calls via `Future.wait`; on failure reads cached counts from `SharedPreferences` or SQLite

**Login flow (now parallel):**
```dart
// ✅ FIXED: parallel load (was sequential before)
await Future.wait([
  loadSettings(),
  loadDashboardStats(),
  loadActiveShift(),
]);
// Products are NOT loaded here — InventoryScreen fetches its own paginated data
```

### ScanningController (`controllers/scanning_controller.dart`)
- Separate `ChangeNotifier` for POS screen
- Has its own `ApiService()` instance → **still creates a second http.Client** (see Known Issues)
- 3-tier product lookup: Memory (`AppProvider._products`) → SQLite → API
- Manages `heldOrders: List<HeldOrder>` for the "hold order" feature
- Signals unknown barcodes and unregistered products via `unknownBarcode` / `unregisteredProduct` notifier fields
- The POS screen subscribes via `addListener(_onScannerUpdate)` in `initState`, removed in `dispose`

### SyncEngine (`services/sync_engine.dart`) — Singleton
- `SyncEngine.instance` — singleton, instantiated in `main.dart` and registered as `ChangeNotifierProvider.value`
- Polls every **30 seconds** via `Timer.periodic`
- Listens to `Connectivity().onConnectivityChanged` for immediate flush on reconnect
- `flushQueue()` sends a `POST /api/sync/batch` request with all pending ops
- The server processes ops idempotently (using `offline_id` for deduplication on expenses/products)
- `cancelOp(id)` — removes a specific pending operation
- `pendingCount` and `isSyncing` are observable for the UI

**Supported operation types:**
| Type | Handler |
|------|---------|
| `checkout` | Reuses `salesController.createTransaction` |
| `add_expense` | `processExpense()` with `offline_id` deduplication |
| `add_product` / `update_product` | Upserts global `Product` + `StoreInventory` |
| `delete_product` | Deletes from `StoreInventory` only |
| `update_stock` | `$inc currentStock` on `StoreInventory` |

---

## Navigation Architecture

### Current: PageView with Static Screen Lists
```dart
// main_navigation.dart — P0 fix applied
static const List<Widget> _adminScreens = [
  DashboardScreen(), PosScannerScreen(), InventoryScreen(), ReportsScreen(), SettingsScreen(),
];
static const List<Widget> _cashierScreens = [
  DashboardScreen(), PosScannerScreen(), PermissionDeniedWidget(), PermissionDeniedWidget(), SettingsScreen(),
];
// PageView (not IndexedStack) — only one screen mounted at a time
PageView(controller: _pageController, physics: NeverScrollableScrollPhysics(), ...)
```

**Previous issue FIXED:** Was `IndexedStack` (kept ALL visited screens in RAM). Now `PageView` — only the current screen is mounted.

**Previous issue FIXED:** Was `context.watch<AppProvider>()` → rebuilds entire nav on ANY state change. Now `context.select<AppProvider, bool>((p) => p.userRole == 'cashier')` — only rebuilds on role change.

### Cart Badge (Bottom Nav)
Uses `Selector<AppProvider, int>` targeting only `cartItemCount` — isolated rebuild.

### Offline Sync FAB
`Selector<SyncEngine, int>` on `pendingCount` — amber floating button with count. Opens `_showSyncBottomSheet()` which lists all pending ops with cancel + manual sync options.

### Route Table
| Route | Screen |
|-------|--------|
| `/splash` | `SplashScreen` |
| `/login` | `LoginScreen` |
| `/register` | `RegisterScreen` |
| `/home` | `MainNavigation` |
| `/pos` | `PosScannerScreen` |
| `/sale-confirmation` | `SaleConfirmationScreen` |
| `/inventory` | `InventoryScreen` |
| `/reports` | `ReportsScreen` |
| `/alerts` | `LowStockAlertsScreen` |
| `/settings` | `SettingsScreen` |
| `/transactions-history` | `TransactionHistoryScreen` |

---

## Screen File Sizes (Current)

| Screen | Size | Notes |
|--------|------|-------|
| `pos_scanner_screen.dart` | **63,043 bytes** | 1,468 lines — massive, consider splitting |
| `receipt_detail_sheet.dart` | **26,842 bytes** | Widget-only, acceptable |
| `inventory_screen.dart` | **31,941 bytes** | 780 lines — includes inline widgets |
| `transaction_history_screen.dart` | **23,204 bytes** | Full transaction history |
| `main_navigation.dart` | **14,284 bytes** | 332 lines — includes sync bottom sheet |
| `api_service.dart` | **19,263 bytes** | 622 lines |
| `app_provider.dart` | **25,958 bytes** | 774 lines |

---

## SQLite Schema (`db_helper.dart`, version 4)

### `products` table
```sql
CREATE TABLE products (
  barcodeId TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  sellingPrice REAL NOT NULL,
  costPrice REAL NOT NULL,
  currentStock INTEGER NOT NULL,
  minThreshold INTEGER DEFAULT 10,
  isRegistered INTEGER DEFAULT 1,
  unit TEXT DEFAULT 'قطعة',
  imageUrl TEXT
)
```

### `offline_queue` table (added in v4)
```sql
CREATE TABLE offline_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  offline_id TEXT NOT NULL UNIQUE,
  operation TEXT NOT NULL,
  payload TEXT NOT NULL,  -- JSON encoded
  created_at TEXT NOT NULL,
  retries INTEGER DEFAULT 0,
  status TEXT DEFAULT 'pending'  -- 'pending' | 'failed' (after 5 retries)
)
```

**WAL mode:** Both `PRAGMA journal_mode=WAL` and `PRAGMA synchronous=NORMAL` are set on `onConfigure`.

**Batch insert optimization:** `insertProductsBatch()` uses `ConflictAlgorithm.ignore` (not `replace`) — avoids DELETE+INSERT for every unchanged row on sync. Individual `insertProduct()` still uses `replace` for targeted updates.

---

## API Service (`services/api_service.dart`)

### Architecture
- **Shared singleton http.Client:** `static final http.Client _client = http.Client()` — keeps persistent TCP connections (HTTP keep-alive)
- **Static context headers:** `currentStoreName`, `currentUserRole`, `currentUsername` — set at login, cleared on logout
- **URL management:** Default ngrok URL; overridable via Settings screen (persisted in `SharedPreferences` as `server_ip`); `_normalizeUrl()` sanitizes and validates user input

### Complete API Endpoint Map

| Method | URL | Flutter Method |
|--------|-----|----------------|
| `POST` | `/api/auth/login` | `login()` |
| `POST` | `/api/auth/register` | `register()` |
| `GET` | `/api/products?page&limit&search&category` | `getProductsPaginated()` |
| `GET` | `/api/products/low-stock?page&limit` | `getLowStockProducts()` |
| `GET` | `/api/products/:barcode` | `getProductByBarcode()` |
| `GET` | `/api/products` | `getAllProducts()` *(used by ScanningController)* |
| `POST` | `/api/products` | `addProduct()` |
| `PUT` | `/api/products/:barcode` | `updateProduct()` |
| `DELETE` | `/api/products/:barcode` | `deleteProduct()` |
| `PUT` | `/api/products/:barcode/stock` | `updateStock()` |
| `POST` | `/api/transactions` | `checkout()` |
| `GET` | `/api/transactions?limit&skip` | `getTransactions()` |
| `GET` | `/api/reports/summary` | `getDashboardSummary()` |
| `GET` | `/api/reports/weekly-chart` | `getWeeklyChart()` |
| `GET` | `/api/reports/top-products` | `getTopProducts()` |
| `GET` | `/api/reports/by-category` | `getSalesByCategory()` |
| `GET` | `/api/settings` | `getSettings()` |
| `PUT` | `/api/settings` | `saveSettings()` |
| `GET` | `/api/shifts/active` | `getActiveShift()` |
| `POST` | `/api/shifts/open` | `openShift()` |
| `POST` | `/api/shifts/close` | `closeShift()` |
| `GET` | `/api/shifts/history` | `getShiftHistory()` |
| `POST` | `/api/expenses` | `recordExpense()` |
| `GET` | `/api/expenses?shiftId&all&category` | `getExpenses()` |
| `GET` | `/api/expenses/category-summary` | `getExpenseCategorySummary()` |
| `POST` | `/api/logs/restricted` | `reportSecurityViolation()` |
| `POST` | `/api/sync/batch` | `syncBatch()` |

**Offline fallback for `getProductsPaginated()`:** On catch, falls back to SQLite (`db.getAllProducts()`), applies local search/category filter, and paginates locally. Returns `fromCache: true`.

---

## Backend Analysis (Node.js + Express 5 + Mongoose 9)

### Server Architecture
- **Port:** 3000 (default) or `process.env.PORT`
- **Auth:** Custom header-based (no JWT). Headers: `x-store-name`, `x-user-role`, `x-username` — parsed in global middleware and attached to `req`
- **Multi-tenancy:** All queries scoped by `req.storeName`
- **Role enforcement:** `checkOwner` middleware (in `middleware/auth.js`) blocks non-admin/owner on write routes for products; logs violation to `SecurityLog` collection

### MongoDB Models

| Model | Collection | Key Fields |
|-------|-----------|-----------|
| `Product` | `products` | `barcodeId` (PK), `name`, `category` — global catalog |
| `StoreInventory` | `storeinventories` | `storeName`, `barcodeId` (compound unique), `sellingPrice`, `costPrice`, `currentStock`, `minThreshold` — per-store pricing |
| `Transaction` | `transactions` | `storeName`, `cashierName`, `items[]`, `totalAmount`, `paymentMethod`, `receiptNumber`, `offline_id` |
| `Expense` | `expenses` | `storeName`, `cashierUsername`, `shiftId`, `amount`, `category`, `description`, `offline_id` |
| `Shift` | `shifts` | `storeName`, `cashierUsername`, `startTime`, `endTime`, `status`, `startingCash`, `endingCash`, `totalSales`, `paymentMethodsBreakdown` |
| `User` | `users` | `username`, `email`, `password` (hashed), `storeName`, `role` |
| `Settings` | `settings` | `storeName` (unique), `taxRate`, `address`, `phone`, etc. |
| `SecurityLog` | `securitylogs` | `username`, `storeName`, `action`, `details` |

### Route Files Summary

| File | Routes |
|------|--------|
| `routes/auth.js` | `POST /login`, `POST /register` |
| `routes/products.js` | Full CRUD + `/low-stock` paginated + `/:barcode/stock` |
| `routes/transactions.js` | `GET /` (with limit/skip), `POST /` |
| `routes/shifts.js` | `GET /active`, `POST /open`, `POST /close`, `GET /history` |
| `routes/expenses.js` | `POST /`, `GET /`, `GET /category-summary` |
| `routes/reports.js` | `/summary`, `/weekly-chart`, `/top-products`, `/by-category`, `/monthly/csv` |
| `routes/settings.js` | `GET /`, `PUT /` |
| `routes/suppliers.js` | Basic supplier CRUD |
| `routes/logs.js` | `POST /restricted` (security violations) |
| `routes/sync.js` | `POST /batch` — processes `checkout`, `add_expense`, `add_product`, `update_product`, `delete_product`, `update_stock` |

### Backend Known Issues
- **No pagination on `GET /api/transactions`** — fetches ALL transactions on history screen (unbounded query)
- **`expenses.js` has console.log debug statements** in production route (lines 9-11)
- **`update_stock` sync not strictly idempotent** — duplicate stock updates possible if offline_queue not cleared properly; acknowledged in code comment

---

## Role-Based Access Control

| Feature | Admin | Cashier |
|---------|-------|---------|
| Dashboard | ✅ | ✅ |
| POS Scanner | ✅ | ✅ (shift must be open) |
| Inventory (write) | ✅ | ❌ → `PermissionDeniedWidget` |
| Reports | ✅ | ❌ → `PermissionDeniedWidget` |
| Settings | ✅ | ✅ (read-only) |
| Add/Edit/Delete Product | ✅ | ❌ + security log |
| Register unpriced product | ✅ | ❌ + security log |
| Open/Close Shift | ✅ | ✅ |
| Record Petty Expense | ✅ | ✅ (requires open shift) |

**Cashier enforcement in POS:** When `unknownBarcode` or `unregisteredProduct` is detected for a cashier, `logSecurityViolation()` is called and a warning SnackBar is shown. No product creation dialog is shown.

**Server-side enforcement:** `checkOwner` middleware on all product write endpoints (`POST /api/products`, `PUT /api/products/:barcode`, `DELETE /api/products/:barcode`, `PUT /api/products/:barcode/stock`).

---

## Inventory Screen Architecture

The `InventoryScreen` is now **fully self-contained and paginated** — it does NOT depend on `AppProvider._products`.

**Key behaviors:**
- Fetches its own data via `context.read<AppProvider>().api.getProductsPaginated()`
- Infinite scroll — triggers next page fetch when scroll position ≥ `maxScrollExtent - 400`
- **Debounced search:** 400ms after last keystroke, sends to backend (MongoDB regex, server-side)
- **Category filter:** Not yet implemented in the UI (search is plain text)
- Add/Edit/Delete all trigger `_refresh()` (re-fetch page 1)
- **Offline state:** Shows amber banner when `fromCache: true`; shows full-screen error when offline + no cached data
- `RepaintBoundary` on each `_ProductListTile` — isolates per-tile repaints
- `ValueKey(p.barcode)` on each tile — stable keys prevent unnecessary rebuilds on scroll

---

## Known Issues / Remaining Items

### 🔴 CRITICAL
1. **`ScanningController` creates its own `ApiService()`** — but `ApiService._client` is `static`, so the HTTP client is actually shared. The issue is a **second `ApiService` instance** object is created unnecessarily. Low actual overhead but semantically messy.

2. **`pos_scanner_screen.dart` is 63KB / 1,468 lines** — a single file with 15+ methods and nested dialogs. Splitting into sub-widgets would improve maintainability significantly.

### 🟠 HIGH IMPACT
3. **No pagination on `GET /api/transactions`** (`routes/transactions.js`) — the transaction history screen (`transaction_history_screen.dart`) fetches ALL transactions on load. With 10,000+ transactions this will be slow and OOM-prone.

4. **`update_stock` sync idempotency** — if the same `update_stock` operation is retried after partial success, stock will be incremented twice. Needs an inventory movement log for strict idempotency.

5. **Debug `console.log` in `routes/expenses.js`** (lines 9-11) — logs full request headers/body in production. Remove before deploying to external server.

6. **`_updateFilterCaches()` still called on every product mutation in AppProvider** — for the POS memory cache this is now less critical (inventory screen is decoupled), but still runs on `completeSale`, `addProduct`, `updateProduct`, `deleteProduct`, `addStock`. With 3200+ products in memory this is an O(n) scan on each operation.

### 🟡 MEDIUM IMPACT
7. **`withOpacity()` deprecated** — used in `pos_scanner_screen.dart` and other screens. Should use `.withValues(alpha: x)`. Some screens have been updated already (e.g., `inventory_screen.dart`).

8. **`avoid_print` violations** — `print()` calls remain in `api_service.dart` (16 places), `app_provider.dart` (`loadDashboardStats`, `loadActiveShift`, `fetchShiftHistory`), and `pos_scanner_screen.dart`. Should use `debugPrint()` which is no-op in release mode.

9. **Splash screen timing** — verify if the hardcoded delay was reduced. If still 3 seconds, should be reduced or removed in favor of data-ready navigation.

10. **`pos_scanner_screen.dart` line 161** — has `print("ElevatedButton - Pressed! ...")` — debug statement in production UI.

### 🟢 MINOR / POLISH
11. `unnecessary_brace_in_string_interps` — e.g., `'${barcode}'` → `'$barcode'` (line 129 of pos_scanner_screen.dart)
12. `_categoriesCache` in AppProvider is recomputed from `_products` on every mutation — but `_products` is no longer bulk-loaded (it's empty for most users). This cache is mostly unused now.
13. No `const` constructors on private widget classes in inventory_screen.dart — small miss, easy win.

---

## Performance Improvements Applied (vs. Previous Analysis)

| Issue | Status |
|-------|--------|
| `context.watch<AppProvider>()` in MainNavigation | ✅ Fixed → `context.select` targeting `userRole` only |
| Sequential login data loading | ✅ Fixed → `Future.wait([loadSettings(), loadDashboardStats(), loadActiveShift()])` |
| `completeSale()` blocks UI | ✅ Fixed → `notifyListeners()` before API call; `loadDashboardStats()` unawaited |
| Splash screen 3s hardcoded wait | ❓ Verify current state |
| Double HTTP clients | ⚠️ Partially fixed — `ApiService._client` is now `static`, so only one TCP pool, but two `ApiService` instances still created |
| `_updateFilterCaches()` on every mutation | ⚠️ Still exists, but less impactful now that InventoryScreen is decoupled |
| `IndexedStack` keeping all screens in RAM | ✅ Fixed → `PageView` (only current screen mounted) |
| Bulk product load on login (3200 items) | ✅ Fixed → removed; InventoryScreen fetches paginated |
| `insertProductsBatch` with `ConflictAlgorithm.replace` | ✅ Fixed → `ConflictAlgorithm.ignore` |
| `GridView.count` with `shrinkWrap` in Dashboard | ❓ Verify current state |

---

## Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `provider` | ^6.1.2 | State management |
| `shared_preferences` | ^2.3.3 | Persist server IP, cached counts |
| `sqflite` | ^2.3.0 | Local SQLite cache (WAL mode) |
| `http` | ^1.2.0 | REST API client (shared singleton) |
| `mobile_scanner` | ^6.0.10 | Barcode scanning (**not** google_mlkit — updated!) |
| `connectivity_plus` | ^7.1.1 | Network state detection |
| `uuid` | ^4.5.3 | Offline ID generation |
| `fl_chart` | ^0.70.2 | Charts in dashboard/reports |
| `google_fonts` | ^6.2.1 | Typography |
| `audioplayers` | ^6.0.0 | Scan beep sound |
| `vibration` | ^3.1.8 | Haptic feedback |
| `url_launcher` | ^6.3.0 | CSV export |
| `flutter_localizations` | SDK | Arabic RTL support |
| `intl` | ^0.20.2 | Number/date formatting |
| `path_provider` | ^2.1.0 | SQLite DB path |
| `path` | ^1.9.0 | Path manipulation |

### Backend Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| `express` | ^5.2.1 | Web framework |
| `mongoose` | ^9.6.3 | MongoDB ODM |
| `cors` | ^2.8.6 | CORS middleware |
| `dotenv` | ^17.4.2 | Environment variables |
| `fast-csv` | ^5.0.7 | CSV report generation |

---

## Important Notes for AI Assistants

1. **Scanner library changed:** The old `google_mlkit_barcode_scanning` + `camera` packages have been replaced with `mobile_scanner: ^6.0.10`. Do not use ML Kit camera APIs — use `MobileScannerController` and `MobileScanner` widget.

2. **Inventory screen is decoupled:** Do NOT add code that depends on `AppProvider.products` for the inventory screen. It has its own paginated API calls via `ApiService.getProductsPaginated()`.

3. **Offline ops go through SyncEngine:** When adding any new write operation that needs offline support, use `_syncEngine.enqueue(operationType, payload)` and add the operation handler in `routes/sync.js → processOperation()`.

4. **Store isolation:** Every backend query must be scoped to `req.storeName` (set from `x-store-name` header). Never query global data without store filtering (except the global `Product` catalog which is intentionally shared).

5. **Header auth:** There is NO JWT/session token. Role and identity are trusted from headers `x-user-role` and `x-username`. The `checkOwner` middleware enforces admin-only routes.

6. **Product data model split:** MongoDB has two collections — `Product` (global catalog: name, category, barcode) and `StoreInventory` (per-store: prices, stock). The Flutter `Product` model merges these. When writing backend queries, always join or cross-reference both.

7. **`mobile_scanner` API notes:** Use `MobileScannerController` (not `CameraController`). Barcode detection is via `onDetect` callback on the `MobileScanner` widget. Use `_scannerCtrl.toggleTorch()` for flashlight. Use `_scannerCtrl.stop()` and `_scannerCtrl.dispose()` in `dispose()`.
