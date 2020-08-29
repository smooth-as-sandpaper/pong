/*
 * Tracks current game score.
 *		clk: Master clock
 *		reset: When high, resets scores to 0
 *		p1_scored: When high, increments paddle 1's score
 *		p2_scored: When high, increments paddle 2's score
 *		p1_score: Paddle 1's current score
 *		p2_score: Paddle 2's current score
 */
module scoreboard (clk, reset, p1_scored, p2_scored, p1_score, p2_score);

	input logic clk, reset, p1_scored, p2_scored;
	
	output integer p1_score, p2_score;
	
	always_ff @(posedge clk) begin
		// Reset scores
		if (reset) begin
			p1_score <= 0;
			p2_score <= 0;
		end 
		
		// Increment scores based on input signals
		else begin
			if (p1_scored) begin
				p1_score <= p1_score + 1;
			end
			
			else if (p2_scored) begin
				p2_score <= p2_score + 1;
			end
			
			else begin
				p1_score <= p1_score;
				p2_score <= p2_score;
			end
		end
	end

endmodule  // scoreboard


module scoreboard_testbench ();

	parameter ClockDelay = 20;

	logic clk, reset, p1_scored, p2_scored;
	integer p1_score, p2_score;
	
	initial begin
		clk <= 0;
		forever #(ClockDelay/2) clk <= ~clk;
	end  // initial
	
	scoreboard dut (.*);

	initial begin
		reset <= 0; @(posedge clk);
		reset <= 1; @(posedge clk);
		reset <= 0; @(posedge clk);
		
		p1_scored <= 1; p2_scored <= 0; @(posedge clk);
		p1_scored <= 0; p2_scored <= 0; @(posedge clk);
		p1_scored <= 0; p2_scored <= 1; @(posedge clk);
		p1_scored <= 1; p2_scored <= 0; @(posedge clk);
		p1_scored <= 0; p2_scored <= 0; @(posedge clk);
		
		$stop;
	end
	
endmodule  // scoreboard_testbench