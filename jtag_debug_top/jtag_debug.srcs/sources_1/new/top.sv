// jtag_top
`timescale 1ns / 1ps

import arty_pkg::*;

module jtag_top (
    input   clk_i,
    input   rst_i,

    //output  logic[3:0] led_g,
    output  logic sel,
    input   logic[1:0] sw,
    
    output logic[7:0] data_o,
    output logic[14:0] write_addr_o,
    // when we hit the reset state
    output logic reset_o
);
  logic clk;

  // logic old_sel;
  logic has_update = 0;
  logic has_reset = 0;

  always_comb begin
    //led_g[0] = SEL;
    //led_g[1] = UPDATE;
    //led_g[2] = has_reset;
    //led_g[3] = has_update;  // UPDATE;

    if (sw[1]) begin
      //led_b[0] = r_count[26];
      //led_b[1] = r_count[25];
      //led_b[2] = r_count[24];
      //led_b[3] = r_count[23];
    end else begin
      //led_b = 0;
    end
  end

  // BSCANE2: Boundary-Scan User Instruction
  //          Artix-7
  // Xilinx HDL Language Template, version 2024.2

  BSCANE2 #(
      .JTAG_CHAIN(3)  // Value for USER3 command, 0x22
      // .JTAG_CHAIN(1)  // Value for USER3 command, 0x02
  ) BSCANE2_inst (
      .CAPTURE(CAPTURE),  // 1-bit output: CAPTURE output from TAP controller.
      .DRCK(DRCK),       // 1-bit output: Gated TCK output. When SEL is asserted, DRCK toggles when CAPTURE or
                         // SHIFT are asserted.

      .RESET(RESET),  // 1-bit output: Reset output for TAP controller.
      .RUNTEST(), // 1-bit output: Output asserted when TAP controller is in Run Test/Idle state.
      .SEL(SEL),  // 1-bit output: USER instruction active output.
      .SHIFT(SHIFT),  // 1-bit output: SHIFT output from TAP controller.
      .TCK(TCK),  // 1-bit output: Test Clock output. Fabric connection to TAP Clock pin.
      .TDI(TDI),  // 1-bit output: Test Data Input (TDI) output from TAP controller.
      .TMS(),  // 1-bit output: Test Mode Select output. Fabric connection to TAP.
      .UPDATE(UPDATE),  // 1-bit output: UPDATE output from TAP controller
      .TDO(TDO)  // 1-bit input: Test Data Output (TDO) input for USER function.
  );

  // End of BSCANE2_inst instantiation

  // clocked registers
  logic [7:0] bs_shift_r;
  logic [2:0] bs_bit_count_r; 
  logic [14:0]     bs_addr_r;
  logic [31:0]     bs_mem_r;
  
  logic [14:0]     write_addr_r;
 
  // temporaries
  logic [7:0] bs_tmp; 
  logic [14:0]     bs_addr_next;
  
  assign TDO = bs_shift_r[0];
  assign bs_tmp = {TDI, bs_shift_r[7:1]};
  assign bs_addr_next = bs_addr_r+1;
  // When this is > len of imem, we know to start writing to dmem
  assign write_addr_o = write_addr_r;
  assign reset_o = RESET;
  assign sel = SEL;
  
  always @(posedge DRCK) begin
    if (CAPTURE) begin
      // possibly we can just do this here since we have to move through capture to get to shift
      bs_bit_count_r <= 0;
      bs_addr_r <= 0;
      bs_shift_r <= bs_mem_r[0];
      write_addr_r <= 0;
    end else if (RESET) begin
      bs_bit_count_r <= 0;
      bs_addr_r <= 0;
      bs_shift_r <= bs_mem_r[0];
      write_addr_r <= 0;
    end else if (SHIFT) begin
      bs_shift_r <= bs_tmp;                    // shift data out
      bs_bit_count_r <= bs_bit_count_r+1;      // wrapping 3 bit counter
      if (bs_bit_count_r == 7) begin           // at last bit
         write_addr_r <= write_addr_r + 1;     // output: how many bytes have we received
         data_o <= bs_tmp;
         bs_mem_r[bs_addr_r] <= bs_tmp;        // update current address in memory
         bs_shift_r <= bs_mem_r[bs_addr_next]; // load next address to shift register
         bs_addr_r <= bs_addr_next;            // update address
      end
    end
  end

  // just for debugging purpose
  always @(posedge TCK) begin
    if (UPDATE & SEL) begin
      has_update <= has_update ^ 1;
    end

    if (RESET) begin
      has_update <= 0;
      has_reset  <= has_reset ^ 1;
    end
  end

endmodule

// to program the FGPA
// openFPGALoader -b  arty jtag_debug/jtag_debug.runs/impl_1/top.bit, or
// cd scipts
// openocd -f program.cfg