module tpuv1 #(
  parameter BITS_AB=8,
  parameter BITS_C=16,
  parameter DIM=8,
  parameter ADDRW=16,
  parameter DATAW=64,
) (
  input wire clk, rst_n,
  input wire r_w, // r_w=0 read, =1 write
  input wire [DATAW-1:0] dataIn,
  output wire [DATAW-1:0] dataOut,
  input wire [ADDRW-1:0] addr
);
  localparam ROWBITS = $clog2(DIM);

  // unpack inputs from dataIn
  wire signed [BITS_AB-1:0] Ain [DIM-1:0];
  wire signed [BITS_AB-1:0] Bin [DIM-1:0];
  genvar i;
  generate
    for (i = 0; i < DIM; i++) begin
      assign Ain[i] = dataIn[i*BITS_AB +: BITS_AB];
      assign Bin[i] = dataIn[i*BITS_AB +: BITS_AB];
    end
  endgenerate


  wire memA_en, memA_WrEn;
  wire [ROWBITS-1:0] Arow;
  memA #(.BITS_AB(BITS_AB), .DIM(DIM)) memory_A (
    .clk  (clk),
    .rst_n(rst_n),
    .en   (memA_en),
    .WrEn (memA_WrEn),
    .Ain  (Ain),
    .Arow (Arow),
    .Aout (Aout),
  );

  wire memB_en;
  memB #(.BITS_AB(BITS_AB), .DIM(DIM)) memory_B (
    .clk  (clk),
    .rst_n(rst_n),
    .en   (memB_en),
    .Bin  (Bin),
    .Bout (Bout)
  );

  always_comb begin
    // defaults
    memA_en = '0;
    memA_WrEn = '0;
    memB_en = '0;

    case (addr) inside
      // ALL ADDRESSES ARE ASSUMED TO BE 8-byte (64-bit) aligned!
      16'b0000000100??????: begin // A: 0x0100 – 0x013f
        memA_en = '1;
        memA_WrEn = '1;
        Arow = addr[5:4]; // ignore low 4 bits; assume alignment!
      end

      16'b0000001000?????? : begin // B: 0x0200 - 0x023f
        memB_en = '1;
      end

      16'b000000110??????? : begin // C: 0x0300 – 0x037f
      end

      16'h0400 : begin // MatMul
      end
    endcase
  end

endmodule; // tpuv1
