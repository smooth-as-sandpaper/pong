`timescale 1ps / 1ps

`define PI 16'hC90F // = 3.1415, fixed point (2 bit integer, 14 bit fraction)

/*
 * Converts 32-bit integer degree value to fixed-point (2-bit integer, 30-bit fraction, two's complement) radian value.
 * Output is valid only if -90 <= deg <= 90. Thus, valid outputs are constrained within -pi/2 <= rad <= pi/2.
 * 	deg: 32-bit integer degree input
 *		rad: fixed-point radian output
 */
module deg_to_rad (deg, rad);

	input logic [31:0] deg;
	output logic [31:0] rad;
	
	logic [31:0] deg_abs;
	assign deg_abs = deg[31] ? -deg : deg;
	
	logic [63:0] deg_with_fraction;
	assign deg_with_fraction = { deg_abs[31:0], 32'd0 };
	
	logic [31:0] quotient;
	assign quotient = deg_with_fraction / 180;  // truncates to 32 bits (fractional part describes entire quotient since |deg| < 90)
	
	// PI:		 		2 integer bits, 14 fraction bits
	// quotient: 		0 integer bits, 32 fraction bits
	// PI * quotient: 2 integer bits, 46 fraction bits
	logic [47:0] product;
	assign product = quotient * `PI;
	
	// Convert into two's complement if angle is negative
	assign rad = deg[31] ? ~product[47:16] + 32'd1 : product[47:16];

endmodule  // deg_to_rad

module deg_to_rad_testbench();

	logic [31:0] deg, rad;
	
	deg_to_rad dut (.*);
	
	initial begin
		deg <= 0; #100;
		deg <= 90; #100;
		deg <= 15; #100;
		deg <= 30; #100;
		deg <= 45; #100;
		deg <= 83; #100;
		deg <= -90; #100;
		deg <= -15; #100;
		deg <= -30; #100;
		deg <= -45; #100;
		deg <= -83; #100;
		
		$stop;
	end

endmodule  // deg_to_rad_testbench