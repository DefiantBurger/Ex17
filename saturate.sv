module saturate #(
    parameter int IN_WIDTH = 16,
    parameter int OUT_WIDTH = 10,
    parameter bit IS_SIGNED = 1
) (
    input logic [IN_WIDTH-1:0]  in_val,
    output  logic [OUT_WIDTH-1:0] out_val
);
    if (IS_SIGNED) begin
        localparam logic signed [OUT_WIDTH-1:0] MAX_VAL = (1 << (OUT_WIDTH - 1)) - 1;
        localparam logic signed [OUT_WIDTH-1:0] MIN_VAL = -(1 << (OUT_WIDTH - 1));

        wire sign_bit = in_val[IN_WIDTH-1];
        // fits_in checks whether the bits intended to be truncated are all 1s or all 0s
        wire fits_in = &in_val[IN_WIDTH-1 : OUT_WIDTH-1] ||
                      ~|in_val[IN_WIDTH-1 : OUT_WIDTH-1];

        assign out_val = fits_in ? in_val[OUT_WIDTH-1:0] :
                         sign_bit ? MIN_VAL : MAX_VAL;
    end else begin
        localparam logic [OUT_WIDTH-1:0] MAX_VAL = {OUT_WIDTH{1'b1}};

        assign out_val = (|in_val[IN_WIDTH-1:OUT_WIDTH]) ? MAX_VAL : in_val[OUT_WIDTH-1:0];
    end
endmodule