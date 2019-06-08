/*
 *  Parametric 3D printed vent adapter for regular computer fan.
 *  Copyright (C) 2019  Ivan Mironov <mironov.ivan@gmail.com>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

use <MCAD/nuts_and_bolts.scad>

WIDTH = 80.0;  // mm
SCREW_HOLE_DIST = 71.5;  // mm
SCREW = 4;
PLATE_THICKNESS = 4.0;  // mm
FAN_DIAM = 77.0;  // mm

ROUNDING_DIAM = WIDTH - SCREW_HOLE_DIST;

NET_HEIGHT = 0.6;  // mm
NET_HOLE_WIDTH = 3.0;  // mm
NET_HOLE_SPACING = 0.6;  // mm

PIPE_ADAPTER_HEIGHT = 20.0;  // mm
PIPE_BOTTOM_FITTING_HEIGHT = 20.0;  // mm
PIPE_TOP_FITTING_HEIGHT = 50.0;  // mm

PIPE_DIAM = 75.0;  // outer, mm
PIPE_WALL_THICKNESS = 3.0;  // mm

NUT_PLACE_HEIGHT = 3.0;  // mm
NUT_PLACE_DIAM = 12.0;  // mm

TOLERANCE = 0.1;  // mm

// Overlap, used for geometry subtraction.
OS = 1.0;  // mm
// Overlap, used for geometry addition.
OA = 0.01;  // mm


// Width is over the "x" axis.
module hex(width)
{
	circle(d=width, $fn=6);
}

// Depth is over the "y" axis.
function hex_depth(width) = sqrt(3.0) / 2.0 * width;

// Sum of 2D cubic coordinates.
function hex_cc_sum(a, b) = [a[0] + b[0], a[1] + b[1], a[2] + b[2]];

// All possible directions from "zero" hexagon in cubic 2D coordinates.
function hex_cc_direction(direction) = [
	[+1, -1,  0],
	[+1,  0, -1],
	[ 0, +1, -1],
	[-1, +1,  0],
	[-1,  0, +1],
	[ 0, -1, +1],
][direction];

// Neighbor of given hexagon in cubic 2D coordinates.
function hex_cc_neighbor(cc, direction) = hex_cc_sum(cc, hex_cc_direction(direction));

// Convert cubic 2D coordinates to [col, row] (even-col is without offset over "y" axis).
function hex_cc_to_off(cc) = [cc[0], cc[2] + (cc[0] - cc[0] % 2) / 2.0];

// Convert [col, row] (even-col) to normal [x, y] 2D coordinates.
function hex_off_to_xy(off, width) = [
	off[0] * width * 3.0 / 4.0,
	off[1] * hex_depth(width) + off[0] % 2 * hex_depth(width) / 2.0,
];

// Convert cubic 2D coordinates to normal [x, y] 2D coordinates.
function hex_cc_to_xy(cc, width) = hex_off_to_xy(hex_cc_to_off(cc), width);

function hex_cc_ring_tail(cur_ring, cur_direction_mul_radius, radius) =
	cur_direction_mul_radius < 6 * radius - 1 ?
		hex_cc_ring_tail(
			concat(
				[hex_cc_neighbor(
					cur_ring[0],
					floor(cur_direction_mul_radius / radius))],
				cur_ring),
			cur_direction_mul_radius + 1,
			radius) :
		cur_ring;

function hex_cc_ring(center_cc, radius) = hex_cc_ring_tail(
	[hex_cc_direction(4) * radius],
	0,
	radius);

function hex_cc_spiral_tail(cur_spiral, radius) =
	radius > 0 ?
		hex_cc_spiral_tail(
			concat(
				cur_spiral,
				hex_cc_ring(cur_spiral[0], radius)),
			radius - 1) :
		cur_spiral;
		
function hex_cc_spiral(center_cc, radius) = hex_cc_spiral_tail([center_cc], radius);

// TODO: Verify. Not sure about radius calculation.
function hex_circle(width, radius) = [
	for (i = hex_cc_spiral([0, 0, 0], ceil(radius / (width * 1.5) * 2)))
		let (xy = hex_cc_to_xy(i, width))
			if (norm(xy) < radius - width / 2.0) xy
];

function screw_hole_coords() = let(half_off = SCREW_HOLE_DIST / 2.0) [
	for (x_off = [-1.0, 1.0], y_off = [-1.0, 1.0])
		[x_off * half_off, y_off * half_off, 0.0]
];

module mounting_plate_2d()
{
	half_off = SCREW_HOLE_DIST / 2.0;
	full_hex_width = NET_HOLE_WIDTH + NET_HOLE_SPACING;
	
	difference() {
		hull() {
			for (i = screw_hole_coords()) {
				translate(i)
					circle(d=ROUNDING_DIAM, $fn=64);
			}
		}
		
		// Holes for airflow.
		for (xy = hex_circle(full_hex_width, FAN_DIAM / 2.0)) {
			translate([xy.x, xy.y])
				hex(NET_HOLE_WIDTH);
		}
	
		// Holes for screws.
		for (x_off = [-1.0, 1.0]) {
			for (y_off = [-1.0, 1.0]) {
				translate([x_off * half_off, y_off * half_off, 0.0])
					boltHole(size=SCREW, tolerance=TOLERANCE, proj=1, $fn=64);
			}
		}
	}
}

module pipe_adapter(is_top_part)
{
	fan_wall_thickness = (WIDTH - FAN_DIAM) / 2.0;
	bottom_outer_r = WIDTH / 2.0;
	bottom_inner_r = bottom_outer_r - fan_wall_thickness;
	top_outer_r = is_top_part ?
		PIPE_DIAM / 2.0 :
		PIPE_DIAM / 2.0 + PIPE_WALL_THICKNESS;
	top_inner_r = is_top_part ?
		PIPE_DIAM / 2.0 - PIPE_WALL_THICKNESS :
		PIPE_DIAM / 2.0;
	top_inner_detent = is_top_part ?
		0.0 :
		PIPE_WALL_THICKNESS;
	top_inner_tolerance = is_top_part ?
		0.0 :
		TOLERANCE;
	fitting_height = is_top_part ?
		PIPE_TOP_FITTING_HEIGHT :
		PIPE_BOTTOM_FITTING_HEIGHT;
	
	difference() {
		union() {
			cylinder(
				h=PIPE_ADAPTER_HEIGHT,
				r1=bottom_outer_r,
				r2=top_outer_r,
				$fn=128);
			translate([0.0, 0.0, PIPE_ADAPTER_HEIGHT - OA])
				cylinder(
					h=fitting_height + OA,
					r=top_outer_r,
					$fn=128);
		}
		
		translate([0.0, 0.0, -OS])
			cylinder(
				h=PIPE_ADAPTER_HEIGHT + OS,
				r1=bottom_inner_r,
				r2=top_inner_r - top_inner_detent,
				$fn=128);
		
		translate([0.0, 0.0, PIPE_ADAPTER_HEIGHT - OA])
			cylinder(
				h=fitting_height + OA + OS,
				r=top_inner_r + top_inner_tolerance,
				$fn=128);
	}
}

module nut_places()
{
	for (i = screw_hole_coords()) {
		translate(i) {
			difference() {
				linear_extrude(height=PLATE_THICKNESS + NUT_PLACE_HEIGHT)
					circle(
						d=NUT_PLACE_DIAM,
						$fn=64);

				translate([0.0, 0.0, PLATE_THICKNESS - OA])
					linear_extrude(height=NUT_PLACE_HEIGHT + OS + OA)
						nutHole(
							size=SCREW,
							tolerance=TOLERANCE,
							proj=1);
				translate([0.0, 0.0, -OS])
					linear_extrude(height=PLATE_THICKNESS + OS * 2.0)
						scale([1.0 + OA, 1.0 + OA, 1.0])
							boltHole(
								size=SCREW,
								tolerance=TOLERANCE,
								proj=1,
								$fn=64);
			}
		}
	}
}
			
module fan_mount(is_top_part)
{
	difference() {
		linear_extrude(height=PLATE_THICKNESS)
			mounting_plate_2d();
		translate([0.0, 0.0, NET_HEIGHT])
			cylinder(
				h=PLATE_THICKNESS - NET_HEIGHT + OS,
				d=FAN_DIAM,
				$fn=128);
	}

	translate([0.0, 0.0, PLATE_THICKNESS - OA])
		pipe_adapter(is_top_part);
	
	// Places for nuts.
	if (!is_top_part) {
		nut_places();
	}
}

translate([-WIDTH / 2.0 - 10.0, 0.0, 0.0])
	fan_mount(true);
translate([WIDTH / 2.0 + 10.0, 0.0, 0.0])
	fan_mount(false);
