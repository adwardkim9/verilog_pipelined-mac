module MatMul #(
    parameter N = 5, // Number of columns in the weight matrix
    parameter T = 10 // Number of columns in the input matrix
)
(
    input CLK,
    input RSTN,
    input signed [39:0] Weight_i,
    input signed [39:0] In_i,
    output reg signed [39:0] OUT_o,
    output reg VAL_o,
    output reg OV_o
);

    parameter IDLE = 4'b0001;
	parameter LOAD_WEIGHT = 4'b0010;
	parameter LOAD_INPUT = 4'b0100;
	parameter COMPUTE = 4'b1000;

    reg [3:0] present_state, next_state;
    reg [3:0] weight_counter, input_counter;
	reg [6:0] compute_counter;

    reg signed [39:0] weight_temp [0:4];
    reg signed [8*T-1:0] input_temp1, input_temp2, input_temp3, input_temp4, input_temp5;
    reg signed [8*(T+4)-1:0] input_reg1, input_reg2, input_reg3, input_reg4, input_reg5;

	reg signed [7:0] Vin1, Vin2, Vin3, Vin4, Vin5;
	
	reg signed [8*(T+3)-1:0] out_temp1, out_temp2, out_temp3, out_temp4, out_temp5;
	reg signed [8*T-1:0] out_reg1, out_reg2, out_reg3, out_reg4, out_reg5;
	
    reg ov1, ov2, ov3, ov4, ov5;
 
    always @(posedge CLK or negedge RSTN) begin
        if (!RSTN)
            present_state = IDLE;
        else
            present_state = next_state;
    end

    always @(posedge CLK) begin
        case(present_state)
            IDLE: begin
                if (Weight_i != 0) next_state = LOAD_WEIGHT;
                else next_state = IDLE;
            end
            LOAD_WEIGHT: begin
                if (Weight_i == 0) next_state = LOAD_INPUT;
                else next_state = LOAD_WEIGHT;
            end
            LOAD_INPUT: begin
                if (In_i == 0) next_state = COMPUTE;
                else next_state = LOAD_INPUT;
            end
            COMPUTE: begin
                if (compute_counter == N+T+7) next_state = IDLE;
				else next_state = COMPUTE;
            end
            default: next_state = IDLE;
        endcase
    end

    always @(posedge CLK or negedge RSTN) begin
        if (!RSTN) begin
            weight_counter <= 0;
            input_counter <= 0;
            compute_counter <= 0;
        end else begin
            case (present_state)
                LOAD_WEIGHT: begin
                    if (weight_counter < 6) weight_counter <= weight_counter + 1;
                    else weight_counter <= 0;
                end
                LOAD_INPUT: begin
                    if (input_counter < 11) input_counter <= input_counter + 1;
                    else input_counter <= 0;
                end
                COMPUTE: begin
                    if (compute_counter < N+T+7) compute_counter <= compute_counter + 1;
                    else if (compute_counter == N+T+7) compute_counter <= 0;
                end
            endcase
        end
    end
	
	integer i, j;
    always @(posedge CLK) begin
		if (present_state == IDLE) begin
			OUT_o <= 0; VAL_o <= 0; OV_o <= 0;
			weight_temp[0] <= 0; weight_temp[1] <= 0; weight_temp[2] <= 0; weight_temp[3] <= 0; weight_temp[4] <= 0;
			input_temp1 <= 0; input_temp2 <= 0; input_temp3 <= 0; input_temp4 <= 0; input_temp5 <= 0;
			input_reg1 <= 0; input_reg2 <= 0; input_reg3 <=0; input_reg4 <= 0; input_reg5 <= 0;
			Vin1 <= 0; Vin2 <= 0; Vin3 <= 0; Vin4 <= 0; Vin5 <= 0;
			out_temp1 <= 0; out_temp2 <= 0; out_temp3 <= 0; out_temp4 <= 0; out_temp5 <= 0;
			out_reg1 <= 0; out_reg2 <= 0; out_reg3 <= 0; out_reg4 <= 0; out_reg5 <= 0; 
			ov1 <= 0; ov2 <= 0; ov3 <= 0; ov4 <= 0; ov5 <=0;
		end else if (present_state == LOAD_WEIGHT) begin
			weight_temp[weight_counter] <= Weight_i;
		end else if (present_state == LOAD_INPUT) begin
            // input_reg[i][input_counter*8 +: 8] <= In_i[8*i +: 8]; // from LSB to MSB
            input_temp1[8*T-1 - input_counter*8 -: 8] <= In_i[39:32]; // from MSB to LSB
			input_temp2[8*T-1 - input_counter*8 -: 8] <= In_i[31:24];
			input_temp3[8*T-1 - input_counter*8 -: 8] <= In_i[23:16];
			input_temp4[8*T-1 - input_counter*8 -: 8] <= In_i[15:8];
			input_temp5[8*T-1 - input_counter*8 -: 8] <= In_i[7:0];
        end
    end

    always @(posedge CLK) begin
        if (present_state == COMPUTE) begin
            input_reg1 <= {input_temp1[8*T-1 -: 8*T],32'b0}; // Shift input_reg to the right by 8 bits
			input_reg2 <= {8'b0, input_temp2[8*T-1 -: 8*T],24'b0};
			input_reg3 <= {16'b0, input_temp3[8*T-1 -: 8*T], 16'b0};
			input_reg4 <= {24'b0, input_temp4[8*T-1 -: 8*T], 8'b0};
			input_reg5 <= {32'b0, input_temp5[8*T-1 -: 8*T]};
        end
    end

    always @(posedge CLK) begin
        if (present_state == COMPUTE) begin
            Vin1 <= input_reg1[8*(T+4)-1 - (compute_counter-2)*8 -: 8];
            Vin2 <= input_reg2[8*(T+4)-1 - (compute_counter-2)*8 -: 8];
            Vin3 <= input_reg3[8*(T+4)-1 - (compute_counter-2)*8 -: 8];
            Vin4 <= input_reg4[8*(T+4)-1 - (compute_counter-2)*8 -: 8];
            Vin5 <= input_reg5[8*(T+4)-1 - (compute_counter-2)*8 -: 8];
        end
    end

    // Intermediate accumulation wires
    wire [17:0] acc11, acc12, acc13, acc14, acc15;
    wire [17:0] acc21, acc22, acc23, acc24, acc25;
    wire [17:0] acc31, acc32, acc33, acc34, acc35;
    wire [17:0] acc41, acc42, acc43, acc44, acc45;
    wire [17:0] acc51, acc52, acc53, acc54, acc55;

    // Intermediate vertical input wires
    wire [7:0] vin11, vin12, vin13, vin14, vin15;
    wire [7:0] vin21, vin22, vin23, vin24, vin25;
    wire [7:0] vin31, vin32, vin33, vin34, vin35;
    wire [7:0] vin41, vin42, vin43, vin44, vin45;
    wire [7:0] vin51, vin52, vin53, vin54, vin55;
	
    MAC u11 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[0][39:32]), .In(Vin1), .partial_sum(18'b0), .vertical_out(vin11), .result(acc11));
    MAC u12 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[0][31:24]), .In(Vin2), .partial_sum(acc11), .vertical_out(vin12), .result(acc12));
    MAC u13 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[0][23:16]), .In(Vin3), .partial_sum(acc12), .vertical_out(vin13), .result(acc13));
    MAC u14 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[0][15:8]), .In(Vin4), .partial_sum(acc13), .vertical_out(vin14), .result(acc14));
    MAC u15 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[0][7:0]), .In(Vin5), .partial_sum(acc14), .vertical_out(vin15), .result(acc15));

    MAC u21 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[1][39:32]), .In(vin11), .partial_sum(18'b0), .vertical_out(vin21), .result(acc21));
    MAC u22 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[1][31:24]), .In(vin12), .partial_sum(acc21), .vertical_out(vin22), .result(acc22));
    MAC u23 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[1][23:16]), .In(vin13), .partial_sum(acc22), .vertical_out(vin23), .result(acc23));
    MAC u24 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[1][15:8]), .In(vin14), .partial_sum(acc23), .vertical_out(vin24), .result(acc24));
    MAC u25 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[1][7:0]), .In(vin15), .partial_sum(acc24), .vertical_out(vin25),.result(acc25));

    MAC u31 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[2][39:32]), .In(vin21), .partial_sum(18'b0), .vertical_out(vin31), .result(acc31));
    MAC u32 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[2][31:24]), .In(vin22), .partial_sum(acc31), .vertical_out(vin32), .result(acc32));
    MAC u33 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[2][23:16]), .In(vin23), .partial_sum(acc32), .vertical_out(vin33), .result(acc33));
    MAC u34 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[2][15:8]), .In(vin24), .partial_sum(acc33), .vertical_out(vin34), .result(acc34));
    MAC u35 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[2][7:0]), .In(vin25), .partial_sum(acc34), .vertical_out(vin35), .result(acc35));

    MAC u41 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[3][39:32]), .In(vin31), .partial_sum(18'b0), .vertical_out(vin41), .result(acc41));
    MAC u42 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[3][31:24]), .In(vin32), .partial_sum(acc41), .vertical_out(vin42), .result(acc42));
    MAC u43 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[3][23:16]), .In(vin33), .partial_sum(acc42), .vertical_out(vin43), .result(acc43));
    MAC u44 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[3][15:8]), .In(vin34), .partial_sum(acc43), .vertical_out(vin44), .result(acc44));
    MAC u45 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[3][7:0]), .In(vin35), .partial_sum(acc44), .vertical_out(vin45), .result(acc45));

    MAC u51 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[4][39:32]), .In(vin41), .partial_sum(18'b0), .vertical_out(vin51), .result(acc51));
    MAC u52 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[4][31:24]), .In(vin42), .partial_sum(acc51), .vertical_out(vin52), .result(acc52));
    MAC u53 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[4][23:16]), .In(vin43), .partial_sum(acc52), .vertical_out(vin53), .result(acc53));
    MAC u54 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[4][15:8]), .In(vin44), .partial_sum(acc53), .vertical_out(vin54), .result(acc54));
    MAC u55 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[4][7:0]), .In(vin45), .partial_sum(acc54), .vertical_out(vin55), .result(acc55));
	
	always @(posedge CLK) begin
		if (present_state == COMPUTE) begin
			// store result value to out_temp, out_reg -> print OUT_o
			case(N) // N = 3 : 6, N = 5 : 9
				1: begin
					out_temp1[8*(T+4)-1 - (compute_counter-N-3)*8 -: 8] <= acc11[7:0]; ov1 <= |acc11[17:8];
					out_temp2[8*(T+4)-1 - (compute_counter-N-4)*8 -: 8] <= acc21[7:0]; ov2 <= |acc21[17:8];
					out_temp3[8*(T+4)-1 - (compute_counter-N-5)*8 -: 8] <= acc31[7:0]; ov3 <= |acc31[17:8];
					out_temp4[8*(T+4)-1 - (compute_counter-N-6)*8 -: 8] <= acc41[7:0]; ov4 <= |acc41[17:8];
					out_temp5[8*(T+4)-1 - (compute_counter-N-7)*8 -: 8] <= acc51[7:0]; ov5 <= |acc51[17:8];
				end
				2: begin
					out_temp1[8*(T+4)-1 - (compute_counter-N-3)*8 -: 8] <= acc11[7:0]; ov1 <= |acc12[17:8];
					out_temp2[8*(T+4)-1 - (compute_counter-N-4)*8 -: 8] <= acc22[7:0]; ov2 <= |acc22[17:8];
					out_temp3[8*(T+4)-1 - (compute_counter-N-5)*8 -: 8] <= acc32[7:0]; ov3 <= |acc32[17:8];
					out_temp4[8*(T+4)-1 - (compute_counter-N-6)*8 -: 8] <= acc42[7:0]; ov4 <= |acc42[17:8];
					out_temp5[8*(T+4)-1 - (compute_counter-N-7)*8 -: 8] <= acc52[7:0]; ov5 <= |acc52[17:8];
				end
				3: begin
					out_temp1[8*(T+4)-1 - (compute_counter-N-3)*8 -: 8] <= acc13[7:0]; ov1 <= |acc13[17:8];
					out_temp2[8*(T+4)-1 - (compute_counter-N-4)*8 -: 8] <= acc23[7:0]; ov2 <= |acc23[17:8];
					out_temp3[8*(T+4)-1 - (compute_counter-N-5)*8 -: 8] <= acc33[7:0]; ov3 <= |acc33[17:8];
					out_temp4[8*(T+4)-1 - (compute_counter-N-6)*8 -: 8] <= acc43[7:0]; ov4 <= |acc43[17:8];
					out_temp5[8*(T+4)-1 - (compute_counter-N-7)*8 -: 8] <= acc53[7:0]; ov5 <= |acc53[17:8];
				end
				4: begin
					out_temp1[8*(T+4)-1 - (compute_counter-N-3)*8 -: 8] <= acc14[7:0]; ov1 <= |acc14[17:8];
					out_temp2[8*(T+4)-1 - (compute_counter-N-4)*8 -: 8] <= acc24[7:0]; ov2 <= |acc24[17:8];
					out_temp3[8*(T+4)-1 - (compute_counter-N-5)*8 -: 8] <= acc34[7:0]; ov3 <= |acc34[17:8];
					out_temp4[8*(T+4)-1 - (compute_counter-N-6)*8 -: 8] <= acc44[7:0]; ov4 <= |acc44[17:8];
					out_temp5[8*(T+4)-1 - (compute_counter-N-7)*8 -: 8] <= acc54[7:0]; ov5 <= |acc54[17:8];
				end
				5: begin
					out_temp1[8*(T+4)-1 - (compute_counter-N-3)*8 -: 8] <= acc15[7:0]; ov1 <= |acc15[17:8];
					out_temp2[8*(T+4)-1 - (compute_counter-N-4)*8 -: 8] <= acc25[7:0]; ov2 <= |acc25[17:8];
					out_temp3[8*(T+4)-1 - (compute_counter-N-5)*8 -: 8] <= acc35[7:0]; ov3 <= |acc35[17:8];
					out_temp4[8*(T+4)-1 - (compute_counter-N-6)*8 -: 8] <= acc45[7:0]; ov4 <= |acc45[17:8];
					out_temp5[8*(T+4)-1 - (compute_counter-N-7)*8 -: 8] <= acc55[7:0]; ov5 <= |acc55[17:8];
				end
			endcase
		end
    end
	
	always @(posedge CLK) begin
        if (present_state == COMPUTE) begin
			if(compute_counter >= N+8) begin
				VAL_o <= 1;
				OUT_o <= {out_temp1[8*(T+4)-1 - (compute_counter-N-8)*8 -: 8],
							out_temp2[8*(T+4)-1 - (compute_counter-N-8)*8 -: 8], 
							out_temp3[8*(T+4)-1 - (compute_counter-N-8)*8 -: 8],
							out_temp4[8*(T+4)-1 - (compute_counter-N-8)*8 -: 8],
							out_temp5[8*(T+4)-1 - (compute_counter-N-8)*8 -: 8]};
			end
		end
    end
			
	always @(posedge CLK or negedge RSTN) begin
        if (!RSTN) begin
            OUT_o <= 0;
            VAL_o <= 0;
            OV_o <= 0;
        end else if (present_state == COMPUTE) begin
			OV_o <= ov1 | ov2 | ov3 | ov4 | ov5;
			if(present_state == IDLE) VAL_o <= 0;
		end
	end
endmodule

module MAC (
    input CLK,
    input RSTN,
    input [7:0] Weight,
    input [7:0] In,
    input [17:0] partial_sum,
    output reg [7:0] vertical_out,
    output reg [17:0] result
);
	reg [15:0] mult_result;

    always @(posedge CLK or negedge RSTN) begin
        if (!RSTN)
            result <= 0;
        else
            vertical_out <= In;
			mult_result <= Weight * In;
            result <= partial_sum + {2'b0, mult_result};
    end

endmodule