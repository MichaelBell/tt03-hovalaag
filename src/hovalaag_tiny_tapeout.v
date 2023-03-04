/* Top module for the Hovalaag Tiny Tapeout
 *
 * IN: 0: CLK
 *     1: RESET_EN
 *   2-7: DATA if RESET_EN false
 *     2: RESET if RESET_EN true
 *     3: RESET address only
 */

module MichaelBell_hovalaag (
  input [7:0] io_in,
  output [7:0] io_out
);
    wire clk;
    wire reset;

    reg [9:0] addr;

    assign clk = io_in[0];
    assign reset = io_in[1] && io_in[2];

    HovalaagWrapper wrapper (
        .clk(clk),
        .reset(reset),
        .addr(addr),
        .io_in(io_in[7:2]),
        .io_out(io_out[7:0])
    );

    always @(negedge clk) begin
        if (io_in[1] && (io_in[2] || io_in[3])) begin
            addr <= 1;
        end
        else begin
            addr <= { addr[8:0], addr[9] };
        end
    end

endmodule