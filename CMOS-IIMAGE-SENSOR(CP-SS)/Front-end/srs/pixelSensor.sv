`timescale 1ns/1ps


module PIXEL_SENSOR
(
  input  logic      VBN1,
  input  logic      RAMP,
  input  logic      RESET,
  input  logic      ERASE,
  input  logic      EXPOSE,
  input  logic      READ,
  inout  [7:0]      DATA
);

  // ---- analog-like params ----
  real  v_erase = 1.2;
  real  lsb     = v_erase/255.0;
  parameter real dv_pixel = 0.5;

  // ---- pixel state ----
  real  tmp;               // ?i?n áp pixel (mô ph?ng)
  real  adc;               // ramp analog (mô ph?ng)
  logic cmp;               // comparator tripped
  logic [7:0] p_data, next_p_data; // latch mã ??m

  // ---- ERASE + CONVERT (??ng b?) ----
  always_ff @(posedge RAMP or posedge ERASE) begin
    if (ERASE) begin
      tmp    <= v_erase;
      adc    <= 0.0;
      cmp    <= 1'b0;
      p_data <= 8'h00;
    end
    else begin
      adc <= adc + lsb;
      if (adc > tmp) cmp <= 1'b1;
      p_data <= next_p_data;    // c?p nh?t latch theo next-state
    end
  end

  // ---- EXPOSE (tích l?y ánh sáng) ----
  always_ff @(posedge VBN1) begin
    if (EXPOSE)
      tmp <= tmp - (dv_pixel*lsb * ({$random}%2));
  end

  // ---- next-state cho p_data ----
  always_comb begin
    next_p_data = p_data;       // m?c ??nh gi? nguyên
    if (!cmp)                   // tr??c khi comparator trip => bám DATA
      next_p_data = DATA;
  end

  // ---- READOUT ----
  // READ=1 -> pixel lái bus b?ng p_data; READ=0 -> nh? bus
  assign DATA = READ ? p_data : 8'bZ;

endmodule


