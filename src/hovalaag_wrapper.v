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
    input [5:0] io_in,
    output [7:0] io_out
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
        .instr({io_in[1:0], instr[29:0]}),
        .PC_out(pc),
        .rst(reset),

        .A_dbg(a_dbg),
        .B_dbg(b_dbg),
        .C_dbg(c_dbg),
        .D_dbg(d_dbg)
    );

    always @(posedge clk) begin
        if (reset) begin
            instr <= 0;
            in1 <= 0;
            in2 <= 0;
        end
        else begin
            case (addr)
            10'b0000000001: instr[ 5: 0] <= io_in;
            10'b0000000010: instr[11: 6] <= io_in;
            10'b0000000100: instr[17:12] <= io_in;
            10'b0000001000: instr[23:18] <= io_in;
            10'b0000010000: instr[29:24] <= io_in;
            10'b0000010000: ;
            10'b0001000000: in1[ 5: 0] <= io_in;
            10'b0010000000: in1[11: 6] <= io_in;
            10'b0100000000: in2[ 5: 0] <= io_in;
            10'b1000000000: in2[11: 6] <= io_in;
            endcase
        end
    end

    function [7:0] get_out(input [9:0] addr);
        case (addr)
        10'b0000000001: get_out = a_dbg[7:0];
        10'b0000000010: get_out = b_dbg[7:0];
        10'b0000000100: get_out = c_dbg[7:0];
        10'b0000001000: get_out = d_dbg[7:0];
        10'b0000010000: get_out = out[7:0];   // OUT is in fact always W.
        10'b0000100000: begin
            get_out[0] = in1_adv;
            get_out[1] = in2_adv;
            get_out[2] = out_valid && !out_select;
            get_out[3] = out_valid && out_select;
            get_out[7:4] = 0;
        end
        10'b0001000000: get_out = pc;
        10'b0010000000: get_out = out[ 7: 0];
        10'b0100000000: get_out = { 4'b0000, out[11: 8] };
        10'b1000000000: get_out = out[ 7: 0];
        endcase
    endfunction

    assign io_out = get_out(addr);

endmodule