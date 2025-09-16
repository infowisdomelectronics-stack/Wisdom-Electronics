`timescale 1ns/1ps
`default_nettype none

module pixelArray_tb;

  // ---------------- Clock & reset ----------------
  logic clk = 0;
  logic reset = 0;
  parameter int clk_period = 10;                // 500ns -> 1 MHz clock
  parameter int sim_end    = clk_period * 2400;
  always #(clk_period) clk = ~clk;

  // ---------------- Pixel array DUT ----------------
  parameter int N = 2;                           // s? pixel (m?i pixel 8-bit)
  parameter real dv_pixel = 0.5;

  // "Analog-like" clocks
  logic anaBias1, anaRamp, anaReset;
  assign anaReset = 1'b1;                        // luôn enable reset analog (mô hình)

  // Digital controls
  logic erase, expose, convert;
  logic [3:0] read;

  // Tristate data bus t?i m?ng pixel
  tri  [(N*8-1):0] pixData;

  // DUT
  pixelArray #(.dv_pixel(dv_pixel)) dut (
    .VBN1     (anaBias1),
    .RAMP     (anaRamp),
    .RESET    (anaReset),
    .ERASE    (erase),
    .EXPOSE   (expose),
    .READ     (read),
    .DATA     (pixData)
  );

  // ---------------- FSM ----------------
  typedef enum logic [2:0] {ERASE_S, EXPOSE_S, CONVERT_S, READ_S, READ2_S, IDLE_S} state_e;
  state_e state, next_state;

  int counter;

  // Th?i l??ng t?ng pha (??n v?: chu k? clk)
  localparam int C_ERASE   = 5;
  localparam int C_EXPOSE  = 255;
  localparam int C_CONVERT = 255;
  localparam int C_READ    = 5;

  // Thanh ghi ?i?u khi?n (??ng ký ? posedge clk ?? không ?ua xung)
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state      <= IDLE_S;
      next_state <= ERASE_S;
      counter    <= 0;

      // outputs
      erase   <= 1'b0;
      expose  <= 1'b0;
      convert <= 1'b0;
      read    <= 4'b0000;
    end else begin
      // ---- state register ----
      if (state == IDLE_S) begin
        state   <= next_state;
        counter <= 0;
      end else begin
        counter <= counter + 1;
      end

      // ---- next-state logic ----
      unique case (state)
        ERASE_S:   if (counter == C_ERASE  ) begin next_state <= EXPOSE_S; state <= IDLE_S; end
        EXPOSE_S:  if (counter == C_EXPOSE ) begin next_state <= CONVERT_S; state <= IDLE_S; end
        CONVERT_S: if (counter == C_CONVERT) begin next_state <= READ_S;   state <= IDLE_S; end
        READ_S:    if (counter == C_READ   ) begin next_state <= READ2_S;  state <= IDLE_S; end
        READ2_S:   if (counter == C_READ   ) begin next_state <= ERASE_S;  state <= IDLE_S; end
        default: ;
      endcase

      // ---- registered outputs from state ----
      unique case (state)
        ERASE_S:   begin erase<=1; expose<=0; convert<=0; read<=4'b0000; end
        EXPOSE_S:  begin erase<=0; expose<=1; convert<=0; read<=4'b0000; end
        CONVERT_S: begin erase<=0; expose<=0; convert<=1; read<=4'b0000; end
        READ_S:    begin erase<=0; expose<=0; convert<=0; read<=4'b1100; end
        READ2_S:   begin erase<=0; expose<=0; convert<=0; read<=4'b0011; end
        IDLE_S:    begin erase<=0; expose<=0; convert<=0; read<=4'b0000; end
      endcase
    end
  end

  // ---------------- DAC/ADC model (ramp & data bus) ----------------
  // "Analog clocks" ???c l?y t? clk theo pha hi?n t?i
  assign anaRamp  = convert ? clk : 1'b0;        // ramp clock trong pha CONVERT
  assign anaBias1 = expose  ? clk : 1'b0;        // integration clock trong pha EXPOSE

  // Bus ??m s? phát vào DATA khi KHÔNG ??c pixel (READ==0)
  logic [7:0] data_byte;
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      data_byte <= 8'h00;
    end else if (convert) begin
      data_byte <= data_byte + 8'h01;
    end else begin
      data_byte <= 8'h00;
    end
  end

  // TB lái bus khi read==0; khi read!=0, nh? bus ?? pixel lái
  assign pixData = (read != 4'b0000) ? 'z : {N{data_byte}};

  // ---------------- Latch d? li?u ??c ra ----------------
  logic [(N*8-1):0] pixelDataOut;
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      pixelDataOut <= '0;
    end else if (read == 4'b1100 || read == 4'b0011) begin
      pixelDataOut <= pixData;                    // b?t d? li?u khi ?ang READ/READ2
    end
  end

  // ---------------- Testbench run ----------------
  initial begin
    reset = 1'b1;
    #(clk_period) reset = 1'b0;

    $dumpfile("pixelArray_tb.vcd");
    $dumpvars(0, pixelArray_tb);

    #(sim_end) $stop;
  end

endmodule
