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

    input [2:0] addr, // Input:  0-1: Set instr bits 0-11, 12-23
                      //           2: Instr bits 24-31 and execute
                      //           3: Set IN1
                      //           4: Set IN2
                      // Output: 0-1: Registers A, B
                      //           2: Execute status: 0: IN1 advance, 1: IN2 advance, 2: OUT1 valid, 3: OUT2 valid
                      //           3: New PC
                      //           4: OUT (valid for OUT1 or OUT2 if one of the valid bits was set)
    input [11:0] io_in,
    output [11:0] io_out
);
    reg [23:0] instr;
    reg [11:0] in1;
    reg [11:0] in2;

    wire in1_adv;
    wire in2_adv;
    wire [11:0] out;
    wire out_valid;
    wire out_select;
    wire [7:0] pc;

    wire [2:0] fast_count;
    reg [2:0] buffered_fast_count;
    reg [11:0] rng_bits;

    wire [11:0] a_dbg;
    wire [11:0] b_dbg;
    wire [11:0] c_dbg;
    wire [11:0] d_dbg;

    wire [6:0] seg7_out;

    Hovalaag hov (
        .clk(clk),
        .clk_en(addr == 2),
        .IN1(in1),
        .IN1_adv(in1_adv),
        .IN2(in2),
        .IN2_adv(in2_adv),
        .OUT(out),
        .instr({io_in[7:0], instr[23:0]}),
        .PC_out(pc),
        .rst(!reset_n),
        .alu_op_14_source(rng_bits),
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

    reg rosc_pause;

    RingOscillator #(.NUM_FAST_CLKS(3), .STAGES(11)) rosc (
        .reset_n(reset_rosc_n),
        .pause(rosc_pause),
        .fast_clk(fast_count)
    );

    always @(posedge clk) begin
        if (!reset_n) begin
            rosc_pause <= 1'b0;
            rng_bits <= 0;
        end else begin
            if (rosc_pause) begin
                rng_bits[11:3] <= rng_bits[8:0];
                rng_bits[2:0] <= buffered_fast_count[2:0];
            end
            rosc_pause <= ~rosc_pause;
        end
    end    

`ifdef SIM
    always @(negedge clk) begin
        buffered_fast_count[2:0] <= fast_count & {3{rosc_pause}};
    end
`else
    genvar i;
    generate
        for (i = 0; i < 3; i = i + 1) begin
            sky130_fd_sc_hd__dfrtn_1 addrff(.Q(buffered_fast_count[i]), .D(fast_count[i] && rosc_pause), .CLK_N(clk), .RESET_B(reset_n));
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
            0: instr[11: 0] <= io_in;
            1: instr[23:12] <= io_in;
            3: in1 <= io_in;
            4: in2 <= io_in;
            endcase
        end
    end

    function [11:0] get_out(input [2:0] addr);
        case (addr)
        0: get_out = a_dbg;
        1: get_out = b_dbg;
        2: begin
            get_out[0] = in1_adv;
            get_out[1] = in2_adv;
            get_out[2] = out_valid && !out_select;
            get_out[3] = out_valid && out_select;
            get_out[11:4] = 0;
        end
        3: get_out = pc;
        4: get_out = out;
        default: get_out = 12'bx;
        endcase
    endfunction

    assign io_out = get_out(addr);

endmodule