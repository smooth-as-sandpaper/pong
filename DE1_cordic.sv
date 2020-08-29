module DE1_cordic (CLOCK_50, LEDR, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, SW);

	input logic CLOCK_50;
	input logic [9:0] SW;
	output logic [9:0] LEDR;
	output logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;

	logic clk = 0;
	integer i = 0;
	always_ff @(posedge CLOCK_50) begin
		if (i == 25000000) begin
			clk <= ~clk;
			i <= 0;
		end else
			i <= i + 1;
	end
	
	logic [31:0] cos_out, sin_out;
	
	logic [31:0] angle_in;
	assign angle_in = 32'h0;
	
	logic [31:0] angle_next, cos_next, sin_next;
	
	cordic cor (.clk(CLOCK_50), .reset(SW[9]), .start(SW[0]), .angle_in, .cos_out, .sin_out);
	
	logic cos_not_zero;
	logic sin_not_zero;

	always_ff @(posedge CLOCK_50) begin
		
		if (cos_out[31:25] != 0) cos_not_zero <= 1'b1;
		else cos_not_zero <= 1'b0;
		
		if (sin_out[31:25] != 0) sin_not_zero <= 1'b1;
		else sin_not_zero <= 1'b0;
	
	end
	
	logic [3:0] curr1, curr2, curr3, curr4, curr5, curr6;
	
	always_ff @(posedge CLOCK_50) begin
		if (SW[8]) begin
			curr1 <= angle_in >> 28;
			curr2 <= angle_in >> 24;
			curr3 <= angle_in >> 20;
			curr4 <= angle_in >> 16;
			curr5 <= angle_in >> 12;
			curr6 <= angle_in >> 8;
		end
		
		else if (SW[7]) begin
			curr1 <= cos_out >> 28;
			curr2 <= cos_out >> 24;
			curr3 <= cos_out >> 20;
			curr4 <= cos_out >> 16;
			curr5 <= cos_out >> 12;
			curr6 <= cos_out >> 8;
		end
		
		else if (SW[6]) begin
			curr1 <= sin_out >> 28;
			curr2 <= sin_out >> 24;
			curr3 <= sin_out >> 20;
			curr4 <= sin_out >> 16;
			curr5 <= sin_out >> 12;
			curr6 <= sin_out >> 8;
		end
		
		else begin
			curr1 <= 'X;
			curr2 <= 'X;
			curr3 <= 'X;
			curr4 <= 'X;
			curr5 <= 'X;
			curr6 <= 'X;
		end
		
	end
	
	seg7 a1 (.bcd(curr1), .leds(HEX5));
	seg7 a2 (.bcd(curr2), .leds(HEX4));
	seg7 a3 (.bcd(curr3), .leds(HEX3));
	seg7 a4 (.bcd(curr4), .leds(HEX2));
	seg7 a5 (.bcd(curr5), .leds(HEX1));
	seg7 a6 (.bcd(curr6), .leds(HEX0));
	
	assign LEDR[9] = cos_not_zero;
	assign LEDR[8] = sin_not_zero;
	
endmodule 

module DE1_cordic_testbench ();

	parameter ClockDelay = 20;

	logic CLOCK_50;
	logic [9:0] LEDR, SW;
	logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
	
	initial begin
		CLOCK_50 <= 0;
		forever #(ClockDelay/2) CLOCK_50 <= ~CLOCK_50;
	end	
	
	DE1_cordic dut (.*);
	
	logic reset, start;
	assign SW[9] = reset;
	assign SW[0] = start;
	
	integer i;
	initial begin
		@(posedge CLOCK_50); reset <= 0; @(posedge CLOCK_50);
		reset <= 1; start <= 0; @(posedge CLOCK_50);
		reset <= 0; @(posedge CLOCK_50);
		
		start <= 1; for (i=0; i<35; i++) @(posedge CLOCK_50);
		
		SW[8:1] = 8'b1000_0000; @(posedge CLOCK_50);
		SW[8:1] = 8'b0100_0000; @(posedge CLOCK_50);
		SW[8:1] = 8'b0010_0000; @(posedge CLOCK_50);
		SW[8:1] = 8'b0001_0000; @(posedge CLOCK_50);
		SW[8:1] = 8'b0000_1000; @(posedge CLOCK_50);
		SW[8:1] = 8'b0000_0100; @(posedge CLOCK_50);
	
		$stop;
	end
	
endmodule 