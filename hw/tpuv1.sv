module tpuv1 #(
  parameter BITS_AB=8,
  parameter BITS_C=16,
  parameter DIM=8,
  parameter ADDRW=16,
  parameter DATAW=64
) (
  input wire clk, rst_n,
  input wire r_w, // r_w=0 read, =1 write
  input wire [DATAW-1:0] dataIn,
  output logic [DATAW-1:0] dataOut,
  input wire [ADDRW-1:0] addr
);
  localparam ROWBITS = $clog2(DIM);

  /*------------------------------------------------------------------------------
  --  unpack inputs from dataIn
  ------------------------------------------------------------------------------*/
  logic zero_pad_AB;

  // wiring from dataIn to memories
  wire signed [BITS_AB-1:0] Ain [DIM-1:0];
  wire signed [BITS_AB-1:0] Bin [DIM-1:0];
  genvar i;
  generate
    for (i = 0; i < DATAW/BITS_AB; i++) begin
      assign Ain[i] = zero_pad_AB ? '0 : dataIn[i*BITS_AB +: BITS_AB];
      assign Bin[i] = zero_pad_AB ? '0 : dataIn[i*BITS_AB +: BITS_AB];
    end
  endgenerate

  // we can only fit 4 values of C into dataIn;
  // we register the low bytes from the previous transaction
  reg signed [BITS_C-1:0] Cin_lo [3:0];
  wire signed [BITS_C-1:0] Cin_hi [3:0];

  logic Cin_latch_lo;
  generate
    for (i = 0; i < 4; i++) begin
      // ff for low words of Cin
      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
          Cin_lo[i] <= '0;
        else if (Cin_latch_lo)
          Cin_lo[i] <= dataIn[i*BITS_C +: BITS_C];
      end

      // wiring for high words of Cin
      assign Cin_hi[i] = dataIn[i*BITS_C +: BITS_C];
    end
  endgenerate

  // form Cin
  wire signed [BITS_C-1:0] Cin [DIM-1:0];
  assign Cin = {Cin_hi, Cin_lo};


  /*------------------------------------------------------------------------------
  --  matmul time counter
  ------------------------------------------------------------------------------*/
  localparam MATMUL_CYCLES = DIM*3-2;
  logic [$clog2(MATMUL_CYCLES+2)-1:0] matmul_ctr;
  logic matmul_timer_start;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n | matmul_timer_start)
      matmul_ctr <= MATMUL_CYCLES+1;
    else if (matmul_ctr < MATMUL_CYCLES)
      matmul_ctr <= matmul_ctr + 1;
  end

  logic matmul_running;
  assign matmul_running = matmul_ctr < MATMUL_CYCLES;
  assign zero_pad_AB = (matmul_ctr > DIM) && matmul_running;

  /*------------------------------------------------------------------------------
  --  memories
  ------------------------------------------------------------------------------*/
  // wiring from memories to systolic array
  wire signed [BITS_AB-1:0] Aout [DIM-1:0];
  wire signed [BITS_AB-1:0] Bout [DIM-1:0];

  logic memA_en, memA_WrEn;
  logic [ROWBITS-1:0] Arow;
  memA #(.BITS_AB(BITS_AB), .DIM(DIM)) memory_A (
    .clk  (clk),
    .rst_n(rst_n),
    .en   (memA_en || matmul_running),
    .WrEn (memA_WrEn),
    .Ain  (Ain),
    .Arow (Arow),
    .Aout (Aout)
  );

  logic memB_en;
  memB #(.BITS_AB(BITS_AB), .DIM(DIM)) memory_B (
    .clk  (clk),
    .rst_n(rst_n),
    .en   (memB_en || matmul_running),
    .Bin  (Bin),
    .Bout (Bout)
  );

  /*------------------------------------------------------------------------------
  --  systolic array
  ------------------------------------------------------------------------------*/
  logic systolic_en;
  logic systolic_WrEn;
  logic [ROWBITS-1:0] Crow;
  wire signed [BITS_C-1:0] Cout [DIM-1:0];
  systolic_array #(
    .BITS_AB(BITS_AB), .BITS_C(BITS_C), .DIM(DIM)
  ) systolic_arr (
    .clk  (clk),
    .rst_n(rst_n),
    .en   (systolic_en | matmul_running),
    .WrEn (systolic_WrEn),

    .Crow (Crow),
    .Cin  (Cin),
    .Cout (Cout),

    .A    (Aout),
    .B    (Bout)
  );

  /*------------------------------------------------------------------------------
  --  address selection logic
  ------------------------------------------------------------------------------*/

  always_comb begin
    // defaults
    memA_en = '0;
    memA_WrEn = '0;
    memB_en = '0;
    Cin_latch_lo = '0;
    systolic_en = '0;
    systolic_WrEn = '0;
    Crow = '0;
    Arow = '0;
    dataOut = '0;


    if (r_w) begin // write
      case (addr) inside
        // ALL ADDRESSES ARE ASSUMED TO BE 8-byte (64-bit) aligned!
        16'b0000000100??????: begin // A: 0x0100 – 0x013f
          memA_en = '1;
          memA_WrEn = '1;
          Arow = addr[5:3]; // ignore low 4 bits; assume alignment!
        end

        16'b0000001000?????? : begin // B: 0x0200 - 0x023f
          memB_en = '1;
        end

        16'b000000110??????? : begin // C: 0x0300 – 0x037f
          Cin_latch_lo = '1; // always be latching
          systolic_WrEn = '1;
          Crow = addr[6:4];
        end

        16'h0400 : begin // MatMul
          matmul_timer_start = '1;
        end
      endcase
    end else begin // read
      case (addr) inside
        16'b000000110??????? : begin // C: 0x0300 – 0x037f
          Crow = addr[6:4];
          if (addr[3]) // high bytes of C
            dataOut = {Cout[7], Cout[6], Cout[5], Cout[4]};
          else
            dataOut = {Cout[3], Cout[2], Cout[1], Cout[0]};
        end
      endcase
    end
  end

endmodule // tpuv1
