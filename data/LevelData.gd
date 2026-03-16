extends Node

const LEVELS = [
	# EASY
	{ "title": "Totally Normal Tuesday", "difficulty": "easy", "line_baku": "Yuna come onnn there's one nearby!!", "line_yuna": "I just sat down...!!" },
	{ "title": "Not Our Problem (It Is)", "difficulty": "easy", "line_baku": "Spotted one!! You coming right?!!", "line_yuna": "Did you even wait for my answer—" },
	{ "title": "Fine. Whatever. Let's Go.", "difficulty": "easy", "line_baku": "Small one!! Easy bakyun!!", "line_yuna": "You said that last time..." },
	{ "title": "Brought Snacks Just In Case", "difficulty": "easy", "line_baku": "I packed snacks let's go!!", "line_yuna": "That's not a reason to—" },
	{ "title": "It's Probably Nothing", "difficulty": "easy", "line_baku": "Probably nothing!! Let's check!!", "line_yuna": "Probably...??" },
	{ "title": "Quick Errand", "difficulty": "easy", "line_baku": "Five minutes max I promise!!", "line_yuna": "It's never five minutes..." },
	{ "title": "We've Done Worse", "difficulty": "easy", "line_baku": "We've done worse!! Let's go!!", "line_yuna": "That's not reassuring...!" },
	{ "title": "Just A Walk", "difficulty": "easy", "line_baku": "Basically just a walk!!", "line_yuna": "To where the anomalies are??" },
	{ "title": "Warm Up Round", "difficulty": "easy", "line_baku": "Perfect warm up bakyun!!", "line_yuna": "My fingers aren't ready..." },
	{ "title": "Should Be Fine", "difficulty": "easy", "line_baku": "Should be fine come on!!", "line_yuna": "...should be??" },

	# MEDIUM
	{ "title": "The Incident With The Thing", "difficulty": "medium", "line_baku": "Okay so I found one. We going?!!", "line_yuna": "Found or caused—" },
	{ "title": "Something Something Wings", "difficulty": "medium", "line_baku": "Winged ones!! Let's go check!!", "line_yuna": "Check or fight??" },
	{ "title": "A Perfectly Reasonable Situation", "difficulty": "medium", "line_baku": "Reasonable mission!! You in?!!", "line_yuna": "Define reasonable..." },
	{ "title": "Chapter ???", "difficulty": "medium", "line_baku": "Fingers ready?? Let's go!!", "line_yuna": "W-wait I'm still eating—" },
	{ "title": "Untitled Anomaly Zone", "difficulty": "medium", "line_baku": "New zone!! Coming?!!", "line_yuna": "Since when is it new—" },
	{ "title": "Getting Interesting", "difficulty": "medium", "line_baku": "This one looks interesting!!", "line_yuna": "Interesting is dangerous..." },
	{ "title": "More Than Expected", "difficulty": "medium", "line_baku": "More than usual but we got it!!", "line_yuna": "More than usual...??" },
	{ "title": "Classified (By Me)", "difficulty": "medium", "line_baku": "I scouted it already!! Trust me!!", "line_yuna": "That's what worries me..." },
	{ "title": "Noted. Moving On.", "difficulty": "medium", "line_baku": "Spotted two of them!! In?!!", "line_yuna": "Two...?? At once??" },
	{ "title": "Mid Actually", "difficulty": "medium", "line_baku": "Not too bad!! You'll be fine!!", "line_yuna": "You'll be fine is not a plan..." },

	# HARD
	{ "title": "We Were Never Here", "difficulty": "hard", "line_baku": "Big one!! Don't panic!! Let's go!!", "line_yuna": "DON'T PANIC??" },
	{ "title": "Do Not Google What We Saw", "difficulty": "hard", "line_baku": "Yuna. You ready. Let's go. Now.", "line_yuna": "W-why are you typing like that—" },
	{ "title": "Named Later", "difficulty": "hard", "line_baku": "Survive this and drinks on me!!", "line_yuna": "WHY SURVIVE—" },
	{ "title": "That's A Lot Of Wings", "difficulty": "hard", "line_baku": "Okay there's a lot. Still going!!", "line_yuna": "A LOT?? HOW MANY IS A LOT—" },
	{ "title": "Unconfirmed. Unhinged.", "difficulty": "hard", "line_baku": "Intel's a bit unclear but—!!", "line_yuna": "A BIT???......" },
	{ "title": "Big One Today", "difficulty": "hard", "line_baku": "Big one today. You and me!!", "line_yuna": "Please define big..." },
	{ "title": "Do Not Look Up", "difficulty": "hard", "line_baku": "Meet me there!! Don't look up!!", "line_yuna": "Why would I— oh no." },
	{ "title": "Honestly Impressive", "difficulty": "hard", "line_baku": "This one's huge!! So cool right?!!", "line_yuna": "THAT IS NOT COOL BAKU—" },
	{ "title": "We Are So Normal", "difficulty": "hard", "line_baku": "Normal day!! Totally fine!! Go!!", "line_yuna": "IT IS NOT FINE—" },
	{ "title": "No Notes", "difficulty": "hard", "line_baku": "No plan just bakyun!! Let's GO!!", "line_yuna": "No plan...?? BAKU—" },
]

func get_random_level(difficulty: String) -> Dictionary:
	var pool = LEVELS.filter(func(l): return l.difficulty == difficulty)
	pool.shuffle()
	return pool[0]
