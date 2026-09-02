extends Reference

const CATEGORY_ORDER = [
	"Maintenance",
	"Space",
	"Factories",
	"Population",
	"Food",
	"Stability",
]

# Tile order within a category: grouped by function/tier; leftovers keep alphabetical order.
const CATEGORY_TILES = {
	"Maintenance": [
		"Battery - Tier 1", "Battery - Tier 2", "Battery - Tier 3",
		"Workshop",
		"Stockpile - Small", "Stockpile - Medium", "Stockpile - Large",
		"Fire Station", "Drone Bay",
	],
	"Space": [
		"Docking Bay", "EVA Airlock", "Probe Launcher", "Colonization Training Center",
	],
	"Factories": [
		"Tech Lab",
		"Steel Mill", "Electronics Factory", "Polymer Refinery",
		"Fusion Station", "Nuclear Power Plant",
		"Waste Treatment Center", "Water Treatment Center",
	],
	"Population": [
		"Crew Quarters", "Optimized Quarter", "Domotic Quarter", "Cell Housing",
		"Cryonics Center", "Infirmary", "Health Center",
	],
	"Food": [
		"Algae Farm", "Algae Plantation", "Crop Farm", "Crop Field",
		"Insect Farm", "Mushroom Wall", "Mess Hall",
	],
	"Stability": [
		"DLS Center",
		"Alternative Life Center", "Hull Temple", "Memorial", "Observatory",
		"Exo-Fighting Dome", "Legislative Strengthening Center",
	],
}

# Stockpile specialisation: storable resources; MMB cycles these plus none.
const STOCKPILE_RESOURCES = [
	"Iron", "Alloy", "Carbon", "Polymer", "Silicon", "Electronics",
	"Food", "Ice", "Hydrogen", "Waste", "Cryopod",
]

# Hover highlight shared by grid tiles and sidebar buttons: hover_color targets a constant
# luminance delta (dark tiles brighten, bright tiles darken) so every building reads about
# the same; hover_texture bakes a radial gradient (base at the center, hover at the corners)
# into a texture, because drawing dozens of colored rects trips the GLES2 batcher's color-smear bug.
const HOVER_SHIFT = 0.3

static func hover_luminance(color: Color) -> float:
	return color.r * 0.299 + color.g * 0.587 + color.b * 0.114

static func hover_color(base: Color) -> Color:
	var lum = hover_luminance(base)
	if lum < 0.5:
		var k_up = HOVER_SHIFT / (1.0 - lum)
		return Color(
			base.r + (1.0 - base.r) * k_up,
			base.g + (1.0 - base.g) * k_up,
			base.b + (1.0 - base.b) * k_up)
	var k_down = HOVER_SHIFT / lum
	return Color(base.r * (1.0 - k_down), base.g * (1.0 - k_down), base.b * (1.0 - k_down))

static func hover_texture(size: Vector2, base: Color) -> ImageTexture:
	var w = int(size.x)
	var h = int(size.y)
	var img = Image.new()
	img.create(w, h, false, Image.FORMAT_RGBA8)
	img.lock()
	var half = size * 0.5
	var dist = half.length()
	var hover = hover_color(base)
	for y in h:
		for x in w:
			var dx = x + 0.5 - half.x
			var dy = y + 0.5 - half.y
			var d = sqrt(dx * dx + dy * dy)
			img.set_pixel(x, y, hover.linear_interpolate(base, 1.0 - clamp(d / dist, 0.0, 1.0)))
	img.unlock()
	var tex = ImageTexture.new()
	tex.create_from_image(img, 0)
	return tex

static func is_stockpile(building_name: String) -> bool:
	return building_name.begins_with("Stockpile")

