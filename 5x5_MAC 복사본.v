module 5X5_MAC (CLK, RSTN, Weight_i, In_i, OUT_o, VAL_o, OV_o);
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

    reg [8*(T+4)-1:0] in [0:4]; // 40-bit input

// Control Signal
    always @(posedge CLK) begin
        case(N)
            1 : vertical_en = 5'b10000;
            2 : vertical_en = 5'b11000;
            3 : vertical_en = 5'b11100;
            4 : vertical_en = 5'b11110;
            5 : vertical_en = 5'b11111;
        endcase
    end
    

// Datapath
    

    // Assign Weight 
    always @(posedge CLK) begin
        if(RSTN) begin
            w1 <= 0; w2 <= 0; w3 <= 0; w4 <= 0; w5 <= 0;
        end
        if(enW_i) begin
            w1 <= Weight_i;
            w2 <= w1;
            w3 <= w2;
            w4 <= w3;
            w5 <= w4;
        end
    end
    integer i;
    // Input -> reg
    always @(posedge CLK) begin
        if(RSTN) begin
            for (i=0; i<5; i=i+1) begin
                in[i] <= 0;
            end
        end
        if(enI_i) begin
            for(i=0; i<5; i=i+1) begin
                in[i][7:0] <= In_i[39-8*i:32-8*i];
                in[i] <= in[i] << 8;
            end 
        end

        for(i=0; i<5; i=i+1) begin
            in[i] <= in[i] >> i;
        end  
    end


    
    // Input -> Vertical
    always @(posedge CLK) begin
        if(RSTN) begin
        
        end
        if(enI_i) begin
        
        end
    end   

    // Accumulation -> Horizontal
    always @(posedge CLK) begin
        if(RSTN) begin
        
        end

    end

endmodule

module MAC (CLK, RSTN, en, Weight, In, Acc, Out);
    input CLK;
    input RSTN;
    input en;
    input [7:0] Weight;
    input [7:0] In;
    input [7:0] Acc;

    output reg [7:0] Out;

    always @(posedge CLK) begin
        if(RSTN) begin
            Out <= 0;
        end
        if(en) begin
            Out <= (Weight * In) + Acc;
        end
    end
endmodule