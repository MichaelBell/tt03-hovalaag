`default_nettype none
`timescale 1ns/1ps

/*
this testbench just instantiates the module and makes some convenient wires
that can be driven / tested by the cocotb test.py
*/

module tb (
    // testbench is controlled by test.py
    input clk,
    input rst,
    input [11:0] data_in,
    output [11:0] data_out
   );

    // this part dumps the trace to a vcd file that can be viewed with GTKWave
    initial begin
        $dumpfile ("tb.vcd");
        $dumpvars (0, tb);
        #1;
    end

    // wire up the inputs and outputs
    wire [11:0] inputs = data_in;
    wire [7:0] outs;
    wire [7:0] io_out;
    wire [7:0] io_oe;

    // instantiate the DUT
    tt_um_MichaelBell_hovalaag uut(
`ifdef GL_TEST
        // for gatelevel testing we need to set up the power pins
        .vccd1(1'b1),
        .vssd1(1'b0),
`endif
        .clk(clk),
        .rst_n(!rst),
        .ena(1'b1),
        .ui_in  (inputs[7:0]),
        .uo_out (outs),
        .uio_in ({4'b0000, inputs[11:8]}),
        .uio_out(io_out),
        .uio_oe(io_oe)
        );

    assign data_out = {io_out[7:4], outs[7:0]};

endmodule