const INFO = {
	"Workshop": {"category": "Maintenance", "description": "Builds other buildings; also required to build roads."},
	"Stockpile - Small": {"category": "Maintenance", "description": "Stores up to 100 units of a single resource."},
	"Stockpile - Medium": {"category": "Maintenance", "description": "Stores up to 300 units of a single resource."},
	"Stockpile - Large": {"category": "Maintenance", "description": "Stores up to 600 units of a single resource."},
	"Battery - Tier 1": {"category": "Maintenance", "description": "Stores 100 power, keeping the sector running through travel or overload."},
	"Battery - Tier 2": {"category": "Maintenance", "description": "Stores 300 power, keeping the sector running through travel or overload."},
	"Battery - Tier 3": {"category": "Maintenance", "description": "Stores 700 power, keeping the sector running through travel or overload."},
	"Fire Station": {"category": "Maintenance", "description": "Dispatches trucks to put out fires."},
	"Drone Bay": {"category": "Maintenance", "description": "Builds and stores drones; drones ferry resources between sectors."},
	"Docking Bay": {"category": "Space", "description": "Constructs mining, cargo and science ships; supports up to 3 ships."},
	"EVA Airlock": {"category": "Space", "description": "Repairs up to 48 hull per cycle for 4 Alloy; builds exterior structures."},
	"Probe Launcher": {"category": "Space", "description": "Builds probes to explore planetary systems for resources and anomalies."},
	"Colonization Training Center": {"category": "Space", "description": "Trains colonists in groups of 15 every 5 cycles, 1 Electronics each."},
	"Tech Lab": {"category": "Factories", "description": "Researches new buildings and upgrades using Science."},
	"Steel Mill": {"category": "Factories", "description": "Transforms 15 Iron into 15 Alloy per cycle."},
	"Electronics Factory": {"category": "Factories", "description": "Transforms 30 Silicon into 1 Electronics every 3 cycles."},
	"Polymer Refinery": {"category": "Factories", "description": "Transforms 5 Carbon into 5 Polymer per cycle."},
	"Fusion Station": {"category": "Factories", "description": "Transforms 15 Ice into 40 Water per cycle and stores it."},
	"Water Treatment Center": {"category": "Factories", "description": "Uses 50 Waste per cycle to fulfil all Water needs of the sector."},
	"Waste Treatment Center": {"category": "Factories", "description": "Transforms 50 Waste into Alloy, Polymer or Electronics."},
	"Nuclear Power Plant": {"category": "Factories", "description": "Transforms 3-8 Hydrogen into 75-200 Power per cycle. Without upgrades, consumes 20 Power to run regardless of Hydrogen consumption."},
	"Crew Quarters": {"category": "Population", "description": "Houses up to 15 crew in limited-quality accommodation."},
	"Optimized Quarter": {"category": "Population", "description": "Houses up to 40 crew in average-quality accommodation."},
	"Domotic Quarter": {"category": "Population", "description": "Houses up to 70 crew in high-quality accommodation."},
	"Cell Housing": {"category": "Population", "description": "Houses up to 125 crew in minimal-quality accommodation."},
	"Cryonics Center": {"category": "Population", "description": "Awakens humans stored in cryopods."},
	"Infirmary": {"category": "Population", "description": "Heals up to 15 injured crew simultaneously."},
	"Health Center": {"category": "Population", "description": "Heals up to 100 injured crew; serves sectors connected by train."},
	"Mess Hall": {"category": "Food", "description": "Serves food for up to 500 crew every 5 cycles."},
	"Insect Farm": {"category": "Food", "description": "Raises insects, converting them into 1 Food per cycle."},
	"Crop Farm": {"category": "Food", "description": "Creates and auto-harvests up to 9 Crop Fields."},
	"Crop Field": {"category": "Food", "description": "Transforms 1.5 Water into 1.2 Food per cycle."},
	"Algae Farm": {"category": "Food", "description": "Creates and auto-harvests up to 4 Algae Plantations."},
	"Algae Plantation": {"category": "Food", "description": "Transforms 4 Water into 4.7 Food per cycle."},
	"Mushroom Wall": {"category": "Food", "description": "Converts 6 Waste into 9 Food every 3 cycles."},
	"DLS Center": {"category": "Stability", "description": "Unlocks sector policies and tracks specializations."},
	"Alternative Life Center": {"category": "Stability", "description": "Provides +1 Stability in the sector."},
	"Memorial": {"category": "Stability", "description": "Provides +1 Stability in the sector."},
	"Legislative Strengthening Center": {"category": "Stability", "description": "Provides +2 Stability while the sector is below 0."},
	"Hull Temple": {"category": "Stability", "description": "Provides +1 Stability while the Cult of the Hull propagates."},
	"Observatory": {"category": "Stability", "description": "Provides +1 Stability; reduces Tiqqun max hull by 25."},
	"Exo-Fighting Dome": {"category": "Stability", "description": "Provides +2 Stability; extends to sectors connected by train."},
}

# Tile aliases: full words only; line breaks chosen for the 131px tiles.
const TILE_LABELS = {
	"Stockpile - Small": "Stockpile\nSmall",
	"Stockpile - Medium": "Stockpile\nMedium",
	"Stockpile - Large": "Stockpile\nLarge",
	"Battery - Tier 1": "Battery\nTier 1",
	"Battery - Tier 2": "Battery\nTier 2",
	"Battery - Tier 3": "Battery\nTier 3",
	"Probe Launcher": "Probe\nLauncher",
	"Colonization Training Center": "Colonization\nCenter",
	"Electronics Factory": "Electronics\nFactory",
	"Polymer Refinery": "Polymer\nRefinery",
	"Fusion Station": "Fusion\nStation",
	"Waste Treatment Center": "Waste\nTreatment",
	"Water Treatment Center": "Water\nTreatment",
	"Nuclear Power Plant": "Nuclear\nPower Plant",
	"Crew Quarters": "Crew\nQuarters",
	"Optimized Quarter": "Optimized\nQuarter",
	"Domotic Quarter": "Domotic\nQuarter",
	"Cell Housing": "Cell\nHousing",
	"Health Center": "Health\nCenter",
	"Cryonics Center": "Cryonics\nCenter",
	"Algae Plantation": "Algae\nPlantation",
	"Mushroom Wall": "Mushroom\nWall",
	"Alternative Life Center": "Alternative\nLife Center",
	"Legislative Strengthening Center": "Legislative\nCenter",
	"Exo-Fighting Dome": "Exo-Fighting\nDome",
}

static func tile_label(building_name: String) -> String:
	return TILE_LABELS.get(building_name, building_name)
