extends Node

const LINES = [

	{ "speaker": "baku", "text": "The sky’s clear, perfect for a run!" },
	{ "speaker": "baku", "text": "Whatever’s out there, I’m ready!" },
	{ "speaker": "baku", "text": "Let’s see what’s waiting this time, *evil laugh*" },
	{ "speaker": "baku", "text": "No time to think, just move!" },
	{ "speaker": "baku", "text": "Another run, let’s go!" },
	{ "speaker": "baku", "text": "I’ll figure it out on the way..." },
	{ "speaker": "baku", "text": "Something’s out there, I can feel it..." },
	{ "speaker": "baku", "text": "Doesn’t matter what it is, I’m going." },
	{ "speaker": "baku", "text": " *evil laugh* " },
	{ "speaker": "baku", "text": "TATAKAE!!!!" },
	{ "speaker": "baku", "text": "No hesitation, just forward!" },
	{ "speaker": "baku", "text": "Shinzou wo sasageyo!" },
	{ "speaker": "baku", "text": "This’ll be fun, I know it! *smirks*"},
	{ "speaker": "baku", "text": "Let’s make this quick *smirks*"},
	{ "speaker": "baku", "text": "I’m already moving!" },
	{ "speaker": "baku", "text": "Let’s see how far this goes." },
	{ "speaker": "baku", "text": "I don’t need a plan for this." },
	{ "speaker": "baku", "text": "As long as we’re together, we’ll make it." },

	
	{ "speaker": "yuna", "text": "Even now… the sky feels calm." },
	{ "speaker": "yuna", "text": "Let’s… try not to die..." },
	{ "speaker": "yuna", "text": "EEEEEEHHHH-!!!" },
	{ "speaker": "yuna", "text": "This doesn’t feel right…" },
	{ "speaker": "yuna", "text": "Stay focused. Don’t rush." },
	{ "speaker": "yuna", "text": "Something feels off…" },
	{ "speaker": "yuna", "text": "It’ll be fine… probably" },
	{ "speaker": "yuna", "text": "Just don’t make the same mistake again." },
	{ "speaker": "yuna", "text": "Let’s just be careful this time." },
	{ "speaker": "yuna", "text": "The silence feels different today." },
	{ "speaker": "yuna", "text": "It’s quiet… too quiet." },
	{ "speaker": "yuna", "text": "We’ve made it this far. Keep going." },
	{ "speaker": "yuna", "text": "Breathe. Focus." },
	{ "speaker": "yuna", "text": "There’s no rushing this." },
	{ "speaker": "yuna", "text": "Please tell me you have a plan this time..." },
	{ "speaker": "yuna", "text": "I’m right behind you." },
	{ "speaker": "yuna", "text": "Like always." },
	{ "speaker": "yuna", "text": "ASDFGHJKL-" },

	
]

func get_random_line():
	var pool = LINES.duplicate()
	pool.shuffle()
	return pool[0]
