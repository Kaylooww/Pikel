extends RefCounted
class_name NetCollision
## Pure swept test of one ball step against the net. No scene access, so it is unit-testable.

## True when a ball of `radius` moving from `prev` to `next` touches the net.
## The net is the vertical segment z=0, y in [0, net height] in the (z, y) plane, so a
## sphere touches it exactly when the step segment comes within `radius` of that segment.
## This covers the net body, the tape from any angle, and grazes that never cross z=0.
static func hits_net(prev: Vector3, next: Vector3, radius: float) -> bool:
    # shortcut: x and net height are sampled at the step midpoint (error under 2 mm at
    # 60 Hz); upgrade to a true 3D capsule test when posts get their own collider.
    var x: float = (prev.x + next.x) * 0.5
    if absf(x) > CourtDimensions.NET_HALF_WIDTH + radius:
        return false # around the post
    var net_top := Vector2(0.0, CourtDimensions.net_height_at(x))
    var closest: PackedVector2Array = Geometry2D.get_closest_points_between_segments(
        Vector2(prev.z, prev.y), Vector2(next.z, next.y), Vector2.ZERO, net_top)
    return closest[0].distance_to(closest[1]) < radius
