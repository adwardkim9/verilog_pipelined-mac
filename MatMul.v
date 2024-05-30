module MatMul #(
    parameter int N = 5, // Number of columns in the weight matrix
    parameter int T = 10 // Number of columns in the input matrix
)(
    input CLK,
    input RSTN,
    input [39:0] Weight_i,
    input [39:0] In_i,
    input start,

    output reg [39:0] OUT_o,
    output reg VAL_o,
    output reg OV_o
);
    parameter IDLE = 4'b0001,
            LOAD_WEIGHT = 4'b0010,
            LOAD_INPUT = 4'b0100,
            COMPUTE = 4'b1000;
    
    reg[3:0] present_state, next_state;
    reg[3:0] weight_counter, input_counter, compute_counter;

    reg [39:0] weight [0:N-1];
    reg [8*T-1:0] input_reg [0:4];
    
    reg [15:0] partial_sum [0:4];
    reg [15:0] result [0:4];

// Control Signal
    always @(posedge CLK or negedge RSTN) begin
		if(!RSTN)
			present_state <= IDLE;
		else
			present_state <= next_state;
	end

    always @(posedge CLK) begin
        case(present_state)
            IDLE: begin
                if(start) next_state <= LOAD_WEIGHT;
                else next_state <= IDLE;
            end
            LOAD_WEIGHT: begin
                if(weight_counter == N-1) next_state <= LOAD_INPUT;
                else next_state <= LOAD_WEIGHT;
            end
            LOAD_INPUT: begin
                if(input_counter == T-1) next_state <= COMPUTE;
                else next_state <= LOAD_INPUT;
            end
            COMPUTE: begin
                next_state <= IDLE;
            end
            default: next_state <= IDLE;
        endcase
    end

    always @(posedge CLK or negedge RSTN) begin
        if(!RSTN) begin
            weight_counter <= 0;
            input_counter <= 0;
            compute_counter <= 0;
        end else begin
            case(present_state)
                LOAD_WEIGHT: begin
                    if(weight_counter < N-1) weight_counter <= weight_counter + 1;
                    else weight_counter <= 0;
                end
                LOAD_INPUT: begin
                    if(input_counter < T-1) input_counter <= input_counter + 1;
                    else input_counter <= 0;
                end
                COMPUTE: begin
                    if(compute_counter < T-1) compute_counter <= compute_counter + 1;
                    else compute_counter <= 0;
                end
            endcase
        end
    end

    always @(posedge CLK) begin
        if(present_state == LOAD_WEIGHT) begin
            weight[weight_counter]<= Weight_i;
        end else if(present_state == LOAD_INPUT) begin
            for(integer i = 0; i < 5 ; i = i + 1) begin
                input_reg[i][input_counter*8 +: 8] <= In_i[8*i +: 8];
            end 
        end
    end

    always @(posedge CLK or negedge RSTN) begin
        if(!RSTN) begin
            for(integer i = 0; i < 5; i = i + 1) begin
                partial_sum[i] <= 16'b0;
            end
        end else if(present_state == COMPUTE) begin
            for(integer i = 0; i < 5; i = i + 1) begin
                partial_sum[i] <= result[i];
            end
        end
    end

    always @(posedge CLK) begin
        if(present_state == COMPUTE) begin
            for(integer i = 0; i<5 ; i= i+1) begin
                OUT_o[8*i +: 8] <= result[i][7:0];
            end

            VAL_o <= 1'b1;

            OV_o <= |{result[0][15:8], result[1][15:8], result[2][15:8], result[3][15:8], result[4][15:8]};
        end else begin
            VAL_o <= 1'b0;
            OV_o <= 1'b0;
        end
    end

    // Manually instantiate each PE and connect them
    // Row 0
    MAC u00 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[0][7:0]), .data(input_reg[0][0]), .partial_sum(16'b0), .data_out(data_pass[0][0]), .result(partial_sum[0][0]));
    MAC u01 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[0][15:8]), .data(data_pass[0][0]), .partial_sum(partial_sum[0][0]), .data_out(data_pass[0][1]), .result(partial_sum[0][1]));
    MAC u02 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[0][23:16]), .data(data_pass[0][1]), .partial_sum(partial_sum[0][1]), .data_out(data_pass[0][2]), .result(partial_sum[0][2]));
    MAC u03 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[0][31:24]), .data(data_pass[0][2]), .partial_sum(partial_sum[0][2]), .data_out(data_pass[0][3]), .result(partial_sum[0][3]));
    MAC u04 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[0][39:32]), .data(data_pass[0][3]), .partial_sum(partial_sum[0][3]), .data_out(data_pass[0][4]), .result(partial_sum[0][4]));

    // Row 1
    MAC u10 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[1][7:0]), .data(input_reg[1][0]), .partial_sum(16'b0), .data_out(data_pass[1][0]), .result(partial_sum[1][0]));
    MAC u11 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[1][15:8]), .data(data_pass[1][0]), .partial_sum(partial_sum[1][0]), .data_out(data_pass[1][1]), .result(partial_sum[1][1]));
    MAC u12 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[1][23:16]), .data(data_pass[1][1]), .partial_sum(partial_sum[1][1]), .data_out(data_pass[1][2]), .result(partial_sum[1][2]));
    MAC u13 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[1][31:24]), .data(data_pass[1][2]), .partial_sum(partial_sum[1][2]), .data_out(data_pass[1][3]), .result(partial_sum[1][3]));
    MAC u14 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[1][39:32]), .data(data_pass[1][3]), .partial_sum(partial_sum[1][3]), .data_out(data_pass[1][4]), .result(partial_sum[1][4]));

    // Row 2
    MAC u20 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[2][7:0]), .data(input_reg[2][0]), .partial_sum(16'b0), .data_out(data_pass[2][0]), .result(partial_sum[2][0]));
    MAC u21 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[2][15:8]), .data(data_pass[2][0]), .partial_sum(partial_sum[2][0]), .data_out(data_pass[2][1]), .result(partial_sum[2][1]));
    MAC u22 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[2][23:16]), .data(data_pass[2][1]), .partial_sum(partial_sum[2][1]), .data_out(data_pass[2][2]), .result(partial_sum[2][2]));
    MAC u23 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[2][31:24]), .data(data_pass[2][2]), .partial_sum(partial_sum[2][2]), .data_out(data_pass[2][3]), .result(partial_sum[2][3]));
    MAC u24 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[2][39:32]), .data(data_pass[2][3]), .partial_sum(partial_sum[2][3]), .data_out(data_pass[2][4]), .result(partial_sum[2][4]));

    // Row 3
    MAC u30 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[3][7:0]), .data(input_reg[3][0]), .partial_sum(16'b0), .data_out(data_pass[3][0]), .result(partial_sum[3][0]));
    MAC u31 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[3][15:8]), .data(data_pass[3][0]), .partial_sum(partial_sum[3][0]), .data_out(data_pass[3][1]), .result(partial_sum[3][1]));
    MAC u32 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[3][23:16]), .data(data_pass[3][1]), .partial_sum(partial_sum[3][1]), .data_out(data_pass[3][2]), .result(partial_sum[3][2]));
    MAC u33 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[3][31:24]), .data(data_pass[3][2]), .partial_sum(partial_sum[3][2]), .data_out(data_pass[3][3]), .result(partial_sum[3][3]));
    MAC u34 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[3][39:32]), .data(data_pass[3][3]), .partial_sum(partial_sum[3][3]), .data_out(data_pass[3][4]), .result(partial_sum[3][4]));

    // Row 4
    MAC u40 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[4][7:0]), .data(input_reg[4][0]), .partial_sum(16'b0), .data_out(data_pass[4][0]), .result(partial_sum[4][0]));
    MAC u41 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[4][15:8]), .data(data_pass[4][0]), .partial_sum(partial_sum[4][0]), .data_out(data_pass[4][1]), .result(partial_sum[4][1]));
    MAC u42 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[4][23:16]), .data(data_pass[4][1]), .partial_sum(partial_sum[4][1]), .data_out(data_pass[4][2]), .result(partial_sum[4][2]));
    MAC u43 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[4][31:24]), .data(data_pass[4][2]), .partial_sum(partial_sum[4][2]), .data_out(data_pass[4][3]), .result(partial_sum[4][3]));
    MAC u44 (.CLK(CLK), .RSTN(RSTN), .weight(weight_reg[4][39:32]), .data(data_pass[4][3]), .partial_sum(partial_sum[4][3]), .data_out(data_pass[4][4]), .result(partial_sum[4][4]));


endmodule

module MAC (CLK, RSTN, en, Weight, In, Acc, Out);
    input CLK;
    input RSTN;
    input [7:0] Weight;
    input [7:0] In;
    input [15:0] partial_sum;
    output reg [15:0] result;

    always @(posedge CLK or negedge RSTN) begin
        if(!RSTN) result <= 16'b0;
        else result <= partial_sum + Weight * In;
    end
endmodule