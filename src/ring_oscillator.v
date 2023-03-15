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

/* Simple ring oscillator generating a fast clock */

module RingOscillator
    #(parameter COUNT_WIDTH = 8)
(
    input clk,
    input reset,
    output [COUNT_WIDTH-1:0] fast_count
);
    // 3 stage ring oscillator
    wire [2:0] c;
    wire c2_clkout;
    wire fast_clk;
    reg [2:0] reset_hold;

    // Divided output
    reg [2:0] out;

    always @(posedge clk) begin
        if (reset) begin
            reset_hold <= 3'b010;
        end else if (reset_hold[2:1] != 2'b00) begin
            reset_hold <= reset_hold + 1;
        end
    end

    // Ring of 3 inversions with reset.
`ifdef SIM
    assign #20 c[2] = ~c[1];
    assign #20 c[1] = ~c[0];
    assign #20 c[0] = reset ? 1'b0 : ~c[2];
    
    assign #1 c2_clkout = c[2];
    assign #1 fast_clk = out[2];
`else
    sky130_fd_sc_hd__inv_1 inv2(.Y(c[2]), .A(c[1]));
    sky130_fd_sc_hd__inv_1 inv1(.Y(c[1]), .A(c[0]));
    assign c[0] = reset ? 1'b0 : ~c[2];

    sky130_fd_sc_hd__clkbuf_1 c2clkbuf(.X(c2_clkout), .A(c[2]));
    sky130_fd_sc_hd__clkbuf_1 fastclkbuf(.X(fast_clk), .A(out[2]));
`endif

    always @(posedge c2_clkout) begin
        if (reset_hold[1]) begin
            out <= 3'b000;
        end else begin
            out <= out + 1;
        end
    end

    // Counter driven by divided output
    reg [COUNT_WIDTH-1:0] counter;

    always @(posedge fast_clk) begin
        if (reset_hold[2]) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
        end
    end    

    assign fast_count = counter;

endmodule