extends Resource
class_name GameplayTuning
## Every gameplay feel number in one place. Edit config/gameplay_tuning.tres in the
## inspector (or assign a different GameplayTuning to a node's `tuning` property) to retune;
## the scripts that read these values do not need to change.
## Court sizes are NOT tuning: they live in CourtDimensions.

@export_group("Ball")
@export var gravity: float = 9.81
@export var drive_speed: float = 12.0 ## horizontal m/s used to pick a drive's flight time
@export var dink_speed: float = 8.0
@export var min_flight_time: float = 0.58
@export var max_flight_time: float = 1.15 ## longest (highest) arc the solver may use to clear the net
@export var max_launch_speed: float = 25.0 ## shots needing more than this are refused
@export_range(0.0, 1.0) var bounce_restitution: float = 0.68 ## vertical speed kept after a bounce
@export_range(0.0, 1.0) var bounce_friction: float = 0.85 ## horizontal speed kept after a bounce

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

@export_group("Training")
@export var fault_reset_delay: float = 1.1 ## seconds between a fault and the next practice ball
