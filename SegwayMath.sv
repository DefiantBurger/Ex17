module SegwayMath (
    input logic signed [11:0] PID_cntrl,
    input logic [7:0] ss_tmr,
    input logic [11:0] steer_pot,
    input logic en_steer,
    input logic pwr_up,
    output logic signed [11:0] lft_spd, rght_spd,
    output logic too_fast
);
    logic signed [11:0] PID_ss;

    always_comb begin
        PID_ss = (20'(PID_cntrl) * ($signed({1'b0, ss_tmr}))) >>> 8; // cast PID_cntrl to 20 bit
    end

    logic [11:0] steer_pot_clamped;
    localparam logic signed [11:0] STEERING_OFFSET = 12'h7FF;
    logic signed [11:0] steer_val_unscaled;
    logic signed [11:0] steer_val;

    always_comb begin
        // limit between 0x200 & 0xE00
        steer_pot_clamped = (&steer_pot[11:9] && |steer_pot[8:0]) ? 12'hE00 :
                            (|steer_pot[11:9]) ? steer_pot : 12'h200;
        steer_val_unscaled = $signed({1'b0, steer_pot_clamped}) - STEERING_OFFSET;
        steer_val = (steer_val_unscaled >>> 3) + (steer_val_unscaled >>> 4); // * 3/16
    end

    logic signed [12:0] lft_torque;
    logic signed [12:0] rght_torque;
    logic signed [12:0] PID_ss_ext;
    logic signed [12:0] steer_val_ext_en;

    always_comb begin
        PID_ss_ext = {PID_ss[11], PID_ss};
        steer_val_ext_en = en_steer ? {steer_val[11], steer_val} : 0;
        lft_torque = PID_ss_ext + steer_val_ext_en;
        rght_torque = PID_ss_ext - steer_val_ext_en;
    end

    localparam logic signed [12:0] MIN_DUTY = 13'h00A8;
    localparam logic signed [6:0] LOW_TORQUE_BAND = 7'h2A;
    localparam logic signed [3:0] GAIN_MULT = 4'h4;
    logic signed [12:0] lft_torque_comp;
    logic signed [12:0] lft_shaped_pre_pwr_up;
    logic signed [12:0] lft_shaped;

    always_comb begin
        lft_torque_comp = lft_torque[12] ? lft_torque - MIN_DUTY : lft_torque + MIN_DUTY;
        lft_shaped_pre_pwr_up = (lft_torque > LOW_TORQUE_BAND || lft_torque < -LOW_TORQUE_BAND) ?
                                lft_torque_comp : lft_torque * GAIN_MULT;
        lft_shaped = pwr_up ? lft_shaped_pre_pwr_up : 13'h0000;
    end

    logic signed [12:0] rght_torque_comp;
    logic signed [12:0] rght_torque_shaped;
    logic signed [12:0] rght_shaped;

    always_comb begin
        rght_torque_comp = rght_torque[12] ? rght_torque - MIN_DUTY : rght_torque + MIN_DUTY;
        rght_torque_shaped = (rght_torque > LOW_TORQUE_BAND || rght_torque < -LOW_TORQUE_BAND) ?
                             rght_torque_comp : rght_torque * GAIN_MULT;
        rght_shaped = pwr_up ? rght_torque_shaped : 13'h0000;
    end

    saturate #(.IN_WIDTH(13), .OUT_WIDTH(12), .IS_SIGNED(1)) i_lft_spd_sat(
        .in_val(lft_shaped),
        .out_val(lft_spd)
    );
    saturate #(.IN_WIDTH(13), .OUT_WIDTH(12), .IS_SIGNED(1)) i_rght_spd_sat(
        .in_val(rght_shaped),
        .out_val(rght_spd)
    );

    localparam logic signed [12:0] TOO_FAST_THRESH = 13'sd1536;

    assign too_fast = (lft_shaped > TOO_FAST_THRESH) || (rght_shaped > TOO_FAST_THRESH);

endmodule
