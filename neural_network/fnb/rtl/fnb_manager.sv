// Feedfoward And Backpropagation SM - Control.
// For timing - SM has to be one-hot.


module fnb_manager 
#(
	parameter int A_WIDTH 					= 18,
	parameter int PREV_LAYER_NUM_OF_NUERONS = 4,
	parameter int CURR_LAYER_NUM_OF_NUERONS = 4,
	parameter int CURR_LAYER_PIPE_SIZE 		= 1
)
(
	// Clock and Reset.	
	input logic 	clk,    												// Clock.
	input logic 	rst_n,  												// Asynchronous reset active low.

	// General.
	input logic		bp_active, 												// Backpropagation needed in the current process.

	// Prev layer interface.	
	dvr_if.slave	prev_a_st,												// Previous layer outputs as a stream.
	input logic		prev_w_copy_done, 										// Previous layer done copy weights.

	// Next layer interface.
	dvr_if.slave 	curr_e_mat,												// Current layer errors.
	dvr_if.master 	curr_a_mat,												// Asynchronous reset active low.

	// FNB units interface.
	dv_if.master 	units_ff_if_arr  [CURR_LAYER_NUM_OF_NUERONS - 1 : 0], 	// Feedfoward interface to the units.
	dv_if.master 	units_bp_if_arr  [CURR_LAYER_NUM_OF_NUERONS - 1 : 0], 	// Backpropagation interface to the units.
	dv_if.master 	units_e_if_arr   [CURR_LAYER_NUM_OF_NUERONS - 1 : 0], 	// Error interface to the units.
	input logic [A_WIDTH - 1 : 0] [CURR_LAYER_NUM_OF_NUERONS - 1 : 0] units_res_arr, 	// Result from all the units.
	

	// Interupt.
	output logic 	irq 													// SM IRQ.
);

	////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////  Declarations  ////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////

	// For last calculation.
	localparam int PREV_A_IF_WIDTH 	= A_WIDTH * CURR_LAYER_PIPE_SIZE; // Also used for RAM's DATA_WIDTH
	localparam int RAM_ADDR_WIDTH 	= log2up(CURR_LAYER_NUM_OF_NUERONS / CURR_LAYER_PIPE_SIZE);
	
	// For current calculation.
	localparam int A_ST_CYCLES 		= PREV_LAYER_NUM_OF_NUERONS / CURR_LAYER_PIPE_SIZE;
	localparam int CALC_DELAY 		= log2up(CURR_LAYER_PIPE_SIZE);
	
	// General.
	localparam int CNT_WIDTH 		= $max(CALC_DELAY, A_ST_CYCLES);

	//// Typedefs.
	typedef logic [RAM_ADDR_WIDTH - 1 : 0] ram_addr_t;

	// SM.
	typedef enum int {
		FEEDFOWARD_ST,				// Get prev_a_st and calc curr_a (And save prev_a).
		WAIT_FOR_FINISH_ST, 		// Feedfoward calc takes some extra cycles to finish.
		SEND_CURR_A_ST, 			// Send result and hold curr_a.
		GET_ERROR_ST, 				// Get error and dsig it. 
		WAIT_FOR_COPY_DONE_ST, 		// If copy doesn't recived in the current proccess, wait for it.
		BACKPROPAGATION_WEIGHTS_ST, // Backpropagate the error to the weights.
		BACKPROPAGATION_BIASES_ST,	// Backpropagate the error to the bias.
		FINISH_BACKPROPAGATION_ST 	// One cycle of updating weights tables.
	} fnb_sm_t;
	fnb_sm_t current_state;

	//// Signals ////
	
	// Copied prev a from a RAM.
	logic [PREV_A_IF_WIDTH - 1 : 0] ram_prev_a_dout;

	// Sampled copy_done.
	logic prev_w_copy_done_s;

	// Re-used cnt.
	logic [log2up(CNT_WIDTH) - 1 : 0] cnt;

	// Copy finished.
	logic prev_w_copy_done_s; // Sampled until clear.
	logic prev_w_copy_done_l; // Behave like latch.

	////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////     Logic      ////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////
	// Store the prev_a_st.
	single_port_bram 
	#( // TODO
		.DATA_WIDTH(PREV_A_IF_WIDTH),
		.ADDR_WIDTH(log2up(CURR_LAYER_NUM_OF_NUERONS / CURR_LAYER_PIPE_SIZE)),
	)
	ram_prev_a_inst 
	(
		.clk(clk),
		.rst(rst_n),
		.ce(1'b1),
		.we((current_state == FEEDFOWARD_ST) & prev_a_st.valid),
		.addr(ram_addr_t'(cnt)),
		.din(prev_a_st.data),
		.dout(ram_prev_a_dout),
	);

	// When prev_w_copy_done arrived, let the SM know.
	assign prev_w_copy_done_l = prev_w_copy_done_s | prev_w_copy_done;

	always_ff @(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			current_state 		<= FEEDFOWARD_ST;
			cnt 				<= {log2up(CNT_WIDTH){1'b0}};
			irq 				<= 1'b0;
			prev_w_copy_done_s 	<= 1'b0;
		end else begin

			// Set and rst prev_w_copy_done_s. 
			// We always set the bit and then we move to the BACKPROPAGATION state and rst there.
			if (current_state == BACKPROPAGATION_WEIGHTS_ST) begin 
				prev_w_copy_done_s <= 1'b0;
			end else if (prev_w_copy_done) begin 
				prev_w_copy_done_s <= 1'b1;
			end

			unique case (current_state)
				
				// Get prev_a_st and calc curr_a (And save prev_a).
				FEEDFOWARD_ST : 
				begin 

					if (prev_a_st.valid) begin 
						
						// Advance counter.
						cnt <= cnt + 1;
	
						if (cnt == A_ST_CYCLES - 1) begin 
							cnt 		  <= {log2up(CNT_WIDTH){1'b0}};
							current_state <= WAIT_FOR_FINISH_ST;
					 	end
					end
				end
				
				// Feedfoward calc takes some extra cycles to finish.
				WAIT_FOR_FINISH_ST : 
				begin 
					// Advance counter.
					cnt <= cnt + 1;

					if (cnt == CALC_DELAY - 1) begin 
						cnt 		  <= {log2up(CNT_WIDTH){1'b0}};
						current_state <= SEND_CURR_A_ST;
					end
				end
				
				// Send result and hold curr_a.
				SEND_CURR_A_ST :
				begin 
					// Transaction sent.
					if (curr_a_mat.rdy) begin 

						// Go to backpropagation or return to feedfoward.
						if (bp_active) begin 
							current_state <= GET_ERROR_ST;
						end else begin 
							current_state <= FEEDFOWARD_ST;
						end
					end
				end
				
				// Get error and dsig it. 
				GET_ERROR_ST :
				begin 
				
					// When getting errors.
					if (curr_e_mat.valid) begin 

						// If we are able to use the weights for backpropagtion or should we wait until copy is fimished.
						if (prev_w_copy_done_l) begin
							current_state <= BACKPROPAGATION_WEIGHTS_ST;
						end else begin 
							current_state <= WAIT_FOR_COPY_DONE_ST;
						end
				
					end
				end
				
				// If copy doesn't recived in the current proccess, wait for it.
				WAIT_FOR_COPY_DONE_ST :
				begin 
					if (prev_w_copy_done) begin 
						current_state <= BACKPROPAGATION_WEIGHTS_ST;
					end
				end
				
				// Backpropagate the error to the weights.
				BACKPROPAGATION_WEIGHTS_ST :
				begin 
					// Advance counter.
					cnt <= cnt + 1;

					if (cnt == A_ST_CYCLES - 1) begin 
						cnt 		  <= {log2up(CNT_WIDTH){1'b0}};
						current_state <= BACKPROPAGATION_BIASES_ST;
					end
				end

				// Backpropagate the error to the bias.			
				BACKPROPAGATION_BIASES_ST :
				begin 
					current_state <= FINISH_BACKPROPAGATION_ST;
				end

				// One cycle of updating weights tables.
				FINISH_BACKPROPAGATION_ST :
				begin 
					current_state <= FEEDFOWARD_ST;
				end

				// Unknown.
				default : 
					irq <= 1'b1;
			endcase
		end
	end

	// Lane interfaces.
	assign prev_a_st.rdy 		= (current_state == FEEDFOWARD_ST);
	assign curr_e_mat.rdy 		= (current_state == GET_ERROR_ST);
	assign curr_a_mat.valid		= (current_state == SEND_CURR_A_ST);
	assign curr_a_mat.data		= units_res_arr; // Natural Casting.

	// Units Interfaces.
	genvar i;
	generate
		for (i = 0; i < CURR_LAYER_NUM_OF_NUERONS; i++) begin
			assign units_ff_if_arr[i].valid = (current_state == FEEDFOWARD_ST) & prev_a_st.valid;
			assign units_ff_if_arr[i].data	= prev_a_st.data;
			assign units_bp_if_arr[i].valid = (current_state == BACKPROPAGATION_WEIGHTS_ST); // TODO - maybe bp bias state also
			assign units_bp_if_arr[i].data 	= ram_prev_a_dout;
			assign units_e_if_arr[i].valid 	= (current_state == GET_ERROR_ST) & curr_e_mat.valid;
			assign units_e_if_arr[i].data 	= curr_e_mat.data;
		end
	endgenerate
endmodule