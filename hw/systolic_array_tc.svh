// testcase for matrix-multiply systolic array
// provides parallelogram-shaped values for A,B based on cycle
class systolic_array_tc #(parameter BITS_AB=8,
                          parameter BITS_C=16,
                          parameter DIM=8
                          );
   bit signed [BITS_AB-1:0] A [DIM-1:0][DIM-1:0];
   bit signed [BITS_AB-1:0] B [DIM-1:0][DIM-1:0];
   bit signed [BITS_C-1:0] C [DIM-1:0][DIM-1:0];
   int                     cycle;
   
   function new();
      int                  Aval, Bval;
      // randomize A and B
      for(int Row=0;Row<DIM;++Row) begin
	     for(int Col=0;Col<DIM;++Col) begin
            Aval = $urandom();
            A[Row][Col] = {Aval[7:0]};
            Bval = $urandom();
            B[Row][Col] = {Bval[7:0]};
         end
      end
            
      // compute C based on A and B
      for(int Row=0;Row<DIM;++Row) begin
	     for(int Col=0;Col<DIM;++Col) begin
	        C[Row][Col] = {BITS_C{1'b0}};
	        for(int i=0;i<DIM;++i) begin
	           C[Row][Col] = C[Row][Col] + A[Row][i] * B[i][Col];
            end
         end
      end
   endfunction: new

   function int next_cycle();
      cycle = cycle + 1;
      return cycle;
   endfunction: next_cycle

   // this returns A entries in parallelogram format
   function bit signed [BITS_AB-1:0] get_next_A(int Row);
      int row_start = Row;
      int row_stop = Row + DIM - 1;
      bit signed [BITS_AB-1:0] retval = {BITS_AB{1'b0}};
      if ((cycle >= row_start) && (cycle <= row_stop)) begin
         retval =  A[Row][cycle-row_start];
      end

      //$display("Cycle %2d Return A[%d] = %d",cycle,Row,retval);
      
      return retval;
   endfunction:get_next_A

   // this returns B entries in parallelogram format
   function bit signed [BITS_AB-1:0] get_next_B(int Col);
      int col_start = Col;
      int col_stop = Col + DIM - 1;
      bit signed [BITS_AB-1:0] retval =  {BITS_AB{1'b0}};
      if ((cycle >= col_start) && (cycle <= col_stop)) begin
         retval =  B[cycle-col_start][Col];
      end

      //$display("Cycle %2d Return B[%d] = %d",cycle,Col,retval);
      
      return retval;
   endfunction: get_next_B

   function int check_row_C(int Row, logic signed [BITS_C-1:0] Cout [DIM-1:0]);
      int failures = 0;
      for(int Col=0;Col<DIM;++Col) begin
         //$display("check_row_C Row=%1d Col=%1d Cout=%5d C=%5d",
         //         Row,Col,Cout[Col],C[Row][Col]);
         
         if (Cout[Col] !== C[Row][Col]) begin
            ++failures;
         end
      end
      return failures;
   endfunction: check_row_C
   
   function void dump();
      // display A,B,C for debugging purposes
      $display("C = A x B");
      for(int Row=0;Row<DIM;++Row) begin
         for(int Col=0;Col<DIM;++Col) begin
            $write("%5d ",C[Row][Col]);
         end
         $write(" ");
         for(int Col=0;Col<DIM;++Col) begin
            $write("%4d ",A[Row][Col]);
         end
         $write(" ");
         for(int Col=0;Col<DIM;++Col) begin
            $write("%4d ",B[Row][Col]);
         end
         $write("\n");
      end // for (int Row=0;Row<DIM;++Row)
   endfunction: dump // dump
   
endclass; // systolic_array_tc
