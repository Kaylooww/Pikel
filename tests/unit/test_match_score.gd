extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_match_score.gd
## Side-out scoring, serve side and match end for singles (RP-024).
const R := MatchScore.Result
const HOME: int = 1
const AWAY: int = -1
var errors: Array[String] = []
var checks: int = 0
var rally: int = 0

func _initialize() -> void:
    var m := MatchScore.new(HOME)
    _assert(m.score_call() == "0-0" and m.server_side == HOME and m.serve_from_right() and not m.is_over(), "match starts 0-0, home serving from the right")

    # Server wins rallies: points, and the serve side alternates with the server's score.
    _assert(_win(m, HOME) == R.POINT and m.score_call() == "1-0" and m.server_side == HOME, "server winning the rally scores a point")
    _assert(not m.serve_from_right(), "odd score serves from the left")
    _assert(_win(m, HOME) == R.POINT and m.score_call() == "2-0" and m.serve_from_right(), "even score serves from the right again")

    # Receiver wins the rally: side-out, no point.
    _assert(_win(m, AWAY) == R.SIDE_OUT and m.server_side == AWAY, "receiver winning the rally is a side-out")
    _assert(m.score_of(HOME) == 2 and m.score_of(AWAY) == 0, "nobody scores on a side-out")
    _assert(m.score_call() == "0-2" and m.serve_from_right(), "the call puts the new server first, serving from the right at 0")
    _assert(_win(m, AWAY) == R.POINT and m.score_call() == "1-2" and not m.serve_from_right(), "the new server scores on their own serve")
    _assert(_win(m, HOME) == R.SIDE_OUT and m.score_call() == "2-1" and m.serve_from_right(), "serve comes back; side depends on the server's own score")

    # A rally can only be counted once.
    var before: String = m.score_call()
    _assert(m.record_rally(rally, HOME) == R.NONE and m.score_call() == before, "the same rally cannot score twice")
    _assert(m.record_rally(rally - 3, HOME) == R.NONE and m.score_call() == before, "an older rally is ignored")
    _assert(m.record_rally(rally + 50, 0) == R.NONE and m.last_rally_id == rally, "a rally with no winner is ignored")

    # Match end: 11 points, win by 2, and only on your own serve.
    m = MatchScore.new(HOME)
    for i in range(10):
        _win(m, HOME)
    _win(m, AWAY) # side-out at 10-0
    for i in range(10):
        _win(m, AWAY)
    _assert(m.score_call() == "10-10" and m.server_side == AWAY and not m.is_over(), "10-10 with away serving")
    _assert(_win(m, AWAY) == R.POINT and m.score_call() == "11-10" and not m.is_over(), "11-10 is not a win: must lead by two")
    _assert(_win(m, HOME) == R.SIDE_OUT and not m.is_over() and m.score_of(HOME) == 10, "the receiver cannot win the match on the other side's serve")
    _win(m, HOME) # 11-11
    _win(m, HOME) # 12-11
    _assert(not m.is_over() and m.score_call() == "12-11", "12-11 still not over")
    _assert(_win(m, HOME) == R.MATCH_WON and m.is_over() and m.winner_side == HOME and m.score_call() == "13-11", "13-11 wins the match")
    _assert(_win(m, AWAY) == R.NONE and _win(m, HOME) == R.NONE and m.score_call() == "13-11", "nothing changes after the match is won")
    _assert(m.last_result == R.MATCH_WON, "last result stays the match win")

    # Straight win and configuration.
    m = MatchScore.new(AWAY)
    for i in range(10):
        _win(m, AWAY)
    _assert(not m.is_over() and _win(m, AWAY) == R.MATCH_WON and m.winner_side == AWAY and m.score_call() == "11-0", "11-0 wins outright")
    m = MatchScore.new(HOME, 3, 1)
    _win(m, HOME)
    _win(m, HOME)
    _assert(_win(m, HOME) == R.MATCH_WON, "a short match to 3, win by 1, ends at 3-0")
    m = MatchScore.new(HOME, 11, 2, 12)
    for i in range(10):
        _win(m, HOME)
    _win(m, AWAY)
    for i in range(11):
        _win(m, AWAY)
    _assert(m.score_call() == "11-10" and not m.is_over(), "below the cap the margin still applies")
    _assert(_win(m, AWAY) == R.MATCH_WON and m.score_call() == "12-10", "reaching the point cap wins")
    m = MatchScore.new(HOME, 11, 2, 11)
    for i in range(10):
        _win(m, HOME)
    _win(m, AWAY)
    for i in range(10):
        _win(m, AWAY)
    _assert(_win(m, AWAY) == R.MATCH_WON and m.score_call() == "11-10", "with a cap of 11, 11-10 wins")

    if errors.is_empty():
        print("PASS: %d match score checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

## Records the next rally as won by `side`.
func _win(m: MatchScore, side: int) -> MatchScore.Result:
    rally += 1
    return m.record_rally(rally, side)

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
