extends Node
## Game registry, player setup, high scores.

const SAVE_PATH := "user://scores.json"

const ENTRIES: Array[Dictionary] = [
	{"id": "courtrally", "name": "Court Rally", "cat": "Classic Five", "color": Color("4fb06d"),
		"blurb": "Racket duel on a grass court.",
		"controls": "Swing like a forehand or backhand as the ball reaches you.\nSwing direction aims the shot. Swing early or late to pull wide."},
	{"id": "slugger", "name": "Slugger", "cat": "Classic Five", "color": Color("d98b3a"),
		"blurb": "Hit pitches out of the park.",
		"controls": "Swing level as the pitch crosses the plate.\nTiming picks the angle. Swing up or down to change the launch."},
	{"id": "pinroll", "name": "Pin Roll", "cat": "Classic Five", "color": Color("4f7fd9"),
		"blurb": "Ten frames of rolling thunder.",
		"controls": "Tilt the phone to slide and aim.\nSwing forward, underhand, to release. Twist your wrist for hook."},
	{"id": "fairway", "name": "Fairway", "cat": "Classic Five", "color": Color("6bbf59"),
		"blurb": "Three holes, one windy meadow.",
		"controls": "Point to aim the shot.\nSwing like a golf club. Bigger swing, longer shot. Hold B on the green for a soft putt."},
	{"id": "sparring", "name": "Sparring", "cat": "Classic Five", "color": Color("d9534f"),
		"blurb": "Gloves up, three rounds.",
		"controls": "Swing left or right to throw hooks, forward for a jab.\nHold B to guard. Dodge by tilting."},
	{"id": "bowrange", "name": "Bow Range", "cat": "Holiday Sports", "color": Color("c9a227"),
		"blurb": "Draw, aim, release.",
		"controls": "Point at the target. Hold A to draw the bow, release A to loose.\nWatch the wind flag."},
	{"id": "disctoss", "name": "Disc Toss", "cat": "Holiday Sports", "color": Color("9b59b6"),
		"blurb": "Curve the disc into the ring.",
		"controls": "Aim, then flick sideways. Tilt your wrist at release to bend the flight."},
	{"id": "foilduel", "name": "Foil Duel", "cat": "Holiday Sports", "color": Color("5bc0de"),
		"blurb": "Parry, riposte, first to five.",
		"controls": "Point high, middle or low to block where the opponent attacks.\nSwing into the gap after a parry."},
	{"id": "hoops", "name": "Hoops", "cat": "Holiday Sports", "color": Color("e67e22"),
		"blurb": "Sixty seconds of free throws.",
		"controls": "Point at the rim.\nSwing upward with a smooth lift. Power sets distance."},
	{"id": "paddlerally", "name": "Paddle Rally", "cat": "Holiday Sports", "color": Color("e84393"),
		"blurb": "Fast table duel to eleven.",
		"controls": "Swing across the table as the ball bounces to you.\nSwing direction places the return."},
]

const EGG_PATH := "user://egg.json"
const EGG_COLORS := ["fff4e0", "f6d6a8", "d9a066", "ffb3c7", "a8d8ff", "b8f0b0", "e1b8ff", "ffe066"]
const EGG_PATTERNS := ["Plain", "Spots", "Stripes"]
const EGG_HATS := ["None", "Cap", "Crown", "Bow", "Chef hat", "Party hat"]
const EGG_FACES := ["Smile", "Grin", "Shades", "Oh!"]

## The player's customisable egg.
var egg := {"color": 0, "pattern": 0, "hat": 0, "face": 0, "name": "Eggbert"}
var main: Node
var players := 1
var _scores := {}


func _ready() -> void:
	_load()
	_load_egg()


func entry(id: String) -> Dictionary:
	for e in ENTRIES:
		if e["id"] == id:
			return e
	return {}


func best(id: String) -> float:
	return _scores.get(id, -1.0)


## Returns true when `score` sets a new record.
func submit(id: String, score: float, higher_better: bool = true) -> bool:
	var old: float = _scores.get(id, -1.0)
	var better := old < 0.0 or (score > old if higher_better else score < old)
	if better:
		_scores[id] = score
		_save()
	return better


func _load() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			_scores = parsed


func _load_egg() -> void:
	if FileAccess.file_exists(EGG_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EGG_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			for k in egg:
				if parsed.has(k):
					egg[k] = parsed[k]


func save_egg() -> void:
	var f := FileAccess.open(EGG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(egg))


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_scores))
