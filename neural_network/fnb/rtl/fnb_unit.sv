// Feedfoward And Backpropagation Unit - Calculations.


module fnb_unit 
#(
	parameter int A_WIDTH 					= 18,
	parameter int PREV_LAYER_NUM_OF_NUERONS = 4,
	parameter int CURR_LAYER_NUM_OF_NUERONS = 4,
	parameter int CURR_LAYER_PIPE_SIZE 		= 1
)
(
	// Clock and Reset.	
	input logic 	clk,    												// Clock
	input logic 	rst_n,  												// Asynchronous reset active low

	// General.
	input logic		bp_active, 												// Backpropagation needed in the current process.

	// FNB Manager interface.
	dv_if.slave 	units_ff_if_arr  [CURR_LAYER_NUM_OF_NUERONS - 1 : 0], 	// Feedfoward interface to the units.
	dv_if.slave 	units_bp_if_arr  [CURR_LAYER_NUM_OF_NUERONS - 1 : 0], 	// backpropagation interface to the units.
	dv_if.slave 	units_e_if_arr   [CURR_LAYER_NUM_OF_NUERONS - 1 : 0], 	// error interface to the units.
	output logic [A_WIDTH - 1 : 0] [CURR_LAYER_NUM_OF_NUERONS - 1 : 0] units_res_arr, 	// Result from all the units.
	
	// Copy requests.
	avalon_mm_if.slave read_req_mm [PREV_LAYER_NUM_OF_NUERONS - 1 : 0]
);


	////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////  Declarations  ////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////

	localparam int PREV_A_IF_WIDTH 	= A_WIDTH * CURR_LAYER_PIPE_SIZE; // Also used for RAM's DATA_WIDTH
	localparam int RAM_ADDR_WIDTH 	= log2up(CURR_LAYER_NUM_OF_NUERONS / CURR_LAYER_PIPE_SIZE);
	
	localparam int A_ST_CYCLES 		= PREV_LAYER_NUM_OF_NUERONS / CURR_LAYER_PIPE_SIZE;
	localparam int CALC_DELAY 		= log2up(CURR_LAYER_PIPE_SIZE);
	
	localparam int CNT_WIDTH 		= $max(CALC_DELAY, A_ST_CYCLES);

	typedef enum int {
		FEEDFOWARD_ST,			// Calc a[i].
		BACKPROPAGATION_ST,		// Backpropagate the error.
	} fnb_unit_t;
	fnb_unit_t current_state;

	// Signals.

	// Multiplier in-out.
	logic [A_WIDTH - 1 : 0] mult_a_in;

	////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////     Logic      ////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////

	// Manage if we are in feedfoard state or backpropagation.
	always_ff @(posedge clk or posedge rst) begin 
		if (!rst) begin
			current_state <= FEEDFOWARD;
		end else begin
			unique case (current_state)
				// Calc a[i].
				FEEDFOWARD_ST :
				begin 
					// When reaching to the end of the BRAM (when adding the bias).
					if ((intr_addr == A_ST_CYCLES) && (TODO)) begin 
						current_state <= BACKPROPAGATION_ST;
					end
				end			
				
				// Backpropagate the error.
				BACKPROPAGATION_ST :
				begin 
					// When reaching to the end of the BRAM (when adding the bias).
					if ((intr_addr == A_ST_CYCLES) && (TODO)) begin 
						current_state <= BACKPROPAGATION_ST;
					end					
				end

				// Unknown.
				default :
					irq <= 1'b1;
			endcase
		end
	end
endmodule