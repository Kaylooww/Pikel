extends RefCounted
class_name MatchScore
## Traditional side-out scoring for singles. Pure: it is told who won each rally and keeps
## the score, the server and the match result. It never looks at the ball or the scene.
##
## Only the server can score. When the receiver wins the rally it is a side-out: no point,
## and the receiver serves next. The server serves from their right court when their own
## score is even and from the left when it is odd.
## shortcut: singles only. Doubles needs first/second server and partner positions (RP-040).

enum Result { NONE, POINT, SIDE_OUT, MATCH_WON }

var points_to_win: int = 11
var win_by: int = 2
var point_cap: int = 0 ## if above 0, the first side to reach it wins whatever the margin
var scores: Dictionary = {1: 0, -1: 0} ## side -> points
var server_side: int = 1
var winner_side: int = 0 ## 0 until the match is won
var last_result: Result = Result.NONE
var last_rally_id: int = 0 ## highest rally already counted; a rally can never score twice

func _init(first_server: int = 1, target: int = 11, margin: int = 2, cap: int = 0) -> void:
    server_side = first_server
    points_to_win = target
    win_by = margin
    point_cap = cap

func is_over() -> bool:
    return winner_side != 0

func score_of(side: int) -> int:
    return int(scores[side])

func serve_from_right() -> bool:
    return score_of(server_side) % 2 == 0

## The score as called out loud: server's points first.
func score_call() -> String:
    return "%d-%d" % [score_of(server_side), score_of(-server_side)]

## Counts one finished rally. Returns what it did; NONE (and no change) if the match is
## already over, the rally was already counted, or `rally_winner` is not +1 or -1.
func record_rally(rally_id: int, rally_winner: int) -> Result:
    if is_over() or rally_id <= last_rally_id or absi(rally_winner) != 1:
        return Result.NONE
    last_rally_id = rally_id
    if rally_winner != server_side:
        server_side = rally_winner
        last_result = Result.SIDE_OUT
    else:
        scores[server_side] = score_of(server_side) + 1
        last_result = Result.POINT
        if _has_won(server_side):
            winner_side = server_side
            last_result = Result.MATCH_WON
    return last_result

func _has_won(side: int) -> bool:
    if point_cap > 0 and score_of(side) >= point_cap:
        return true
    return score_of(side) >= points_to_win and score_of(side) - score_of(-side) >= win_by
