extends RefCounted
class_name NetConfig
## Settings for the server and online-match scenes. The main menu sets them before changing
## scene; a command-line launch sets them with arguments after a `--` separator, for example
## `--port=7777 --points=11 --bot` for the server scene or `--join=192.168.1.20:7777` for the
## online match scene. tools/run_server and tools/lan_smoke_test show complete commands.
##
## Never put passwords, tokens or keys here: there are none in this LAN prototype.

static var host: String = "127.0.0.1"
static var port: int = NetProtocol.DEFAULT_PORT
static var points_to_win: int = 11
static var win_by: int = 2
static var fill_with_bot: bool = false ## server: start with one human and a bot
static var autoplay: bool = false ## client: a bot plays (demos and automated tests)
static var exit_on_match_end: bool = false ## quit the process when the match is over (automated tests)
static var bot_seed: int = 1

static func read_command_line() -> void:
    for argument: String in OS.get_cmdline_user_args():
        var parts: PackedStringArray = argument.split("=", true, 1)
        var value: String = parts[1] if parts.size() > 1 else ""
        match parts[0]:
            "--join": set_address(value)
            "--port": port = _port_or(value, port)
            "--points": points_to_win = maxi(1, value.to_int())
            "--win-by": win_by = maxi(1, value.to_int())
            "--seed": bot_seed = value.to_int()
            "--bot": fill_with_bot = true
            "--autoplay": autoplay = true
            "--exit-on-match-end": exit_on_match_end = true

## Accepts "host" or "host:port". Returns false, changing nothing, if the port is not a valid port.
static func set_address(address: String) -> bool:
    var text: String = address.strip_edges()
    var colon: int = text.rfind(":")
    var new_host: String = text if colon < 0 else text.substr(0, colon)
    var new_port: int = port if colon < 0 else _port_or(text.substr(colon + 1), -1)
    if new_host == "" or new_port < 0:
        return false
    host = new_host
    port = new_port
    return true

static func _port_or(text: String, fallback: int) -> int:
    return text.to_int() if text.is_valid_int() and text.to_int() >= 1 and text.to_int() <= 65535 else fallback
