class_name ChatMarkdown
extends RefCounted

# Minimal markdown for magic diary bubbles: *action* and **bold**.
# Bold uses brighter color — Godot [b] faux-bold blurs at small UI sizes.

const ACTION_BG_USER := "#FFFFFF44"
const ACTION_BG_ASSISTANT := "#FFFFFF33"
const BOLD_COLOR := "#FFFFFF"


static func to_bbcode(text: String, role: String = "assistant") -> String:
	if text.is_empty():
		return ""
	var bg := ACTION_BG_USER if role == "user" else ACTION_BG_ASSISTANT
	var parts: PackedStringArray = []
	var i := 0
	var n := text.length()
	while i < n:
		if i + 1 < n and text[i] == "*" and text[i + 1] == "*":
			var close_bold := text.find("**", i + 2)
			if close_bold != -1:
				var inner_bold := text.substr(i + 2, close_bold - i - 2)
				parts.append("[color=%s]%s[/color]" % [BOLD_COLOR, _escape_text(inner_bold)])
				i = close_bold + 2
				continue
		if text[i] == "*":
			var close_action := text.find("*", i + 1)
			if close_action != -1:
				var inner_action := text.substr(i + 1, close_action - i - 1)
				parts.append(
					"[i][bgcolor=%s]%s[/bgcolor][/i]" % [bg, _escape_text(inner_action)]
				)
				i = close_action + 1
				continue
		parts.append(_escape_char(text[i]))
		i += 1
	return "".join(parts)


static func _escape_text(s: String) -> String:
	return s.replace("[", "[lb]").replace("]", "[rb]")


static func _escape_char(ch: String) -> String:
	match ch:
		"[": return "[lb]"
		"]": return "[rb]"
		_: return ch
