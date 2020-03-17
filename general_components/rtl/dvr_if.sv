interface dvr_if #(parameter int unsigned DATA_WIDTH = 32) (input clk);

	logic [DATA_WIDTH - 1 : 0] 	data;
	logic 						valid;
	logic 						rdy;

	modport master (
		output data, 
		output valid, 
		input  rdy
	);

	modport slave (
		input  data, 
		input  valid, 
		output rdy
	);
endinterface