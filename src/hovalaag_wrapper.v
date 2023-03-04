/*
   Wrapper for the Hovalaag CPU.  This provides registers for the data coming in
   over the 6-bit in to populate, and exposes the outputs for the 8-bit output bus
   */

module HovalaagWrapper(
    input clk,     // Clock for the wrapper
    input reset,

    input [9:0] addr, // 1-hot.  
                      // Input:  0-4: Set instr bits 0-5, 6-11, 12-17, 18-23, 24-29
                      //           5: Instr bits 30-31 and execute
                      //         6-7: Set IN1 bits 0-5, 6-11  
                      //         8-9: Set IN2 bits 0-5, 6-11
                      // Output: 0-4: Low 8 bits of registers A-D, W for debugging
                      //           5: Execute status: 0: IN1 advance, 1: IN2 advance, 2: OUT1 valid, 3: OUT2 valid
                      //           6: New PC
                      //         7-9: OUT bits 0-7, 8-11, 0-7 (valid for OUT1 or OUT2 if one of the valid bits was set)
    input [5:0] in,   
    output [7:0] out,
);
    reg [29:0] instr;
    reg [11:0] in1;
    reg [11:0] in2;

    wire cpu_clk;
    wire in1_adv;
    wire in2_adv;
    wire [11:0] out;
    wire out_valid;
    wire out_select;
    wire [7:0] pc;

    wire [11:0] a_dbg;
    wire [11:0] b_dbg;
    wire [11:0] c_dbg;
    wire [11:0] d_dbg;

    assign cpu_clk = addr[5] && clk;

    Hovalaag hov (
        .clk(cpu_clk),
        .IN1(in1),
        .IN1_adv(in1_adv),
        .IN2(in2),
        .IN2_adv(in2_adv),
        .OUT(out),
        .OUT_valid(out_valid),
        .OUT_select(out_select),
        .instr({in[1:0], instr[29:0]}),
        .PC_out(pc),
        .rst(reset),

        .A_dbg(a_dbg),
        .B_dbg(b_dbg),
        .C_dbg(c_dbg),
        .D_dbg(d_dbg),
    );

    always @(posedge clk) begin
        if (reset) begin
            instr <= 0;
            in1 <= 0;
            in2 <= 0;
        end
        else begin
            case (addr)
            10'b0000000001: begin instr[ 5: 0] <= in; out <= a_dbg[7:0];  end
            10'b0000000010: begin instr[11: 6] <= in; out <= b_dbg[7:0];  end
            10'b0000000100: begin instr[17:12] <= in; out <= c_dbg[7:0];  end
            10'b0000001000: begin instr[23:18] <= in; out <= d_dbg[7:0];  end
            10'b0000010000: begin instr[29:24] <= in; out <= out[7:0];    end  // OUT is in fact always W.
            10'b0000100000: begin
                out[0] <= in1_adv;
                out[1] <= in2_adv;
                out[2] <= out_valid && !out_select;
                out[3] <= out_valid && out_select;
                out[7:4] <= 0;
            end
            10'b0001000000: begin in1[ 5: 0] <= in; out <= pc;        end
            10'b0010000000: begin in1[11: 6] <= in; out <= out[ 7: 0] end
            10'b0100000000: begin in2[ 5: 0] <= in; out <= { 4'b0000, out[11: 8] }; end
            10'b1000000000: begin in2[11: 6] <= in; out <= out[ 7: 0] end
            endcase
        end
    end

endmodule