extends RefCounted
class_name ShotRecipe
## How one shot type flies: its pace, spin, the flight times the solver may use and where it
## is allowed to land. Pure: built from the shot type, the charge and the tuning.
##
##   DINK  (left tap)   a slow, high, floaty arc with backspin, the same hang time from anywhere.
##                      Tapped on a ball in the air it is a punched volley instead.
##   DRIVE (left hold)  fast and flat; pace and topspin grow with the charge, so hard drives dip.
##   BLOCK (right tap)  soaks up the pace: slow, flat-ish, backspin, and it always lands short.
##   LOB   (right hold) height and depth grow with the charge.

enum Kind { NONE, DRIVE, DINK, BLOCK, LOB } ## same numbers as PlayerInput.Swing

var kind: Kind = Kind.DRIVE
var speed: float = 12.0 ## horizontal m/s the shot prefers; sets the flight time from the distance
var flight_time: float = 0.0 ## when above zero, the flight time the shot prefers instead of `speed`
var min_flight_time: float = 0.58
var max_flight_time: float = 1.15
var spin: float = 0.0 ## rev/s, positive is topspin
var max_depth: float = INF ## metres past the net the shot may land
var extra_depth: float = 0.0 ## metres the shot carries past the aim point

## `charge` is 0..1 and only matters for drives and lobs. `volley` is true when the ball is
## hit out of the air.
static func make(shot: Kind, charge: float, volley: bool, tuning: GameplayTuning) -> ShotRecipe:
    var recipe := ShotRecipe.new()
    var c: float = clampf(charge, 0.0, 1.0)
    recipe.kind = shot
    recipe.min_flight_time = tuning.min_flight_time
    recipe.max_flight_time = tuning.max_flight_time
    match shot:
        Kind.DRIVE:
            recipe.speed = lerpf(tuning.drive_min_speed, tuning.drive_max_speed, c)
            recipe.spin = lerpf(tuning.drive_min_spin, tuning.drive_max_spin, c)
            recipe.min_flight_time = tuning.drive_min_flight_time
            recipe.max_flight_time = tuning.drive_max_flight_time
        Kind.BLOCK:
            recipe.speed = tuning.block_speed
            recipe.spin = tuning.block_spin
            recipe.max_depth = tuning.block_max_depth
            recipe.max_flight_time = tuning.block_max_flight_time
            recipe.min_flight_time = tuning.drive_min_flight_time # flat: it may be quicker than a dink
        Kind.LOB:
            recipe.flight_time = lerpf(tuning.lob_min_flight_time, tuning.lob_max_flight_time, c)
            recipe.min_flight_time = tuning.lob_min_flight_time
            recipe.max_flight_time = tuning.lob_max_flight_time * 1.3
            recipe.spin = tuning.lob_spin
            recipe.extra_depth = tuning.lob_extra_depth * c
        _:
            if volley:
                recipe.speed = tuning.volley_dink_speed
                recipe.spin = tuning.volley_dink_spin
                recipe.min_flight_time = tuning.drive_min_flight_time
            else:
                recipe.flight_time = tuning.dink_flight_time
                recipe.min_flight_time = tuning.dink_flight_time
                recipe.max_flight_time = tuning.dink_max_flight_time
                recipe.spin = tuning.dink_spin
            recipe.kind = Kind.DINK
    return recipe

## A weaker version of this shot (a wrong-side or no-side swing). `keep` is 0..1.
func weakened(keep: float) -> ShotRecipe:
    var copy: ShotRecipe = duplicate_recipe()
    var k: float = clampf(keep, 0.05, 1.0)
    copy.speed *= k
    copy.spin *= k
    if copy.flight_time > 0.0:
        copy.flight_time = lerpf(copy.min_flight_time * 0.85, copy.flight_time, k)
        copy.min_flight_time = minf(copy.min_flight_time, copy.flight_time)
    else:
        copy.max_flight_time = maxf(copy.max_flight_time, copy.min_flight_time / k)
    copy.extra_depth *= k
    return copy

func duplicate_recipe() -> ShotRecipe:
    var copy := ShotRecipe.new()
    copy.kind = kind
    copy.speed = speed
    copy.flight_time = flight_time
    copy.min_flight_time = min_flight_time
    copy.max_flight_time = max_flight_time
    copy.spin = spin
    copy.max_depth = max_depth
    copy.extra_depth = extra_depth
    return copy

## Where this shot really lands for an aim point: blocks are pulled short, lobs carry deeper.
## Both stay inside the court, so the shape never turns a good aim into an out ball.
func shape_target(aim: Vector3) -> Vector3:
    var target: Vector3 = aim
    var depth: float = absf(target.z)
    var sign_z: float = signf(target.z) if target.z != 0.0 else -1.0
    if extra_depth > 0.0:
        depth = maxf(depth, minf(depth + extra_depth, CourtDimensions.HALF_LENGTH - LOB_BASELINE_MARGIN))
    depth = minf(depth, max_depth)
    target.z = sign_z * depth
    return target

const LOB_BASELINE_MARGIN: float = 0.15

static func kind_name(shot: Kind) -> String:
    match shot:
        Kind.DRIVE: return "DRIVE"
        Kind.DINK: return "DINK"
        Kind.BLOCK: return "BLOCK"
        Kind.LOB: return "LOB"
        _: return ""
