// Asymmetric Dual-Port Asymmetric ram (Verilog)
// A - write interface.
// B - read interface.

module sdp_ram
#(
	parameter int WIDTH_A = 4,
	parameter int DEPTH_A = 1024,
	parameter int WIDTH_B = 16,
	parameter int DEPTH_B = 256
(
	input  logic 							clka, 
	input  logic 							clkb, 
	input  logic 							ena, 
	input  logic 							wea, 
	input  logic 							enb, 
	input  logic [log2(DEPTH_A) - 1 : 0] 	addra, 
	input  logic [log2(DEPTH_B) - 1 : 0]	addrb, 
	input  logic [WIDTH_A - 1 : 0] 			dina, 
	output logic [WIDTH_B - 1 : 0]			doutb
);

	localparam int MAX_SIZE  = `max(DEPTH_A, DEPTH_B);
	localparam int MAX_WIDTH = `max(WIDTH_A, WIDTH_B);
	localparam int MIN_WIDTH = `min(WIDTH_A, WIDTH_B);
	localparam int RATIO     = MAX_WIDTH / MIN_WIDTH;
	localparam int LOG2RATIO = log2(RATIO);

	reg [MIN_WIDTH - 1 : 0] ram [0 : MAX_SIZE - 1];
	reg [WIDTH_B - 1 : 0] 	readB;

	generate : ram_write
		// Equals or Read is bigger.
		if (WIDTH_B >= WIDTH_A) begin 
			always @(posedge clka) begin
				if (ena) begin
					if (wea) begin 
		 				ram[addra] <= dina;
					end
				end
			end
		end	

		// Write is bigger.
		else begin 
			always @(posedge clka) begin 
				integer i;
				reg [LOG2RATIO-1:0] lsbaddr;
				for (i=0; i< RATIO; i= i+ 1) begin 
					lsbaddr = i;
					if (ena) begin
						if (wea) begin 
							ram[{addra, lsbaddr}] <= dina[(i+1)*MIN_WIDTH-1 -: MIN_WIDTH];
						end
					end
				end
			end
		end

	generate : ram_read
		// Read is bigger.
		if (WIDTH_B > WIDTH_A) begin 
			always @(posedge clkb) begin 
				integer i;
				reg [LOG2RATIO-1:0] lsbaddr;
				
				if (enb) begin
					for (i = 0; i < RATIO; i = i+1) begin
						lsbaddr = i;
						readB[(i+1)*MIN_WIDTH-1 -: MIN_WIDTH] <= ram[{addrb, lsbaddr}];
					end
				end
			end
		end 

		// Equals or Write is bigger
		else begin 
			always @(posedge clkb) begin
				if (enb) begin
					readB <= ram[addrb];
				end
			end
		end
	endgenerate

	assign doutb = readB;

endmodule