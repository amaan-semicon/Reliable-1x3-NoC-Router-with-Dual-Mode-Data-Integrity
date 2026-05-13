`timescale 1ns / 1ps

module router_top (
    input  logic       clock,
    input  logic       resetn,
    input  logic       pkt_valid,
    input  logic [7:0] data_in,
    input  logic       read_enb_0,
    input  logic       read_enb_1,
    input  logic       read_enb_2,
    input  logic       parity_mode,

    output logic [7:0] data_out_0,
    output logic [7:0] data_out_1,
    output logic [7:0] data_out_2,
    output logic       vld_sync_0,
    output logic       vld_sync_1,
    output logic       vld_sync_2,
    output logic       err,
    output logic       busy,
    output logic       error_corrected,
    output logic [7:0] corrected_data
);

    // -------------------------------------------------------------------------
    // INTERNAL WIRES FOR INTERCONNECTION
    // -------------------------------------------------------------------------
    logic       soft_reset_0, soft_reset_1, soft_reset_2;
    logic       empty_0, empty_1, empty_2;
    logic       full_0, full_1, full_2;
    logic [2:0] write_enb;
    
    logic       fifo_full;
    logic       detect_add, ld_state, lfd_state, full_state, laf_state;
    logic       rst_int_reg, parity_done, low_packet_valid, write_enb_reg;
    
    logic [7:0] dout_to_fifo;
    logic [7:0] crc_out; // Internal tracking wire

    // -------------------------------------------------------------------------
    // 1. INSTANTIATE SYNCHRONIZER
    // -------------------------------------------------------------------------
    router_sync SYNC (
        .clock(clock),
        .resetn(resetn),
        .data_in(data_in[1:0]),
        .detect_add(detect_add),
        .write_enb_reg(write_enb_reg),
        .read_enb_0(read_enb_0),
        .read_enb_1(read_enb_1),
        .read_enb_2(read_enb_2),
        .empty_0(empty_0),
        .empty_1(empty_1),
        .empty_2(empty_2),
        .full_0(full_0),
        .full_1(full_1),
        .full_2(full_2),
        .write_enb(write_enb),
        .fifo_full(fifo_full),
        .vld_sync_0(vld_sync_0),
        .vld_sync_1(vld_sync_1),
        .vld_sync_2(vld_sync_2),
        .soft_reset_0(soft_reset_0),
        .soft_reset_1(soft_reset_1),
        .soft_reset_2(soft_reset_2)
    );

    // -------------------------------------------------------------------------
    // 2. INSTANTIATE FSM (Now fully 8-State connected)
    // -------------------------------------------------------------------------
    router_fsm FSM (
        .clock(clock),
        .resetn(resetn),
        .pkt_valid(pkt_valid),
        .data_in(data_in[1:0]),
        .fifo_full(fifo_full),
        .fifo_empty_0(empty_0),
        .fifo_empty_1(empty_1),
        .fifo_empty_2(empty_2),
        .soft_reset_0(soft_reset_0),
        .soft_reset_1(soft_reset_1),
        .soft_reset_2(soft_reset_2),
        .parity_done(parity_done),
        .low_packet_valid(low_packet_valid),
        .write_enb_reg(write_enb_reg),
        .detect_add(detect_add),
        .ld_state(ld_state),
        .lfd_state(lfd_state),
        .full_state(full_state),
        .laf_state(laf_state),    // Connected to the new 8th state!
        .rst_int_reg(rst_int_reg),
        .busy(busy)
    );

    // -------------------------------------------------------------------------
    // 3. INSTANTIATE REGISTER CRC-8
    // -------------------------------------------------------------------------
    register_crc8 REG_CRC (
        .clock(clock),
        .resetn(resetn),
        .pkt_valid(pkt_valid),
        .data_in(data_in),
        .fifo_full(fifo_full),
        .detect_add(detect_add),
        .ld_state(ld_state),
        .full_state(full_state),
        .laf_state(laf_state),
        .lfd_state(lfd_state),
        .rst_int_reg(rst_int_reg),
        .parity_mode(parity_mode),
        .dout(dout_to_fifo),
        .err(err),
        .parity_done(parity_done),
        .low_packet_valid(low_packet_valid),
        .crc_out(crc_out),
        .error_corrected(error_corrected),
        .corrected_data(corrected_data)
    );

    // -------------------------------------------------------------------------
    // 4. INSTANTIATE FIFO 0
    // -------------------------------------------------------------------------
    router_fifo FIFO_0 (
        .clock(clock),
        .resetn(resetn),
        .write_enb(write_enb[0]),
        .soft_reset(soft_reset_0),
        .read_enb(read_enb_0),
        .lfd_state(lfd_state),
        .data_in(dout_to_fifo),
        .empty(empty_0),
        .full(full_0),
        .data_out(data_out_0)
    );

    // -------------------------------------------------------------------------
    // 5. INSTANTIATE FIFO 1
    // -------------------------------------------------------------------------
    router_fifo FIFO_1 (
        .clock(clock),
        .resetn(resetn),
        .write_enb(write_enb[1]),
        .soft_reset(soft_reset_1),
        .read_enb(read_enb_1),
        .lfd_state(lfd_state),
        .data_in(dout_to_fifo),
        .empty(empty_1),
        .full(full_1),
        .data_out(data_out_1)
    );

    // -------------------------------------------------------------------------
    // 6. INSTANTIATE FIFO 2
    // -------------------------------------------------------------------------
    router_fifo FIFO_2 (
        .clock(clock),
        .resetn(resetn),
        .write_enb(write_enb[2]),
        .soft_reset(soft_reset_2),
        .read_enb(read_enb_2),
        .lfd_state(lfd_state),
        .data_in(dout_to_fifo),
        .empty(empty_2),
        .full(full_2),
        .data_out(data_out_2)
    );

endmodule