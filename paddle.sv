/*
 * Determines the location of a paddle given move up and move down commands.
 *		clk: The master clock
 *		reset: When high, moves the ball to its starting position
 *		start: When high, allows for paddle movement
 *		move_up: When high, moves paddle up (equivalent to decreasing y)
 *		move_down: when high, moves paddle down (equivalent to increasing y)
 *		y_min: The minimum y-value of the paddle
 */
module paddle #(parameter y0 = 240, PADDLE_HEIGHT = 70, SCREEN_HEIGHT = 480) (clk, reset, start, move_up, move_down, y_min);

	input  logic clk, reset, start, move_up, move_down;
	output logic [8:0] y_min;
	
	always_ff @(posedge clk)
		if (reset)
			y_min <= y0;
		else if (start)
			// Move paddle up
			if (move_up && ~move_down)
				if (y_min == 0) y_min <= y_min;
				else y_min <= y_min - 9'b1;
			
			// Move paddle down
			else if (~move_up && move_down) 
				if (y_min + PADDLE_HEIGHT == SCREEN_HEIGHT) y_min <= y_min;
				else y_min <= y_min + 9'b1;
				
			// Do not move paddle
			else y_min <= y_min;

endmodule  // paddle

module paddle_testbench ();

	parameter ClockDelay = 20;

	logic clk, reset, start, move_up, move_down;
	logic [8:0] y_min;
	
	initial begin
		clk <= 0;
		forever #(ClockDelay/2) clk <= ~clk;
	end  // initial
	
	parameter y0 = 25, PADDLE_HEIGHT = 10, SCREEN_HEIGHT = 50;
	
	paddle #(y0, PADDLE_HEIGHT, SCREEN_HEIGHT) dut (.*);

	integer i = 0;
	initial begin
		reset <= 0; @(posedge clk);
		reset <= 1; @(posedge clk);
		reset <= 0; @(posedge clk);
		start <= 1; @(posedge clk);
		
		// Check that paddle begins at y0
		
		// Move paddle up, then down
		{ move_up, move_down } <= 2'b10; @(posedge clk);
		{ move_up, move_down } <= 2'b00; @(posedge clk);
		{ move_up, move_down } <= 2'b01; @(posedge clk);
		{ move_up, move_down } <= 2'b01; @(posedge clk);
		
		// Ensure paddle does not move beyond edge of screen
		for (i=0; i<SCREEN_HEIGHT; i++) @(posedge clk);
		
		{ move_up, move_down } <= 2'b10; @(posedge clk);
		for (i=0; i<SCREEN_HEIGHT; i++) @(posedge clk);

		$stop;
	end
	
endmodule  // paddle_testbench 