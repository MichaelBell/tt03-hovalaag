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
    #(parameter COUNT_WIDTH = 8, parameter STAGES=7)
(
    input reset_n,
    output [COUNT_WIDTH-1:0] fast_count
);
    wire [STAGES-1:0] c;

    // Ring of inversions with reset.
    genvar i;
    generate
        for (i = 1; i < STAGES; i = i + 1) begin
`ifdef SIM
            assign #20 c[i] = ~c[i-1];
`else
            sky130_fd_sc_hd__inv_1 inv1(.Y(c[i]), .A(c[i-1]));
`endif
        end
    endgenerate

`ifdef SIM
    assign #20 c[0] = reset_n ? ~c[STAGES-1] : 1'b0;
`else
    assign c[0] = reset_n ? ~c[STAGES-1] : 1'b0;
`endif

    reg [2:0] clk_div;

    always @(posedge c[STAGES-1] or negedge reset_n) begin
        if (!reset_n) begin
            clk_div[0] <= 1'b0;
        end else begin
            clk_div[0] <= ~clk_div[0];
        end
    end

    generate
    for (i = 1; i <= 2; i = i + 1) begin
        always @(posedge clk_div[i-1] or negedge reset_n) begin
            if (!reset_n) begin
                clk_div[i] <= 1'b0;
            end else begin
                clk_div[i] <= ~clk_div[i];
            end
        end
    end
    endgenerate

    wire fast_clk;
`ifdef SIM
    assign fast_clk = clk_div[2];
`else
    sky130_fd_sc_hd__clkbuf_8 fastclkbuf(.X(fast_clk), .A(clk_div[2]));
`endif

    // Counter driven by divided output
    reg [COUNT_WIDTH-1:0] counter;

    always @(posedge fast_clk or negedge reset_n) begin
        if (!reset_n) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
        end
    end    

    assign fast_count = counter;

endmodule