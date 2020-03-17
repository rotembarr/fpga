// Asymmetric Dual-Port Asymmetric ram (Verilog)
// A - write interface.
// B - read interface.

module tdp_ram
#(
	parameter int WIDTH_A = 4,
	parameter int DEPTH_A = 1024,
	parameter int WIDTH_B = 16,
	parameter int DEPTH_B = 256
(
	input  logic 							clka, 
	input  logic 							clkb, 
	input  logic 							ena, 
	input  logic 							enb, 
	input  logic 							wea, 
	input  logic 							web, 
	input  logic [log2(DEPTH_A) - 1 : 0] 	addra, 
	input  logic [log2(DEPTH_B) - 1 : 0]	addrb, 
	input  logic [WIDTH_A - 1 : 0] 			dina, 
	input  logic [WIDTH_B - 1 : 0] 			dinb, 
	output logic [WIDTH_A - 1 : 0]			douta,
	output logic [WIDTH_B - 1 : 0]			doutb
);

	localparam int MAX_SIZE  = `max(DEPTH_A, DEPTH_B);
	localparam int MAX_WIDTH = `max(WIDTH_A, WIDTH_B);
	localparam int MIN_WIDTH = `min(WIDTH_A, WIDTH_B);
	localparam int RATIO     = MAX_WIDTH / MIN_WIDTH;
	localparam int LOG2RATIO = log2(RATIO);

	reg [MIN_WIDTH - 1 : 0] ram [0 : MAX_SIZE - 1];
	reg [WIDTH_A-1:0] readA;
	reg [WIDTH_B-1:0] readB;

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

module asym_ram_tdp_read_first (clkA, clkB, enaA, weA, enaB, weB, addrA, addrB, diA,
doA, diB, doB);
parameter WIDTH_B = 4;
parameter DEPTH_B = 1024;
parameter ADDRWIDTHB = 10;
parameter WIDTH_A = 16;
parameter DEPTH_A = 256;
parameter ADDRWIDTHA = 8;
input clkA;
input clkB;
input weA, weB;
input enaA, enaB;
input [ADDRWIDTHA-1:0] addrA;
input [ADDRWIDTHB-1:0] addrB;
input [WIDTH_A-1:0] diA;
input [WIDTH_B-1:0] diB;
output [WIDTH_A-1:0] doA;
output [WIDTH_B-1:0] doB;


reg [MIN_WIDTH-1:0] ram [0:MAX_SIZE-1];
always @(posedge clkB)
begin
 if (enaB) begin
 readB <= ram[addrB] ;
 if (weB)
 ram[addrB] <= diB;
 end
end
always @(posedge clkA)
begin : portA
 integer i;
 reg [LOG2RATIO-1:0] lsbaddr ;
 for (i=0; i< RATIO; i= i+ 1) begin
 lsbaddr = i;
 if (enaA) begin
 readA[(i+1)*MIN_WIDTH -1 -: MIN_WIDTH] <= ram[{addrA, lsbaddr}];
 if (weA)
 ram[{addrA, lsbaddr}] <= diA[(i+1)*MIN_WIDTH-1 -: MIN_WIDTH];
 end
 end
end
assign doA = readA;
assign doB = readB;
endmodule
//// True Dual Port Asymmetric ram Write First (Verilog)
//// Filename: asym_ram_tdp_write_first.v
// Asymmetric port ram - TDP
// WRITE_FIRST MODE.
// asym_ram_tdp_write_first.v
module asym_ram_tdp_write_first (clkA, clkB, enaA, weA, enaB, weB, addrA, addrB, diA,
doA, diB, doB);
parameter WIDTH_B = 4;
parameter DEPTH_B = 1024;
parameter ADDRWIDTHB = 10;
parameter WIDTH_A = 16;
parameter DEPTH_A = 256;
parameter ADDRWIDTHA = 8;
input clkA;
input clkB;
input weA, weB;
input enaA, enaB;
input [ADDRWIDTHA-1:0] addrA;
input [ADDRWIDTHB-1:0] addrB;
input [WIDTH_A-1:0] diA;
input [WIDTH_B-1:0] diB;
output [WIDTH_A-1:0] doA;
output [WIDTH_B-1:0] doB;
`define max(a,b) {(a) > (b) ? (a) : (b)}
`define min(a,b) {(a) < (b) ? (a) : (b)}
function integer log2;
input integer value;
reg [31:0] shifted;
integer res;
begin
 if (value < 2)
 log2 = value;
 else
 begin
 shifted = value-1;
 for (res=0; shifted>0; res=res+1)
 shifted = shifted>>1;
 log2 = res;
 end
end
endfunction
localparam MAX_SIZE = `max(DEPTH_A, DEPTH_B);
localparam MAX_WIDTH = `max(WIDTH_A, WIDTH_B);
localparam MIN_WIDTH = `min(WIDTH_A, WIDTH_B);
localparam RATIO = MAX_WIDTH / MIN_WIDTH;
localparam LOG2RATIO = log2(RATIO);
reg [MIN_WIDTH-1:0] ram [0:MAX_SIZE-1];
reg [WIDTH_A-1:0] readA;
reg [WIDTH_B-1:0] readB;
always @(posedge clkB)
begin
 if (enaB) begin
 if (weB)
 ram[addrB] = diB;
 readB = ram[addrB] ;
 end
end
always @(posedge clkA)
begin : portA
 integer i;
 reg [LOG2RATIO-1:0] lsbaddr ;
 for (i=0; i< RATIO; i= i+ 1) begin
 lsbaddr = i;
 if (enaA) begin
 if (weA)
 ram[{addrA, lsbaddr}] = diA[(i+1)*MIN_WIDTH-1 -: MIN_WIDTH];

 readA[(i+1)*MIN_WIDTH -1 -: MIN_WIDTH] = ram[{addrA, lsbaddr}];
 end
 end
end
assign doA = readA;
assign doB = readB;
endmodule
