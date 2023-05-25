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

/* Top module for the Hovalaag Tiny Tapeout
 *
 * IN: 0: CLK
 *     1: RESET_EN
 *   2-7: DATA if RESET_EN false
 *     2: RESET if RESET_EN true
 *     3: RESET address only
 */

module tt_um_MichaelBell_hovalaag (
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,  // IOs: Input path
  output wire [7:0] uio_out, // IOs: Output path
  output wire [7:0] uio_oe,  // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,
  input  wire       clk,
  input  wire       rst_n
);

    wire reset_enable = !rst_n;
    wire reset_n;
    reg reset_rosc_n;

    reg [2:0] addr;
    reg [2:0] next_addr;

    wire [11:0] io_in = {uio_in[3:0], ui_in[7:0]};
    wire [11:0] io_out;

    assign uo_out = io_out[7:0];
    assign uio_out[7:4] = io_out[11:8];

    // Top4 IOs are outputs, bottom 4 are inputs
    assign uio_oe = 8'b11110000;
    assign uio_out[3:0] = 4'b0000;

    assign reset_n = !(reset_enable && io_in[2]);

    wire [7:0] out_from_wrapper;

    HovalaagWrapper wrapper (
        .clk(clk),
        .reset_n(ena ? reset_n : 1'b0),
        .reset_rosc_n(ena ? reset_rosc_n : 1'b0),
        .addr(addr),
        .io_in(io_in),
        .io_out(io_out)
    );

    always @(posedge clk) begin
        if (reset_enable && io_in[4]) begin
            reset_rosc_n <= 1'b1;
        end
        else if (reset_enable) begin
            reset_rosc_n <= 1'b0;
        end 

        if (reset_enable && (io_in[2] || io_in[3])) begin
            next_addr <= 0;
        end
        else begin
            if (next_addr == 4) next_addr <= 0;
            else next_addr <= next_addr + 1;
        end
    end

`ifdef SIM
    always @(negedge clk) begin
        addr <= next_addr;
    end
`else
    genvar i;
    generate
        for (i = 0; i <= 2; i = i + 1) begin
            sky130_fd_sc_hd__dfrtn_1 addrff(.Q(addr[i]), .D(next_addr[i]), .CLK_N(clk), .RESET_B(1'b1));
        end
    endgenerate
`endif

endmodule