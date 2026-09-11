// Only for Icarus/ModelSim. Vivado already knows the real BUFG primitive,
// so do NOT add this file to the Vivado project.
`timescale 1ns/1ps
module BUFG (input I, output O);
    assign O = I;
endmodule
