`timescale 1ps / 1ps

/*
 * Determines the location of the ball on the screen given its speed and information about either paddle making contact with it.
 *		clk: The clock used in determination of the ball's location
 *		CLOCK_50: The clock used in calculation of cosine and sine
 *		reset: When high, moves the ball to its starting position
 *		start: When high, initiates ball movement
 *		x_min: The minimum x-value of the ball
 * 	y_min: The minimum y-value of the ball
 *		paddle1_hit: True when paddle 1 is making contact with the ball
 * 	paddle2_hit: True when paddle 2 is making contact with the ball
 *		hit_intersect: Indicates the y-intercept of the ball relative to the paddle's center when the ball hits
 *							either paddle. Valid only when paddle1_hit or paddle2_hit is true.
 *		boundary_hit: True when the ball hits either the top or bottom boundary of the screen.
 */
module ball #(parameter BALL_LEN = 15, MAX_BOUNCE_ANGLE = 75, BALL_SPEED = 2, PADDLE_HEIGHT = 70, SCREEN_WIDTH = 640, SCREEN_HEIGHT = 480)
		(clk, CLOCK_50, reset, start, x_min, y_min, paddle1_hit, paddle2_hit, hit_intersect, boundary_hit);

	input  logic clk, CLOCK_50, reset, start, paddle1_hit, paddle2_hit;
	input  logic signed [9:0] hit_intersect;

	// (x_min, y_min) is the coordinate pair locating the top-left corner of the ball (note: ball is square)
	output logic [9:0] x_min;
	output logic [8:0] y_min;

	// Ball hit top or bottom of screen
	logic top_boundary_hit, bottom_boundary_hit;
	output logic boundary_hit;
	
	// Must account for wrap-around when y_min passes through 0
	assign top_boundary_hit = (y_min == 0) || (y_min >= 2**9 - BALL_SPEED);
	assign bottom_boundary_hit = (y_min + BALL_LEN >= SCREEN_HEIGHT) && (y_min + BALL_LEN < 2**9 - BALL_SPEED);
	assign boundary_hit = top_boundary_hit || bottom_boundary_hit;

	logic [31:0] sin_out, cos_out;
	logic [31:0] last_cos_out, last_sin_out;
	logic [31:0] paddle_bounce_angle_deg;
	logic [31:0] paddle_bounce_angle_rad, boundary_bounce_angle_deg, boundary_bounce_angle_rad;

	logic [9:0] hit_intersect_abs;
	assign hit_intersect_abs = hit_intersect[9] ? ~hit_intersect + 10'd1 : hit_intersect;
	assign paddle_bounce_angle_deg = (hit_intersect_abs * MAX_BOUNCE_ANGLE) / (PADDLE_HEIGHT / 2);
	deg_to_rad d2r (.deg(paddle_bounce_angle_deg), .rad(paddle_bounce_angle_rad));
	
	logic paddle1_hit_reg, paddle2_hit_reg;
	cordic cor (.clk(CLOCK_50), .reset, .start(paddle1_hit_reg | paddle2_hit_reg), .angle_in(paddle_bounce_angle_rad), .cos_out, .sin_out);
	
	// Synchronize paddle hit signals to clock
	always_ff @(posedge CLOCK_50) begin
		paddle1_hit_reg <= paddle1_hit;
		paddle2_hit_reg <= paddle2_hit;
	end

	logic [35:0] x_delta_intermediate, y_delta_intermediate;
	logic [9:0] x_delta;
	logic [8:0] y_delta;

	logic [32:0] cos_out_abs, sin_out_abs;
	assign cos_out_abs = cos_out[31] ? ~cos_out + 32'd1 : cos_out;
	assign sin_out_abs = sin_out[31] ? ~sin_out + 32'd1 : sin_out;

	// BALL_SPEED: 			32 integer bits, 0 fraction bits
	// last_*_out[31:28]:  	 2 integer bits, 2 fraction bits
	// product:					34 integer bits, 2 fraction bits
	assign x_delta_intermediate = BALL_SPEED * cos_out_abs[31:28];
	assign y_delta_intermediate = BALL_SPEED * sin_out_abs[31:28];

	// Truncate and ignore fractional part in each intermediate delta
	assign x_delta = cos_out === 'X ? BALL_SPEED : x_delta_intermediate[11:2];
	assign y_delta = sin_out === 'X ? 0 : y_delta_intermediate[10:2];

	// Define flags indicating current ball direction
	logic moving_right;
	logic moving_up;
	
	// States and FSM logic
	enum {S_idle, S_p1_hit, S_p2_hit, S_top_hit, S_bottom_hit, S_move_right, S_move_left, S_pause} ps, ns;
	logic set_direction_right, set_direction_left, set_direction_up, set_direction_down, move_ball_left, move_ball_right, reset_ball;
	
	/*** Controller logic ***/
	always_ff @(posedge clk) begin
		if (reset)
			ps <= S_idle;
		else
			ps <= ns;
	end
	/************************/
	
	/*** Datapath logic ***/
	always_ff @(posedge clk) begin
		if (set_direction_right)		moving_right <= 1'b1;
		else if (set_direction_left)	moving_right <= 1'b0;
		else if (reset_ball)				moving_right <= 1'b1;
		else									moving_right <= moving_right;
		
		if (set_direction_up)			moving_up <= 1'b1;
		else if (set_direction_down)	moving_up <= 1'b0;
		else if (reset_ball) 			moving_up <= 1'b0;
		else									moving_up <= moving_up;
		
		if (reset_ball) begin
			x_min <= (SCREEN_WIDTH - BALL_LEN) / 4;
			y_min <= (SCREEN_HEIGHT - BALL_LEN) / 2;
		end
	
		else if (move_ball_right) begin
			x_min <= x_min + x_delta;
			y_min <= moving_up ? y_min - y_delta : y_min + y_delta;
		end
		
		else if (move_ball_left) begin
			x_min <= x_min - x_delta;
			y_min <= moving_up ? y_min - y_delta : y_min + y_delta;
		end
		
		else if (set_direction_left) begin
			x_min <= x_min - x_delta;
			y_min <= moving_up ? y_min - y_delta : y_min + y_delta;
		end
		
		else if (set_direction_right) begin
			x_min <= x_min + x_delta;
			y_min <= moving_up ? y_min - y_delta : y_min + y_delta;
		end
		
		else begin
			x_min <= x_min;
			y_min <= y_min;
		end
	end
	/**********************/
	
	/*** Next state logic ***/
	always_comb begin
		case (ps) 
			S_idle:
				ns = start ? S_move_right : S_idle;

			S_p1_hit:
				ns = start ? S_move_right : S_pause;

			S_p2_hit:
				ns = start ? S_move_left : S_pause;
			
			S_top_hit:
				ns = start ? (moving_right ? S_move_right : S_move_left) : 
								 S_pause;
			
			S_bottom_hit:
				ns = start ? (moving_right ? S_move_right : S_move_left) :
								 S_pause;
			
			S_move_right:
				if 		(!start)						ns = S_pause;
				else if 	(paddle2_hit) 				ns = S_p2_hit;
				else if	(bottom_boundary_hit) 	ns = S_bottom_hit;
				else if	(top_boundary_hit) 		ns = S_top_hit;
				else 										ns = S_move_right;
			
			S_move_left:
				if 		(!start)						ns = S_pause;
				else if 	(paddle1_hit) 				ns = S_p1_hit;
				else if	(bottom_boundary_hit) 	ns = S_bottom_hit;
				else if	(top_boundary_hit) 		ns = S_top_hit;
				else 										ns = S_move_left;			
			
			S_pause:
				ns = start ? (moving_right ? S_move_right : S_move_left) :
								 S_pause;		
		endcase
	end
	/************************/
	
	assign set_direction_right = (ps == S_p1_hit) || (ps == S_move_right);
	assign set_direction_left  = (ps == S_p2_hit) || (ps == S_move_left);
	assign set_direction_up 	= (ps == S_bottom_hit) || hit_intersect > 0;
	assign set_direction_down 	= (ps == S_top_hit) || hit_intersect < 0;
	assign move_ball_right		= (ps == S_move_right);
	assign move_ball_left		= (ps == S_move_left);
	assign reset_ball 			= (ps == S_idle);

endmodule  // ball

module ball_testbench ();

	parameter ClockDelay = 20;

	logic clk, CLOCK_50, reset, start, paddle1_hit, paddle2_hit;
	logic signed [9:0] hit_intersect;
	logic [9:0] x_min;
	logic [8:0] y_min;

	integer i = 0;
	initial begin
		CLOCK_50 <= 0; clk <= 0;
		forever begin
			#(ClockDelay/2) CLOCK_50 <= ~CLOCK_50;
			if (i == 100) begin
				clk <= ~clk; i <= 0;
			end else
				i <= i + 1;
		end
	end  // initial
	
	parameter BALL_LEN = 15, MAX_BOUNCE_ANGLE = 75, BALL_SPEED = 7, PADDLE_HEIGHT = 70, SCREEN_WIDTH = 640, SCREEN_HEIGHT = 480;
	ball #(BALL_LEN, MAX_BOUNCE_ANGLE, BALL_SPEED, PADDLE_HEIGHT, SCREEN_WIDTH, SCREEN_HEIGHT) dut
		(.clk, .CLOCK_50, .reset, .start, .x_min, .y_min, .paddle1_hit, .paddle2_hit, .hit_intersect);

	integer j;
	initial begin
		$display(" time   x   y  p1 p2 intersect");
		$display("------ --- --- -- -- ---------");
	   $monitor("%6t %3d %3d  %b  %b     %d", $time, x_min, y_min, paddle1_hit, paddle2_hit, hit_intersect);
		
		start <= 0; @(posedge clk); reset <= 1; @(posedge clk); reset <= 0; @(posedge clk);
		
		start <= 1; @(posedge clk);
		paddle1_hit <= 1'b0; paddle2_hit <= 1'b0; hit_intersect <= 10'b0_0000_0000;
		for (j=0; j<5; j++) @(posedge clk);
		start <= 0; @(posedge clk); reset <= 1; @(posedge clk); reset <= 0; @(posedge clk);

		// hit in center of paddle 1; x_min should begin to increase, y_min should remain the same
		start <= 1; @(posedge clk);
		paddle1_hit <= 1'b1; paddle2_hit <= 1'b0; hit_intersect <= 10'b0_0000_0000; @(posedge clk);
		paddle1_hit <= 1'b0;																			 @(posedge clk);
		for (j=0; j<5; j++) @(posedge clk);
		start <= 0; @(posedge clk); reset <= 1; @(posedge clk); reset <= 0; @(posedge clk);
		
		// hit in center of paddle 2; x_min should begin to decrease, y_min should remain the same
		start <= 1; @(posedge clk);
		paddle1_hit <= 1'b0; paddle2_hit <= 1'b1; hit_intersect <= 10'b0_0000_0000; @(posedge clk);
									paddle2_hit <= 1'b0;												 @(posedge clk);
		for (j=0; j<5; j++) @(posedge clk);
		start <= 0; @(posedge clk); reset <= 1; @(posedge clk); reset <= 0; @(posedge clk);
		
		// hit on top half of paddle 1; x_min should begin to increase, y_min should begin to decrease
		start <= 1; @(posedge clk);
		paddle1_hit <= 1'b1; paddle2_hit <= 1'b0; hit_intersect <= 8; @(posedge clk);
		paddle1_hit <= 1'b0;																			 @(posedge clk);
		for (j=0; j<5; j++) @(posedge clk);
		start <= 0; @(posedge clk); reset <= 1; @(posedge clk); reset <= 0; @(posedge clk);
		
		// hit on top half of paddle 2; x_min should begin to decrease, y_min should begin to decrease
		start <= 1; @(posedge clk);
		paddle1_hit <= 1'b0; paddle2_hit <= 1'b1; hit_intersect <= 8; @(posedge clk);
									paddle2_hit <= 1'b0; 										  	 @(posedge clk);
		for (j=0; j<5; j++) @(posedge clk);
		start <= 0; @(posedge clk); reset <= 1; @(posedge clk); reset <= 0; @(posedge clk);
		
		// hit on bottom half of paddle 1; x_min should begin to increase, y_min should begin to increase
		start <= 1; @(posedge clk);
		paddle1_hit <= 1'b1; paddle2_hit <= 1'b0; hit_intersect <= -8; @(posedge clk);
		paddle1_hit <= 1'b0;																			 @(posedge clk);
		for (j=0; j<5; j++) @(posedge clk);
		start <= 0; @(posedge clk); reset <= 1; @(posedge clk); reset <= 0; @(posedge clk);
		
		// hit on bottom half of paddle 2; x_min should begin to decrease, y_min should begin to increase
		start <= 1; @(posedge clk);
		paddle1_hit <= 1'b0; paddle2_hit <= 1'b1; hit_intersect <= -8; @(posedge clk);
									paddle2_hit <= 1'b0; 											 @(posedge clk);
		for (j=0; j<5; j++) @(posedge clk);
		start <= 0; @(posedge clk); reset <= 1; @(posedge clk); reset <= 0; @(posedge clk);
		
		// Let the ball go to edge of screen
		start <= 1; @(posedge clk);
		paddle1_hit <= 1'b0; paddle2_hit <= 1'b0; hit_intersect <= 0; @(posedge clk);
		for (j=0; j<50; j++) @(posedge clk);
		start <= 0; @(posedge clk); reset <= 1; @(posedge clk); reset <= 0; @(posedge clk);
		
		$stop;
	end  // initial

endmodule  // ball_testbench
