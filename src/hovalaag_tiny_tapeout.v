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

    reg addr[9:0];

    assign clk = in[0];
    assign reset = in[1] & in[2];

    HovalaagWrapper wrapper (
        clk(clk),
        reset(reset),
        addr(addr),
        in(io_in[7:2]),
        out(io_out[7:0])
    );

    always @(posedge clk) begin
        if (in[1] && (in[2] ||S in[3])) begin
            addr <= 1;
        end
        else begin
            addr <= { addr[8:0], addr[9] };
        end
    end

endmodule