class_name VortexGrappleSphere
extends Area3D

## Runtime marker type for the colored spheres in the grapple intercept.
## The color lives on the physics node so ray hits can be identified and
## resolved without relying on a collision-layer bit or a parallel lookup.
var is_yellow := false
