`timescale 1ns / 1ps

module router_fsm (
    input  logic       clock,
    input  logic       resetn,
    input  logic       pkt_valid,
    input  logic [1:0] data_in,
    input  logic       fifo_full,
    input  logic       fifo_empty_0,
    input  logic       fifo_empty_1,
    input  logic       fifo_empty_2,
    input  logic       soft_reset_0,
    input  logic       soft_reset_1,
    input  logic       soft_reset_2,
    input  logic       parity_done,
    input  logic       low_packet_valid,

    output logic       write_enb_reg,
    output logic       detect_add,
    output logic       ld_state,
    output logic       lfd_state,
    output logic       laf_state,
    output logic       full_state,
    output logic       rst_int_reg,
    output logic       busy
);

  
    // 1. STATE DEFINITIONS

    typedef enum logic [2:0] {
        DECODE_ADDRESS     = 3'b000,
        WAIT_TILL_EMPTY    = 3'b001,
        LOAD_FIRST_DATA    = 3'b010,
        LOAD_DATA          = 3'b011,
        LOAD_PARITY        = 3'b100,
        FIFO_FULL_STATE    = 3'b101,
        CHECK_PARITY_ERROR = 3'b110,
        LOAD_AFTER_FULL    = 3'b111  
    } state_t;

    state_t present_state, next_state;
    
    // Internal register to remember the address 
    logic [1:0] addr;

   
    // 2. ADDRESS LATCH LOGIC
   
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            addr <= 2'b11; // 11 means invalid
        end
        else if ((present_state == DECODE_ADDRESS) && pkt_valid) begin
            addr <= data_in; // Save destination address
        end
    end

       // 3. STATE REGISTER
       always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            present_state <= DECODE_ADDRESS;
        end
        else if (soft_reset_0 || soft_reset_1 || soft_reset_2) begin
            present_state <= DECODE_ADDRESS; 
        end
        else begin
            present_state <= next_state;
        end
    end

    
    // 4. NEXT STATE LOGIC
       always_comb begin
        next_state = present_state; 

        case (present_state)
            
            DECODE_ADDRESS: begin
                if (pkt_valid) begin
                    if ((data_in == 2'b00 && fifo_empty_0) ||
                        (data_in == 2'b01 && fifo_empty_1) ||
                        (data_in == 2'b10 && fifo_empty_2)) begin
                        next_state = LOAD_FIRST_DATA;
                    end
                    else if ((data_in == 2'b00 && !fifo_empty_0) ||
                             (data_in == 2'b01 && !fifo_empty_1) ||
                             (data_in == 2'b10 && !fifo_empty_2)) begin
                        next_state = WAIT_TILL_EMPTY;
                    end
                end
            end

            WAIT_TILL_EMPTY: begin
                if ((addr == 2'b00 && fifo_empty_0) ||
                    (addr == 2'b01 && fifo_empty_1) ||
                    (addr == 2'b10 && fifo_empty_2)) begin
                    next_state = LOAD_FIRST_DATA;
                end
            end

            LOAD_FIRST_DATA: begin
                next_state = LOAD_DATA;
            end

            LOAD_DATA: begin
                if (fifo_full) begin
                    next_state = FIFO_FULL_STATE; // Jump to FULL state
                end
                else if (!fifo_full && !pkt_valid) begin
                    next_state = LOAD_PARITY;     // Data finished, go to parity
                end
                else begin
                    next_state = LOAD_DATA;       // Continue loading
                end
            end

            FIFO_FULL_STATE: begin
                if (!fifo_full) begin
                    // UPDATED: Do not go to LOAD_DATA directly! Go to LOAD_AFTER_FULL
                    next_state = LOAD_AFTER_FULL;
                end
            end

            // NEW STATE LOGIC: Handles the data left on the bus during backpressure
            
            LOAD_AFTER_FULL: begin
                if (!parity_done && !low_packet_valid) begin
                    next_state = LOAD_DATA;
                end
                else if (!parity_done && low_packet_valid) begin
                    next_state = LOAD_PARITY;
                end
                else if (parity_done) begin
                    next_state = DECODE_ADDRESS;
                end
            end

            LOAD_PARITY: begin
                next_state = CHECK_PARITY_ERROR;
            end

            CHECK_PARITY_ERROR: begin
                if (fifo_full)
                    next_state = FIFO_FULL_STATE;
                else
                    next_state = DECODE_ADDRESS;
            end
            
            default: next_state = DECODE_ADDRESS;
        endcase
    end

  
    // 5. OUTPUT ASSIGNMENTS
  
    
    assign detect_add    = (present_state == DECODE_ADDRESS);
    assign lfd_state     = (present_state == LOAD_FIRST_DATA);
    assign ld_state      = (present_state == LOAD_DATA);
    assign full_state    = (present_state == FIFO_FULL_STATE);
    assign rst_int_reg   = (present_state == CHECK_PARITY_ERROR);
    assign laf_state  = (present_state == LOAD_AFTER_FULL);
    // UPDATED: Write enable must also be HIGH during LOAD_AFTER_FULL to latch pending byte
    assign write_enb_reg = ((present_state == LOAD_DATA) || 
                            (present_state == LOAD_PARITY) || 
                            (present_state == LOAD_FIRST_DATA) ||
                            (present_state == LOAD_AFTER_FULL));
    
    // UPDATED: FSM is also busy during LOAD_AFTER_FULL
    assign busy = ((present_state == LOAD_FIRST_DATA) || 
                   (present_state == LOAD_PARITY) || 
                   (present_state == FIFO_FULL_STATE) || 
                   (present_state == LOAD_AFTER_FULL) ||
                   (present_state == WAIT_TILL_EMPTY) || 
                   (present_state == CHECK_PARITY_ERROR) ||
                   (present_state == DECODE_ADDRESS && pkt_valid));

endmodule
