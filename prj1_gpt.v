module MatMul #(
    parameter int N = 5, // Number of columns in the weight matrix
    parameter int T = 10 // Number of columns in the input matrix
)
(
    input CLK,
    input RSTN,
    input start,
    input [39:0] Weight_i,
    input [39:0] In_i,
    output reg [79:0] OUT_o,
    output reg VAL_o,
    output reg OV_o
);

    parameter IDLE = 4'b0001,
              LOAD_WEIGHT = 4'b0010,
              LOAD_INPUT = 4'b0100,
              COMPUTE = 4'b1000;

    reg [3:0] present_state, next_state;
    reg [3:0] weight_counter, input_counter, compute_counter;

    reg [39:0] weight_temp [0:N-1];
    reg [8*T-1:0] input_temp [0:4];
    reg [8*(T+4)-1:0] input_reg [0:4];

    reg [15:0] partial_sum [0:4];
    reg [15:0] result [0:4];

    always @(posedge CLK or negedge RSTN) begin
        if (!RSTN)
            present_state <= IDLE;
        else
            present_state <= next_state;
    end

    always @(*) begin
        case (present_state)
            IDLE: begin
                if (start) next_state = LOAD_WEIGHT;
                else next_state = IDLE;
            end
            LOAD_WEIGHT: begin
                if (weight_counter == N-1) next_state = LOAD_INPUT;
                else next_state = LOAD_WEIGHT;
            end
            LOAD_INPUT: begin
                if (input_counter == T-1) next_state = COMPUTE;
                else next_state = LOAD_INPUT;
            end
            COMPUTE: begin
                next_state = IDLE;
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
                    if (weight_counter < N-1) weight_counter <= weight_counter + 1;
                    else weight_counter <= 0;
                end
                LOAD_INPUT: begin
                    if (input_counter < T-1) input_counter <= input_counter + 1;
                    else input_counter <= 0;
                end
                COMPUTE: begin
                    if (compute_counter < T-1) compute_counter <= compute_counter + 1;
                    else compute_counter <= 0;
                end
            endcase
        end
    end

    always @(posedge CLK) begin
        if (present_state == LOAD_WEIGHT) begin
            weight_temp[weight_counter] <= Weight_i;
        end else if (present_state == LOAD_INPUT) begin
            for (integer i = 0; i < 5; i = i + 1) begin
                // input_reg[i][input_counter*8 +: 8] <= In_i[8*i +: 8]; // from LSB to MSB
                input_reg[i][8*(T-1) - input_counter*8 -: 8] <= In_i[8*(4-i) +: 8]; // from MSB to LSB
            end 
        end
    end

    always @(posedge CLK) begin
        if (present_state == COMPUTE) begin
            for (i = 0; i < 5; i = i + 1) begin
                input_temp[i] <= input_reg[i] >> 8*i; // Shift input_reg[i] to the right by 8 bits
            end
        end
    end

    reg [7:0] Vin [0:4];
    always @(posedge CLK) begin
        if (present_state == COMPUTE) begin
            Vin[0] <= input_temp[0][8*(T+4) - compute_counter*8 -: 8];
            Vin[1] <= input_temp[1][8*(T+4) - compute_counter*8 -: 8];
            Vin[2] <= input_temp[2][8*(T+4) - compute_counter*8 -: 8];
            Vin[3] <= input_temp[3][8*(T+4) - compute_counter*8 -: 8];
            Vin[4] <= input_temp[4][8*(T+4) - compute_counter*8 -: 8];
        end
    end

    // Intermediate accumulation wires
    wire [15:0] acc11, acc12, acc13, acc14, acc15;
    wire [15:0] acc21, acc22, acc23, acc24, acc25;
    wire [15:0] acc31, acc32, acc33, acc34, acc35;
    wire [15:0] acc41, acc42, acc43, acc44, acc45;
    wire [15:0] acc51, acc52, acc53, acc54, acc55;

    // Intermediate vertical input wires
    wire [15:0] vin11, vin12, vin13, vin14, vin15;
    wire [15:0] vin21, vin22, vin23, vin24, vin25;
    wire [15:0] vin31, vin32, vin33, vin34, vin35;
    wire [15:0] vin41, vin42, vin43, vin44, vin45;
    wire [15:0] vin51, vin52, vin53, vin54, vin55;

    MAC u11 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[0][39:32]), .In(Vin[0]), .partial_sum(16'b0), .vertical_out(vin11), .result(acc11));
    MAC u12 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[0][31:24]), .In(Vin[1]), .partial_sum(acc11), .vertical_out(vin12), .result(acc12));
    MAC u13 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[0][23:16]), .In(Vin[2]), .partial_sum(acc12), .vertical_out(vin13), .result(acc13));
    MAC u14 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[0][15:8]), .In(Vin[3]), .partial_sum(acc13), .vertical_out(vin14),.result(acc14));
    MAC u15 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[0][7:0]), .In(Vin[4]), .partial_sum(acc14), .vertical_out(vin15),.result(acc15));

    MAC u21 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[1][39:32]), .In(vin11), .partial_sum(16'b0), .vertical_out(vin21), .result(acc21));
    MAC u22 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[1][31:24]), .In(vin12), .partial_sum(acc21), .vertical_out(vin22), .result(acc22));
    MAC u23 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[1][23:16]), .In(vin13), .partial_sum(acc22), .vertical_out(vin23), .result(acc23));
    MAC u24 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[1][15:8]), .In(vin14), .partial_sum(acc23), .vertical_out(vin24), .result(acc24));
    MAC u25 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[1][7:0]), .In(vin15), .partial_sum(acc24), .vertical_out(vin25),.result(acc25));

    MAC u31 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[2][39:32]), .In(vin21), .partial_sum(16'b0), .vertical_out(vin31), .result(acc31));
    MAC u32 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[2][31:24]), .In(vin22), .partial_sum(acc31), .vertical_out(vin32), .result(acc32));
    MAC u33 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[2][23:16]), .In(vin23), .partial_sum(acc32), .vertical_out(vin33), .result(acc33));
    MAC u34 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[2][15:8]), .In(vin24), .partial_sum(acc33), .vertical_out(vin34), .result(acc34));
    MAC u35 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[2][7:0]), .In(vin25), .partial_sum(acc34), .vertical_out(vin35), .result(acc35));

    MAC u41 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[3][39:32]), .In(vin31), .partial_sum(16'b0), .vertical_out(vin41), .result(acc41));
    MAC u42 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[3][31:24]), .In(vin32), .partial_sum(acc41), .vertical_out(vin42), .result(acc42));
    MAC u43 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[3][23:16]), .In(vin33), .partial_sum(acc42), .vertical_out(vin43), .result(acc43));
    MAC u44 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[3][15:8]), .In(vin34), .partial_sum(acc43), .vertical_out(vin44), .result(acc44));
    MAC u45 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[3][7:0]), .In(vin35), .partial_sum(acc44), .vertical_out(vin45), .result(acc45));

    MAC u51 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[4][39:32]), .In(vin41), .partial_sum(16'b0), .vertical_out(vin51), .result(acc51));
    MAC u52 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[4][31:24]), .In(vin42), .partial_sum(acc51), .vertical_out(vin52), .result(acc52));
    MAC u53 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[4][23:16]), .In(vin43), .partial_sum(acc52), .vertical_out(vin53), .result(acc53));
    MAC u54 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[4][15:8]), .In(vin44), .partial_sum(acc53), .vertical_out(vin54), .result(acc54));
    MAC u55 (.CLK(CLK), .RSTN(RSTN), .Weight(weight_temp[4][7:0]), .In(vin45), .partial_sum(acc54), .vertical_out(vin55), .result(acc55));

    // Assign outputs
    assign result1 = acc15;
    assign result2 = acc25;
    assign result3 = acc35;
    assign result4 = acc45;
    assign result5 = acc55;

    always @(posedge CLK or negedge RSTN) begin
        if (!RSTN) begin
            OUT_o <= 0;
            VAL_o <= 0;
            OV_o <= 0;
        end else if (present_state == COMPUTE) begin
            OUT_o <= {acc15, acc25, acc35, acc45, acc55};
            VAL_o <= 1;
            OV_o <= 0; // Placeholder for overflow logic, if needed
        end else begin
            VAL_o <= 0;
        end
    end

endmodule

module MAC (
    input CLK,
    input RSTN,
    input [7:0] Weight,
    input [7:0] In,
    input [15:0] partial_sum,
    output reg [7:0] vertical_out,
    output reg [15:0] result
);

    always @(posedge CLK or negedge RSTN) begin
        if (!RSTN)
            result <= 0;
        else
            vertical_out <= In;
            result <= partial_sum + (Weight * In);
    end

endmodule
