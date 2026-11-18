extends Resource
class_name GameplayTuning
## Every gameplay feel number in one place. Edit config/gameplay_tuning.tres in the
## inspector (or assign a different GameplayTuning to a node's `tuning` property) to retune;
## the scripts that read these values do not need to change.
## Court sizes are NOT tuning: they live in CourtDimensions.

@export_group("Ball flight")
@export var gravity: float = 12.0 ## above real 9.81 on purpose: snappy arcade arcs like the Just Volleyball reference (high but quick)
@export var air_drag: float = 0.45 ## per second; velocity lost to the air is air_drag * velocity (linear drag)
@export var spin_lift: float = 0.15 ## m/s² of vertical push per rev/s of spin: topspin pushes down, backspin holds up
@export var min_flight_time: float = 0.58 ## shortest flight a soft shot (dink, block) may use
@export var max_flight_time: float = 1.15 ## longest arc a dink, block or drive may use to clear the net
@export var max_launch_speed: float = 32.0 ## shots needing more than this are refused

@export_group("Bounce")
@export_range(0.0, 1.0) var bounce_restitution: float = 0.68 ## vertical speed kept after a bounce
@export_range(0.0, 1.0) var bounce_friction: float = 0.85 ## horizontal speed kept after a bounce, before spin
@export var bounce_spin_kick: float = 0.04 ## m/s of horizontal speed per rev/s of spin at the bounce: topspin skids on, backspin checks up
@export var bounce_spin_height: float = 0.004 ## per rev/s: topspin bounces lower, backspin a little higher
@export_range(0.0, 1.0) var bounce_spin_keep: float = 0.4 ## share of spin the ball keeps after a bounce

@export_group("Dink (left tap)")
@export var dink_flight_time: float = 1.15 ## seconds in the air whatever the distance: a soft arc about 2 m up
@export var dink_max_flight_time: float = 1.45 ## longest arc it may raise to, to clear the net
@export var dink_spin: float = -10.0 ## rev/s; negative is backspin, so the dink floats and sits up
@export var volley_dink_speed: float = 9.0 ## a dink tapped on a ball that has not bounced is a punched volley
@export var volley_dink_spin: float = -6.0

@export_group("Drive (left hold)")
@export var drive_min_speed: float = 13.0 ## horizontal m/s at the shortest hold
@export var drive_max_speed: float = 26.0 ## horizontal m/s at a full charge
@export var drive_min_spin: float = 12.0 ## rev/s of topspin at the shortest hold
@export var drive_max_spin: float = 30.0 ## rev/s of topspin at a full charge, so hard drives dip
@export var drive_min_flight_time: float = 0.25 ## a full-power drive may be this quick
@export var drive_max_flight_time: float = 0.9 ## a drive never floats longer than this; past it the shot is refused

@export_group("Block (right tap)")
@export var block_speed: float = 6.0 ## horizontal m/s: a block soaks up the pace and drops short
@export var block_spin: float = -8.0
@export var block_max_depth: float = 3.6 ## metres past the net a block can reach, whatever the aim
@export var block_max_flight_time: float = 0.95 ## keeps the block low and flat, under a dink's arc

@export_group("Lob (right hold)")
@export var lob_min_flight_time: float = 1.6 ## flight time (so height) at the shortest hold: about 4 m up
@export var lob_max_flight_time: float = 2.3 ## at a full charge: about 7.5 m up, a Just Volleyball-style set
@export var lob_extra_depth: float = 1.6 ## metres a full-charge lob carries past the aim point, kept inside the baseline
@export var lob_spin: float = 6.0 ## light topspin

@export_group("Hit input")
@export var tap_threshold: float = 0.15 ## seconds; a mouse press shorter than this is a tap (dink, block), longer is a hold (drive, lob)
@export var full_charge_time: float = 0.9 ## seconds of holding until a drive or lob is at full power
@export var side_key_window: float = 0.25 ## seconds before the mouse press that a Q or E press still counts for the swing

@export_group("Forehand and backhand")
@export var body_deadzone: float = 0.2 ## metres either side of the body where forehand and backhand both work
@export_range(0.0, 1.0) var wrong_side_power: float = 0.5 ## pace kept by a swing on the wrong side
@export var wrong_side_error: float = 1.1 ## metres a wrong-side swing drifts (short and across)
@export_range(0.0, 1.0) var no_side_power: float = 0.75 ## pace kept when neither Q nor E was pressed
@export var no_side_error: float = 0.6 ## metres a swing with no side picked drifts

@export_group("Player")
@export var move_speed: float = 5.4
@export var sprint_speed: float = 7.2
@export var max_side_distance: float = 3.65 ## how far from the court center line a player may run
@export var min_net_distance: float = 0.35
@export var max_back_distance: float = 7.35 ## how far behind the net a player may run

@export_group("Contact")
@export var player_reach: float = 2.05 ## max distance from the player's contact point to the ball
@export var player_contact_height: float = 0.95
@export var clean_reach: float = 1.2 ## within this distance the swing is comfortable; beyond it, stretched
@export var max_reach_error: float = 1.0 ## metres a fully stretched shot falls short
@export var contact_lead: float = 0.4 ## how far in front of the body the ideal contact is
@export var clean_timing_window: float = 0.08 ## seconds either side of ideal contact that count as clean
@export var max_timing_window: float = 0.30 ## seconds off at which the timing error stops growing
@export var max_timing_error: float = 1.2 ## metres a badly timed shot drifts sideways
@export var bot_reach: float = 2.25
@export var bot_contact_height: float = 1.0

@export_group("Volleys")
@export var volley_dink_window: float = 0.10 ## seconds either side of ideal contact a volley dink must be pressed in, or it is missed
@export var volley_block_window: float = 0.20 ## a block is the forgiving volley
@export var volley_drive_window: float = 0.14 ## drives and lobs hit out of the air
@export var whiff_recovery: float = 0.4 ## seconds a player cannot swing again after missing a volley

@export_group("Rules")
@export var momentum_window: float = 0.6 ## seconds after a volley in which stepping into the kitchen is a fault

@export_group("Training")
@export var fault_reset_delay: float = 1.1 ## seconds between a fault and the next practice ball
