module MatMul #(
    parameter int N = 5, // Number of columns in the weight matrix
    parameter int T = 10 // Number of columns in the input matrix
)
(CLK, RSTN, Weight_i, In_i, OUT_o, VAL_o, OV_o);
    input CLK;
    input RSTN;
    input [39:0] Weight_i;
    input [39:0] In_i;
    
    input N;
    input T;
    input enI_i;
    input enW_i;

    output reg [39:0] OUT_o;
    output reg VAL_o;
    output reg OV_o;

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
		if(!reset_b)
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

    MAC u1(CLK, RSTN, weight[0][7:0], input_reg[0][7:0], partial_sum[0], result[0]);
    MAC u1(CLK, RSTN, weight[1][7:0], input_reg[1][7:0], partial_sum[1], result[1]);
    MAC u1(CLK, RSTN, weight[2][7:0], input_reg[2][7:0], partial_sum[2], result[2]);
    MAC u1(CLK, RSTN, weight[3][7:0], input_reg[3][7:0], partial_sum[3], result[3]);
    MAC u1(CLK, RSTN, weight[4][7:0], input_reg[4][7:0], partial_sum[4], result[4]);

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

endmodule

module MAC (CLK, RSTN, en, Weight, In, Acc, Out);
    input CLK;
    input RSTN;
    input [7:0] Weight;
    input [7:0] In;
    input [15:0] partial_sum;
    output [15:0] result;

    always @(posedge CLK or negedge RSTN) begin
        if(!RSTN) result <= 16'b0;
        else result <= partial_sum + Weight * In;
    end
endmodule