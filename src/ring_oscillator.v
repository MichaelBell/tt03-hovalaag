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
    input reset,
    output [COUNT_WIDTH-1:0] fast_count
);
    // 7 stage ring oscillator
    wire [6:0] c;

    // Ring of 7 inversions with reset.
`ifdef SIM
    assign #20 c[6] = ~c[5];
    assign #20 c[5] = ~c[4];
    assign #20 c[4] = ~c[3];
    assign #20 c[3] = ~c[2];
    assign #20 c[2] = ~c[1];
    assign #20 c[1] = ~c[0];
    assign #20 c[0] = reset ? 1'b0 : ~c[6];
`else
    sky130_fd_sc_hd__inv_1 inv6(.Y(c[6]), .A(c[5]));
    sky130_fd_sc_hd__inv_1 inv5(.Y(c[5]), .A(c[4]));
    sky130_fd_sc_hd__inv_1 inv4(.Y(c[4]), .A(c[3]));
    sky130_fd_sc_hd__inv_1 inv3(.Y(c[3]), .A(c[2]));
    sky130_fd_sc_hd__inv_1 inv2(.Y(c[2]), .A(c[1]));
    sky130_fd_sc_hd__inv_1 inv1(.Y(c[1]), .A(c[0]));
    assign c[0] = reset ? 1'b0 : ~c[6];
`endif

    // Divided output
    reg [1:0] out;

    always @(posedge c[6] or posedge reset) begin
        if (reset) begin
            out <= 2'b00;
        end else begin
            out <= out + 1;
        end
    end

    wire fast_clk;
    assign fast_clk = out[1];

    // Counter driven by divided output
    reg [COUNT_WIDTH-1:0] counter;

    always @(posedge fast_clk or posedge reset) begin
        if (reset) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
        end
    end    

    assign fast_count = counter;

endmodule