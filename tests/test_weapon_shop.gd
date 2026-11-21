extends SceneTree

# Preload all dependencies using the working pattern from test_ammo_system.gd
const AmmoSystem = preload("res://core/game/ammo_system.gd")
const WeaponShop = preload("res://core/game/weapon_shop.gd")
const Inventory = preload("res://core/game/inventory.gd")
const ItemDB = preload("res://core/game/item_db.gd")

var ammo_system
var weapon_shop
var inventory
var item_db
var test_results = []

func _init():
	print("=== TestWeaponShop: Starting ===")
	_initialize_systems()
	run_tests()

func _initialize_systems():
	# Initialize AmmoSystem singleton first (used by WeaponShop)
	AmmoSystem.get_singleton()._ensure_initialized()
	
	# Initialize singletons
	ammo_system = AmmoSystem.get_singleton()
	weapon_shop = WeaponShop.new()
	inventory = Inventory.new()
	item_db = ItemDB.new()
	
	# Initialize systems (only core logic, no UI/3D)
	weapon_shop._ensure_core_systems()
	
	# Give some starting money for purchase tests
	weapon_shop.player_currency = 10000

func run_tests():
	test_shop_config_loading()
	test_display_generation()
	test_weapon_purchase()
	test_ammo_purchase()
	test_insufficient_funds()
	test_category_filtering()
	test_price_calculation()
	test_restock()
	
	print_results()

func test_shop_config_loading():
	var passed = true
	var msg = ""
	
	# Verify shop config loaded - _shop_data is a dict with "categories" key
	if not weapon_shop._shop_data:
		passed = false
		msg = "_shop_data not loaded"
	elif not weapon_shop._shop_data.has("categories"):
		passed = false
		msg = "categories not in _shop_data"
	elif weapon_shop._shop_data.categories.size() == 0:
		passed = false
		msg = "no categories defined"
	
	record_test("Shop config loading", passed, msg)

func test_display_generation():
	var passed = true
	var msg = ""
	
	var displays = weapon_shop.get_shop_displays()
	if not displays:
		passed = false
		msg = "get_shop_displays returned null"
	elif displays.size() == 0:
		passed = false
		msg = "no displays generated"
	else:
		# Verify display structure - _build_shop_item returns dict with id, type, name, price, etc.
		for display in displays:
			if not display.has("id") or not display.has("type") or not display.has("name") or not display.has("price") or not display.has("category"):
				passed = false
				msg = "display missing required fields: " + str(display.keys())
				break
	
	record_test("Display generation", passed, msg)

func test_weapon_purchase():
	var passed = true
	var msg = ""
	
	# Get a weapon display
	var displays = weapon_shop.get_shop_displays()
	var weapon_display = null
	for d in displays:
		if d.type == "weapon":
			weapon_display = d
			break
	
	if not weapon_display:
		passed = false
		msg = "no weapon display found for testing"
		record_test("Weapon purchase", passed, msg)
		return
	
	print("DEBUG: Weapon display:", weapon_display.id, "price:", weapon_display.price, "currency:", weapon_shop.player_currency)
	var initial_currency = weapon_shop.player_currency
	var result = weapon_shop.purchase_item(weapon_display.id, 1)
	print("DEBUG: Purchase result:", result)
	
	if not result.success:
		passed = false
		msg = "purchase failed: " + result.message
	elif weapon_shop.player_currency != initial_currency - weapon_display.price:
		passed = false
		msg = "currency not deducted correctly: " + str(weapon_shop.player_currency) + " != " + str(initial_currency - weapon_display.price)
	# Note: weapon not added to inventory since we don't have a player inventory in this test
	
	record_test("Weapon purchase", passed, msg)

func test_ammo_purchase():
	var passed = true
	var msg = ""
	
	# Get an ammo display
	var displays = weapon_shop.get_shop_displays()
	var ammo_display = null
	for d in displays:
		if d.type == "ammo":
			ammo_display = d
			break
	
	if not ammo_display:
		passed = false
		msg = "no ammo display found for testing"
		record_test("Ammo purchase", passed, msg)
		return
	
	print("DEBUG: Ammo display:", ammo_display.id, "price:", ammo_display.price, "currency:", weapon_shop.player_currency)
	var initial_currency = weapon_shop.player_currency
	var initial_ammo = ammo_system.get_reserve(ammo_display.ammo_type)
	var result = weapon_shop.purchase_item(ammo_display.id, 1)
	print("DEBUG: Ammo purchase result:", result)
	
	if not result.success:
		passed = false
		msg = "purchase failed: " + result.message
	elif weapon_shop.player_currency != initial_currency - ammo_display.price:
		passed = false
		msg = "currency not deducted correctly: " + str(weapon_shop.player_currency) + " != " + str(initial_currency - ammo_display.price)
	elif ammo_system.get_reserve(ammo_display.ammo_type) != initial_ammo + ammo_display.rounds:
		passed = false
		msg = "ammo not added to reserves: " + str(ammo_system.get_reserve(ammo_display.ammo_type)) + " != " + str(initial_ammo + ammo_display.rounds)
	
	record_test("Ammo purchase", passed, msg)

func test_insufficient_funds():
	var passed = true
	var msg = ""
	
	# Set currency to 0
	weapon_shop.player_currency = 0
	
	var displays = weapon_shop.get_shop_displays()
	if displays.size() > 0:
		var result = weapon_shop.purchase_item(displays[0].id, 1)
		if result.success:
			passed = false
			msg = "purchase should fail with insufficient funds"
		elif not result.message.to_lower().contains("fund"):
			passed = false
			msg = "error message should mention insufficient funds: " + result.message
	
	# Restore currency for other tests
	weapon_shop.player_currency = 10000
	
	record_test("Insufficient funds rejection", passed, msg)

func test_category_filtering():
	var passed = true
	var msg = ""
	
	var categories = weapon_shop.get_categories()
	if not categories or categories.size() == 0:
		passed = false
		msg = "no categories returned"
	else:
		# Test filtering by first category
		var cat = categories[0]
		var filtered = weapon_shop.get_shop_displays(cat)
		for display in filtered:
			if display.category != cat:
				passed = false
				msg = "filter returned wrong category: " + display.category + " != " + cat
				break
	
	record_test("Category filtering", passed, msg)

func test_price_calculation():
	var passed = true
	var msg = ""
	
	var displays = weapon_shop.get_shop_displays()
	if displays.size() > 0:
		var display = displays[0]
		var price = weapon_shop.calculate_price(display.id, 3)
		var expected = display.price * 3
		
		# Allow for bulk discount if implemented
		if price > expected:
			passed = false
			msg = "price for 3 units exceeds 3x unit price: " + str(price) + " > " + str(expected)
	
	record_test("Price calculation", passed, msg)

func test_restock():
	var passed = true
	var msg = ""
	
	# Test restock functionality - just verify it runs without error
	weapon_shop.restock()
	
	record_test("Restock functionality", passed, msg)

func record_test(name, passed, msg):
	test_results.append({
		"name": name,
		"passed": passed,
		"message": msg
	})
	var status = "PASS" if passed else "FAIL"
	print(status + ": " + name + ((" - " + msg) if msg else ""))

func print_results():
	var passed_count = 0
	var total = test_results.size()
	
	for r in test_results:
		if r.passed:
			passed_count += 1
	
	print("\n=== TestWeaponShop Results: " + str(passed_count) + "/" + str(total) + " passed ===")
	
	if passed_count == total:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)