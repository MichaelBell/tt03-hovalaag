/* Copyright (C) 2023 Michael Bell

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

/*
   Wrapper for the Hovalaag CPU.  This provides registers for the data coming in
   over the 6-bit in to populate, and exposes the outputs for the 8-bit output bus
   */

module HovalaagWrapper(
    input clk,     // Clock for the wrapper
    input reset_n,
    input reset_rosc_n,

    input [3:0] addr, // Input:  0-4: Set instr bits 0-5, 6-11, 12-17, 18-23, 24-29
                      //           5: Instr bits 30-31 and execute
                      //         6-7: Set IN1 bits 0-5, 6-11  
                      //         8-9: Set IN2 bits 0-5, 6-11
                      // Output: 0-4: Low 8 bits of registers A-D, W for debugging
                      //           5: Execute status: 0: IN1 advance, 1: IN2 advance, 2: OUT1 valid, 3: OUT2 valid
                      //           6: New PC
                      //         7-8: OUT bits 0-7, 8-11 (valid for OUT1 or OUT2 if one of the valid bits was set)
                      //           9: OUT bits 0-3, 11 in 7-segment format (11 sets the 8th output)
    input [5:0] io_in,
    output [7:0] io_out
);
    parameter RNG_WIDTH = 12;

    reg [29:0] instr;
    reg [11:0] in1;
    reg [11:0] in2;

    wire in1_adv;
    wire in2_adv;
    wire [11:0] out;
    wire out_valid;
    wire out_select;
    wire [7:0] pc;

    wire [RNG_WIDTH-1:0] fast_count;
    reg [RNG_WIDTH-1:0] buffered_fast_count;

    wire [11:0] a_dbg;
    wire [11:0] b_dbg;
    wire [11:0] c_dbg;
    wire [11:0] d_dbg;

    wire [6:0] seg7_out;

    Hovalaag hov (
        .clk(clk),
        .clk_en(addr == 5),
        .IN1(in1),
        .IN1_adv(in1_adv),
        .IN2(in2),
        .IN2_adv(in2_adv),
        .OUT(out),
        .instr({io_in[1:0], instr[29:0]}),
        .PC_out(pc),
        .rst(!reset_n),
        .alu_op_14_source({{(12-RNG_WIDTH){1'b0}}, buffered_fast_count}),
        .alu_op_15_source(12'h001),

        .A_dbg(a_dbg),
        .B_dbg(b_dbg),
        .C_dbg(c_dbg),
        .D_dbg(d_dbg)
    );

    Seg7 seg7 (
        .value(out[3:0]),
        .seg_out(seg7_out)
    );

    RingOscillator #(.COUNT_WIDTH(RNG_WIDTH), .STAGES(17)) rosc (
        .reset_n(reset_rosc_n),
        .fast_count(fast_count)
    );

`ifdef SIM
    always @(negedge clk) begin
        buffered_fast_count <= fast_count;
    end
`else
    genvar i;
    generate
        for (i = 0; i < RNG_WIDTH; i = i + 1) begin
            sky130_fd_sc_hd__dfrtn_1 addrff(.Q(buffered_fast_count[i]), .D(fast_count[i]), .CLK_N(clk), .RESET_B(reset_n));
        end
    endgenerate
`endif

    // We want to use out valid and select before the result is clocked out,
    // so decode them directly here
    assign out_valid = instr[14];
    assign out_select = instr[13];

    always @(posedge clk) begin
        if (!reset_n) begin
            instr <= 0;
            in1 <= 0;
            in2 <= 0;
        end
        else begin
            case (addr)
            0: instr[ 5: 0] <= io_in;
            1: instr[11: 6] <= io_in;
            2: instr[17:12] <= io_in;
            3: instr[23:18] <= io_in;
            4: instr[29:24] <= io_in;
            6: in1[ 5: 0] <= io_in;
            7: in1[11: 6] <= io_in;
            8: in2[ 5: 0] <= io_in;
            9: in2[11: 6] <= io_in;
            endcase
        end
    end

    function [7:0] get_out(input [3:0] addr);
        case (addr)
        0: get_out = a_dbg[7:0];
        1: get_out = b_dbg[7:0];
        2: get_out = c_dbg[7:0];
        3: get_out = d_dbg[7:0];
        4: get_out = out[7:0];   // OUT is in fact always W.
        5: begin
            get_out[0] = in1_adv;
            get_out[1] = in2_adv;
            get_out[2] = out_valid && !out_select;
            get_out[3] = out_valid && out_select;
            get_out[7:4] = 0;
        end
        6: get_out = pc;
        7: get_out = out[ 7: 0];
        8: get_out = { 4'b0000, out[11: 8] };
        9: get_out = { out[11], seg7_out };
        default: get_out = 8'bx;
        endcase
    endfunction

    assign io_out = get_out(addr);

endmodule