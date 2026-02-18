module axi_cache_controller #(
  parameter int NO_OF_MASTERS = 4,
  parameter int NO_OF_SLAVES  = 2,

  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 64,
  parameter int ID_WIDTH = 4,

  parameter int CACHE_LINE_SIZE = 64, // bytes
  parameter int NUM_SETS = 64,
  parameter int ASSOCIATIVITY   = 4 ,
  parameter int NUM_MSHR  = 2
)(
  input  logic aclk,
  input  logic aresetn,

  // ---------------- Read interface ----------------
  input  logic rd_req_valid [NO_OF_MASTERS],
  input  logic [ADDR_WIDTH-1:0] rd_req_addr [NO_OF_MASTERS],
  input  logic [ID_WIDTH-1:0]   rd_req_id [NO_OF_MASTERS],
  input  logic [7:0] rd_req_len[NO_OF_MASTERS],
  input  logic [2:0]  rd_req_size [NO_OF_MASTERS],
  input  logic [1:0] rd_req_burst [NO_OF_MASTERS],

  output logic rd_ready [NO_OF_MASTERS],
  output logic rd_cache_hit [NO_OF_MASTERS],
  output logic rd_cache_miss [NO_OF_MASTERS],
  output logic [DATA_WIDTH-1:0] rd_cache_data  [NO_OF_MASTERS],
  output logic rd_data_valid [NO_OF_MASTERS],
  output logic [ID_WIDTH-1:0] rd_data_id [NO_OF_MASTERS], 
  output logic rd_data_last   [NO_OF_MASTERS],
  output logic [1:0] rd_resp [NO_OF_MASTERS],

 //----------------Writeinterface----------------
  input logic wr_req_valid [NO_OF_MASTERS],
  input logic [ADDR_WIDTH-1:0] wr_req_addr [NO_OF_MASTERS],
  input logic [ID_WIDTH-1:0] wr_req_id [NO_OF_MASTERS],
  input logic [7:0] wr_req_len [NO_OF_MASTERS],
  input logic [2:0] wr_req_size [NO_OF_MASTERS],
  input logic [1:0] wr_req_burst [NO_OF_MASTERS],
  input logic wr_data_valid [NO_OF_MASTERS],
  input logic [DATA_WIDTH-1:0] wr_data [NO_OF_MASTERS],
  input logic [(DATA_WIDTH/8)-1:0] wr_strb [NO_OF_MASTERS],
  input logic wr_data_last [NO_OF_MASTERS],
  output logic wr_req_ready [NO_OF_MASTERS],
  output logic wr_cache_hit [NO_OF_MASTERS],
  output logic wr_cache_miss [NO_OF_MASTERS],
  output logic wr_complete [NO_OF_MASTERS],
  output logic wr_resp_valid [NO_OF_MASTERS],
  output logic [1:0] wr_resp [NO_OF_MASTERS],

//----------------AXISlaveinterface----------------
  output logic [NO_OF_SLAVES-1:0] s_arvalid,
  input logic [NO_OF_SLAVES-1:0] s_arready,
  output logic [ADDR_WIDTH-1:0] s_araddr [NO_OF_SLAVES],
  output logic [ID_WIDTH-1:0] s_arid [NO_OF_SLAVES],
  output logic [7:0] s_arlen [NO_OF_SLAVES],
  output logic [2:0] s_arsize [NO_OF_SLAVES],
  output logic [1:0] s_arburst [NO_OF_SLAVES],
  input logic [NO_OF_SLAVES-1:0] s_rvalid,
  output logic [NO_OF_SLAVES-1:0] s_rready,
  input logic [DATA_WIDTH-1:0] s_rdata [NO_OF_SLAVES],
  input logic [ID_WIDTH-1:0] s_rid [NO_OF_SLAVES],
  input logic [NO_OF_SLAVES-1:0] s_rlast,
  input logic [1:0] s_rresp [NO_OF_SLAVES],
  output logic [NO_OF_SLAVES-1:0] s_awvalid,
  input logic [NO_OF_SLAVES-1:0] s_awready,
  output logic [ADDR_WIDTH-1:0] s_awaddr [NO_OF_SLAVES],
  output logic [ID_WIDTH-1:0] s_awid [NO_OF_SLAVES],
  output logic [7:0] s_awlen [NO_OF_SLAVES],
  output logic [2:0] s_awsize [NO_OF_SLAVES],
  output logic [1:0] s_awburst [NO_OF_SLAVES],
  output logic [NO_OF_SLAVES-1:0] s_wvalid,
  input logic [NO_OF_SLAVES-1:0] s_wready,
  output logic [DATA_WIDTH-1:0] s_wdata [NO_OF_SLAVES],
  output logic [(DATA_WIDTH/8)-1:0] s_wstrb [NO_OF_SLAVES],
  output logic [NO_OF_SLAVES-1:0] s_wlast,
  input logic [NO_OF_SLAVES-1:0] s_bvalid,
  output logic [NO_OF_SLAVES-1:0] s_bready,
  input logic [1:0] s_bresp [NO_OF_SLAVES]
 );

  //cache parameters
  localparam int OFFSET_BITS = $clog2(CACHE_LINE_SIZE);
  localparam int INDEX_BITS  = $clog2(NUM_SETS);
  localparam int TAG_BITS    = ADDR_WIDTH - OFFSET_BITS - INDEX_BITS;
  localparam int WORDS_PER_LINE = CACHE_LINE_SIZE / (DATA_WIDTH / 8);
  localparam int WORD_OFFSET_BITS = $clog2(WORDS_PER_LINE);

  //mshr_structure
  typedef struct{
    logic valid;
    logic is_write;
    logic done;
    logic [$clog2(NO_OF_MASTERS)-1:0] master;
    logic [ADDR_WIDTH-1:0] addr;
    logic [INDEX_BITS-1:0] index;
    logic [TAG_BITS-1:0] tag;
    logic [$clog2(ASSOCIATIVITY)-1:0] way;
    logic [$clog2(NO_OF_SLAVES)-1:0] slave;
    logic [$clog2(WORDS_PER_LINE)-1:0] beat;
    logic [ID_WIDTH-1:0] axi_id;
    logic needs_writeback;

    //Full line write buffer
    logic [DATA_WIDTH-1:0] wdata_buf [WORDS_PER_LINE];
    logic [(DATA_WIDTH/8)-1:0] wstrb_buf [WORDS_PER_LINE];
    logic [$clog2(WORDS_PER_LINE)-1:0] wbeat_count;

    logic [1:0] resp_code;
    logic ar_sent;
    logic wb_done;
    logic wb_error;  // Writeback failed
  } mshr_t;

  mshr_t mshr[NUM_MSHR];

  //  Track active R-channel MSHR per slave
  logic [$clog2(NUM_MSHR)-1:0] active_r_mshr [NO_OF_SLAVES];
  logic active_r_valid [NO_OF_SLAVES];

  // Read address decode signals
  logic [TAG_BITS-1:0] rd_tag [NO_OF_MASTERS];
  logic [INDEX_BITS-1:0] rd_index [NO_OF_MASTERS];
  logic [$clog2(WORDS_PER_LINE)-1:0] rd_word_idx [NO_OF_MASTERS];
  logic [$clog2(ASSOCIATIVITY)-1:0] rd_hit_way [NO_OF_MASTERS];

  // Write address decode signals
  logic [TAG_BITS-1:0] wr_tag [NO_OF_MASTERS];
  logic [INDEX_BITS-1:0] wr_index [NO_OF_MASTERS];
  logic [$clog2(WORDS_PER_LINE)-1:0] wr_word_idx [NO_OF_MASTERS];
  logic [$clog2(ASSOCIATIVITY)-1:0]  wr_hit_way [NO_OF_MASTERS];

  // Write data ownership
  logic w_locked;
  logic [$clog2(NO_OF_MASTERS)-1:0] w_owner;

  // Gated write signals
  logic wr_data_valid_g [NO_OF_MASTERS];
  logic wr_data_last_g  [NO_OF_MASTERS];
  logic [DATA_WIDTH-1:0] wr_data_g [NO_OF_MASTERS];
  logic [(DATA_WIDTH/8)-1:0] wr_strb_g [NO_OF_MASTERS];

  // WRITE-BACK FSM
  typedef enum logic [1:0] {
    WB_IDLE,
    WB_AW,
    WB_W,
    WB_RESP
  } wb_state_t;

  wb_state_t wb_state;
  logic wb_active;
  logic [$clog2(NUM_MSHR)-1:0] wb_mshr_id;
  logic [$clog2(WORDS_PER_LINE)-1:0] wb_beat;
  
  //mshr full
  logic mshr_full;

  // CACHE MEMORY STRUCTURE
  logic [TAG_BITS-1:0] tag_array [NUM_SETS][ASSOCIATIVITY];
  logic [DATA_WIDTH-1:0] data_array [NUM_SETS][ASSOCIATIVITY][WORDS_PER_LINE];
  logic valid_array [NUM_SETS][ASSOCIATIVITY];
  logic dirty_array [NUM_SETS][ASSOCIATIVITY];
  logic [7:0] lru_counter [NUM_SETS][ASSOCIATIVITY];

  integer s, w;
  genvar m;

  // ADDRESS BREAKDOWN FUNCTIONS
  function automatic logic [TAG_BITS-1:0] get_tag(
    input logic [ADDR_WIDTH-1:0] addr
  );
    return addr[ADDR_WIDTH-1 : OFFSET_BITS+INDEX_BITS];
  endfunction

  function automatic logic [INDEX_BITS-1:0] get_index(
    input logic [ADDR_WIDTH-1:0] addr
  );
    return addr[OFFSET_BITS+INDEX_BITS-1 : OFFSET_BITS];
  endfunction

  function automatic logic [OFFSET_BITS-1:0] get_offset(
    input logic [ADDR_WIDTH-1:0] addr
  );
    return addr[OFFSET_BITS-1:0];
  endfunction

  function automatic logic [$clog2(WORDS_PER_LINE)-1:0] get_word_index(
    input logic [ADDR_WIDTH-1:0] addr
  );
    logic [OFFSET_BITS-1:0] byte_offset;
    byte_offset = get_offset(addr);
    return byte_offset[OFFSET_BITS-1 : $clog2(DATA_WIDTH/8)];
  endfunction

  // SLAVE ADDRESS DECODE
  function automatic logic [$clog2(NO_OF_SLAVES)-1:0] decode_slave(
    input logic [ADDR_WIDTH-1:0] addr
  );
    logic [ADDR_WIDTH-1:0] region_size;
    logic [$clog2(NO_OF_SLAVES)-1:0] sid;
    region_size = (1 << ADDR_WIDTH) / NO_OF_SLAVES;
    sid = addr / region_size;
    if (sid >= NO_OF_SLAVES)
      sid = (NO_OF_SLAVES - 1);
    return sid;
  endfunction

  // VICTIM WAY SELECTION (LRU)
  function automatic logic [$clog2(ASSOCIATIVITY)-1:0] find_victim_way(
    input logic [INDEX_BITS-1:0] idx
  );
    logic [7:0] max_lru;
    logic [$clog2(ASSOCIATIVITY)-1:0] victim_way;

    for (int w = 0; w < ASSOCIATIVITY; w++) begin
      if (!valid_array[idx][w])
        return w[$clog2(ASSOCIATIVITY)-1:0];
    end

    max_lru = lru_counter[idx][0];
    victim_way = 0;

    for (int w = 1; w < ASSOCIATIVITY; w++) begin
      if (lru_counter[idx][w] > max_lru) begin
        max_lru = lru_counter[idx][w];
        victim_way = w[$clog2(ASSOCIATIVITY)-1:0];
      end
    end

    return victim_way;
  endfunction


  // MSHR FULL CHECK
  always_comb begin
    mshr_full = 1'b1;
    for (int i = 0; i < NUM_MSHR; i++) begin
      if (!mshr[i].valid)
        mshr_full = 1'b0;
    end
  end


  // READ READY SIGNAL
  always_comb begin
    for (int m = 0; m < NO_OF_MASTERS; m++) begin
      rd_ready[m] = 1'b0;
      
      if (rd_cache_hit[m]) begin
          rd_ready[m] = 1'b1;
      end
      else begin
        bit conflict;
        conflict = 1'b0;

        for (int i = 0; i < NUM_MSHR; i++) begin
          if (mshr[i].valid &&
              mshr[i].index == rd_index[m] &&
              mshr[i].tag   == rd_tag[m])
            conflict = 1'b1;
        end

        rd_ready[m] = (!mshr_full && !conflict);
      end
    end
  end


  // RESET LOGIC
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      for (s = 0; s < NUM_SETS; s++) begin
        for (w = 0; w < ASSOCIATIVITY; w++) begin
          valid_array[s][w] <= 1'b0;
          dirty_array[s][w] <= 1'b0;
          tag_array[s][w]   <= '0;
          lru_counter[s][w] <= '0;
        end
      end

      for (int i = 0; i < NUM_MSHR; i++) begin
        mshr[i].valid    <= 1'b0;
        mshr[i].done     <= 1'b0;
        mshr[i].ar_sent  <= 1'b0;
        mshr[i].wb_done  <= 1'b0;
        mshr[i].wb_error <= 1'b0;
      end

      for (int s = 0; s < NO_OF_SLAVES; s++) begin
        active_r_valid[s] <= 1'b0;
      end

      wb_state  <= WB_IDLE;
      wb_active <= 1'b0;
      w_locked  <= 1'b0;

     end
  end

  //==========================================================================
  // READ ADDRESS DECODE
  //==========================================================================
  generate
    for (m = 0; m < NO_OF_MASTERS; m++) begin : G_RD_ADDR_DECODE
      always_comb begin
        rd_tag[m]      = get_tag(rd_req_addr[m]);
        rd_index[m]    = get_index(rd_req_addr[m]);
        rd_word_idx[m] = get_word_index(rd_req_addr[m]);
      end
    end
  endgenerate

  //==========================================================================
  // READ HIT/MISS DETECTION 
  //==========================================================================

  function automatic bit line_under_refill(
    input logic [INDEX_BITS-1:0] idx,
    input logic [TAG_BITS-1:0]   tag
  );
    for (int i = 0; i < NUM_MSHR; i++) begin
      if (mshr[i].valid &&
          !mshr[i].done &&
          mshr[i].index == idx &&
          mshr[i].tag   == tag)
        return 1'b1;
    end
    return 1'b0;
  endfunction

  generate
    for (genvar m = 0; m < NO_OF_MASTERS; m++) begin 
      always_comb begin
        rd_cache_hit[m]  = 1'b0;
        rd_cache_miss[m] = 1'b0;
        rd_hit_way[m]    = '0;

        if (rd_req_valid[m]) begin
          for (int w = 0; w < ASSOCIATIVITY; w++) begin
            if (valid_array[rd_index[m]][w] &&
                tag_array[rd_index[m]][w] == rd_tag[m] &&

                // block read hit if line is under refill
                !line_under_refill(rd_index[m], rd_tag[m])) begin

              if (!(w_locked &&
                    wr_cache_hit[w_owner] &&
                    wr_index[w_owner] == rd_index[m] &&
                    wr_hit_way[w_owner] == w)) begin
                rd_cache_hit[m] = 1'b1;
                rd_hit_way[m]   = w[$clog2(ASSOCIATIVITY)-1:0];
              end
              break;
            end
          end
          rd_cache_miss[m] = ~rd_cache_hit[m];
        end
      end
    end
  endgenerate

  // LRU UPDATE
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      // Handled in main reset
    end
    else begin
      // Read hit LRU update
      for (int m = 0; m < NO_OF_MASTERS; m++) begin
        if (rd_cache_hit[m]) begin
          for (int w = 0; w < ASSOCIATIVITY; w++) begin
            if (lru_counter[rd_index[m]][w] < 8'hFF) begin
              lru_counter[rd_index[m]][w] <= lru_counter[rd_index[m]][w] + 1;
            end
          end
          lru_counter[rd_index[m]][rd_hit_way[m]] <= 8'h00;
        end
      end

      // Write hit LRU update 
      for (int m = 0; m < NO_OF_MASTERS; m++) begin
        if (wr_cache_hit[m] && wr_data_last_g[m] && (m == w_owner)) begin
          for (int w = 0; w < ASSOCIATIVITY; w++) begin
            if (lru_counter[wr_index[m]][w] < 8'hFF) begin
              lru_counter[wr_index[m]][w] <= lru_counter[wr_index[m]][w] + 1;
            end
          end
          lru_counter[wr_index[m]][wr_hit_way[m]] <= 8'h00;
        end
      end
    end
  end


  // WRITE ADDRESS DECODE
  generate
    for (m = 0; m < NO_OF_MASTERS; m++) begin
      always_comb begin
        wr_tag[m]      = get_tag(wr_req_addr[m]);
        wr_index[m]    = get_index(wr_req_addr[m]);
        wr_word_idx[m] = get_word_index(wr_req_addr[m]);
      end
    end
  endgenerate

  // WRITE HIT/MISS DETECTION
  generate
    for (m = 0; m < NO_OF_MASTERS; m++) begin
      always_comb begin
        wr_cache_hit[m]  = 1'b0;
        wr_cache_miss[m] = 1'b0;
        wr_hit_way[m]    = '0;

        if (wr_req_valid[m] && !wb_active) begin
          for (int w = 0; w < ASSOCIATIVITY; w++) begin
            if (valid_array[wr_index[m]][w] &&
                tag_array[wr_index[m]][w] == wr_tag[m]) begin
              wr_cache_hit[m] = 1'b1;
              wr_hit_way[m]   = w[$clog2(ASSOCIATIVITY)-1:0];
              break;
            end
          end
          wr_cache_miss[m] = ~wr_cache_hit[m];
        end
      end
    end
  endgenerate


  // WRITE REQUEST READY 
  always_comb begin
    for (int m = 0; m < NO_OF_MASTERS; m++) begin
      wr_req_ready[m] = 1'b0;

      if (wr_cache_hit[m]) begin
        wr_req_ready[m] = 1'b1;
      end
      else begin
        bit conflict;
        conflict = 1'b0;

        for (int i = 0; i < NUM_MSHR; i++) begin
          if (mshr[i].valid &&
              mshr[i].index == wr_index[m] &&
              mshr[i].tag   == wr_tag[m])
            conflict = 1'b1;
        end

        if (!mshr_full && !conflict)
          wr_req_ready[m] = 1'b1;
      end
    end
  end

  //==========================================================================
  // WRITE OWNERSHIP LOCK 
  //==========================================================================
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      w_locked <= 1'b0;
      w_owner  <= '0;
    end
    else begin
      // Acquire ownership
      if (!w_locked) begin
        for (int m = 0; m < NO_OF_MASTERS; m++) begin
          if (wr_req_valid[m] && wr_req_ready[m]) begin
            w_locked <= 1'b1;
            w_owner  <= m[$clog2(NO_OF_MASTERS)-1:0];
            break;
          end
        end
      end

      // Release ONLY when write is fully completed
      if (w_locked && wr_complete[w_owner]) begin
        w_locked <= 1'b0;
      end
    end
  end

  //==========================================================================
  // GATED WRITE SIGNALS
  //==========================================================================
  always_comb begin
    for (int m = 0; m < NO_OF_MASTERS; m++) begin
      if (w_locked && (w_owner == m)) begin
        wr_data_valid_g[m] = wr_data_valid[m];
        wr_data_last_g[m]  = wr_data_last[m];
        wr_data_g[m]       = wr_data[m];
        wr_strb_g[m]       = wr_strb[m];
      end
      else begin
        wr_data_valid_g[m] = 1'b0;
        wr_data_last_g[m]  = 1'b0;
        wr_data_g[m]       = '0;
        wr_strb_g[m]       = '0;
      end
    end
  end

  //==========================================================================
  // WRITE-HIT DATA UPDATE
  //==========================================================================
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      // No action
    end
    else begin
      for (int m = 0; m < NO_OF_MASTERS; m++) begin
        if (wr_cache_hit[m] && wr_data_valid_g[m] && (m == w_owner)) begin
          for (int b = 0; b < (DATA_WIDTH/8); b++) begin
            if (wr_strb_g[m][b]) begin
              data_array[wr_index[m]]
                        [wr_hit_way[m]]
                        [wr_word_idx[m]][8*b +: 8]
                <= wr_data_g[m][8*b +: 8];
            end
          end
          dirty_array[wr_index[m]][wr_hit_way[m]] <= 1'b1;
        end
      end
    end
  end

  //==========================================================================
  // UNIFIED MSHR ALLOCATION
  //==========================================================================
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      // Handled in main reset
    end
    else begin
      bit allocated;
      allocated = 1'b0;

      // PRIORITY 1: READ MISS
      for (int m = 0; m < NO_OF_MASTERS; m++) begin
        if (rd_req_valid[m] && rd_cache_miss[m] && !allocated && !mshr_full) begin

          bit conflict;
          conflict = 1'b0;
          for (int j = 0; j < NUM_MSHR; j++) begin
            if (mshr[j].valid &&
                mshr[j].index == rd_index[m] &&
                mshr[j].tag   == rd_tag[m]) begin
              conflict = 1'b1;
            end
          end

          if (!conflict) begin
            for (int i = 0; i < NUM_MSHR; i++) begin
              if (!mshr[i].valid && !allocated) begin
                automatic logic [$clog2(ASSOCIATIVITY)-1:0] vway;
                vway = find_victim_way(rd_index[m]);

                mshr[i].valid    <= 1'b1;
                mshr[i].is_write <= 1'b0;
                mshr[i].master   <= m[$clog2(NO_OF_MASTERS)-1:0];
                mshr[i].addr     <= rd_req_addr[m];
                mshr[i].index    <= rd_index[m];
                mshr[i].tag      <= rd_tag[m];
                mshr[i].way      <= vway;
                mshr[i].slave    <= decode_slave(rd_req_addr[m]);
                mshr[i].beat     <= '0;
                mshr[i].axi_id   <= rd_req_id[m];
                mshr[i].done     <= 1'b0;
                mshr[i].ar_sent  <= 1'b0;
                mshr[i].wb_done  <= 1'b0;
                mshr[i].wb_error <= 1'b0;
                mshr[i].resp_code <= 2'b00;
                mshr[i].wbeat_count <= '0;

                mshr[i].needs_writeback <=
                  valid_array[rd_index[m]][vway] &&
                  dirty_array[rd_index[m]][vway];

                allocated = 1'b1;
              end
            end
          end
        end
      end

      // PRIORITY 2: WRITE MISS
      for (int m = 0; m < NO_OF_MASTERS; m++) begin
        if (wr_req_valid[m] && wr_cache_miss[m] && !allocated && !mshr_full) begin

          bit conflict;
          conflict = 1'b0;
          for (int j = 0; j < NUM_MSHR; j++) begin
            if (mshr[j].valid &&
                mshr[j].index == wr_index[m] &&
                mshr[j].tag   == wr_tag[m]) begin
              conflict = 1'b1;
            end
          end

          if (!conflict) begin
            for (int i = 0; i < NUM_MSHR; i++) begin
              if (!mshr[i].valid && !allocated) begin
                automatic logic [$clog2(ASSOCIATIVITY)-1:0] vway;
                vway = find_victim_way(wr_index[m]);

                mshr[i].valid    <= 1'b1;
                mshr[i].is_write <= 1'b1;
                mshr[i].master   <= m[$clog2(NO_OF_MASTERS)-1:0];
                mshr[i].addr     <= wr_req_addr[m];
                mshr[i].index    <= wr_index[m];
                mshr[i].tag      <= wr_tag[m];
                mshr[i].way      <= vway;
                mshr[i].slave    <= decode_slave(wr_req_addr[m]);
                mshr[i].beat     <= '0;
                mshr[i].axi_id   <= wr_req_id[m];
                mshr[i].done     <= 1'b0;
                mshr[i].ar_sent  <= 1'b0;
                mshr[i].wb_done  <= 1'b0;
                mshr[i].wb_error <= 1'b0;
                mshr[i].resp_code <= 2'b00;
                mshr[i].wbeat_count <= '0;

                mshr[i].needs_writeback <=
                  valid_array[wr_index[m]][vway] &&
                  dirty_array[wr_index[m]][vway];

                // Initialize write buffer
                for (int wb = 0; wb < WORDS_PER_LINE; wb++) begin
                  mshr[i].wdata_buf[wb] <= '0;
                  mshr[i].wstrb_buf[wb] <= '0;
                end

                allocated = 1'b1;
              end
            end
          end
        end
      end
    end
  end

  //==========================================================================
  // WRITE-MISS DATA CAPTURE 
  //==========================================================================
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      // no action...
    end
    else begin
      for (int i = 0; i < NUM_MSHR; i++) begin
        if (mshr[i].valid && mshr[i].is_write) begin
          int m;
          m = mshr[i].master;

          if (wr_data_valid_g[m] && (m == w_owner)) begin
            automatic logic [$clog2(WORDS_PER_LINE)-1:0] base;
            automatic logic [$clog2(WORDS_PER_LINE)-1:0] widx;

            base = get_word_index(mshr[i].addr);
            widx = base + mshr[i].wbeat_count;

            // Protect against line overflow
            if (widx < WORDS_PER_LINE) begin
              mshr[i].wdata_buf[widx] <= wr_data_g[m];
              mshr[i].wstrb_buf[widx] <= wr_strb_g[m];
            end

            if (!wr_data_last_g[m])
              mshr[i].wbeat_count <= mshr[i].wbeat_count + 1;
          end
        end
      end
    end
  end

  //==========================================================================
  // WRITE-BACK FSM 
  //==========================================================================
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      wb_state   <= WB_IDLE;
      wb_active  <= 1'b0;
      wb_mshr_id <= '0;
      wb_beat    <= '0;
    end
    else begin
      case (wb_state)

        WB_IDLE: begin
          wb_active <= 1'b0;
          wb_beat   <= '0;

          for (int i = 0; i < NUM_MSHR; i++) begin
            if (mshr[i].valid && mshr[i].needs_writeback && !mshr[i].wb_done) begin
              wb_mshr_id <= i[$clog2(NUM_MSHR)-1:0];
              wb_state   <= WB_AW;
              wb_active  <= 1'b1;
              break;
            end
          end
        end

        WB_AW: begin
          if (s_awready[mshr[wb_mshr_id].slave]) begin
            wb_state <= WB_W;
            wb_beat  <= '0;
          end
        end

        WB_W: begin
          if (s_wready[mshr[wb_mshr_id].slave]) begin
            if (wb_beat == WORDS_PER_LINE-1) begin
              wb_state <= WB_RESP;
            end
            else begin
              wb_beat <= wb_beat + 1'b1;
            end
          end
        end

        WB_RESP: begin
          if (s_bvalid[mshr[wb_mshr_id].slave]) begin

          
            if (s_bresp[mshr[wb_mshr_id].slave] == 2'b00) begin
              // Successful writeback
              dirty_array[mshr[wb_mshr_id].index]
                         [mshr[wb_mshr_id].way] <= 1'b0;

              mshr[wb_mshr_id].needs_writeback <= 1'b0;
              mshr[wb_mshr_id].wb_done <= 1'b1;
              mshr[wb_mshr_id].wb_error <= 1'b0;
              
            end
            else begin
              // Writeback ERROR - keep dirty, mark error
              mshr[wb_mshr_id].wb_done  <= 1'b1;
              mshr[wb_mshr_id].wb_error <= 1'b1;
              mshr[wb_mshr_id].resp_code <= s_bresp[mshr[wb_mshr_id].slave];

              
              // Do NOT clear dirty or needs_writeback
              // Line remains dirty for potential retry
            end

            wb_state  <= WB_IDLE;
            wb_active <= 1'b0;
          end
        end
      endcase
    end
  end

  //==========================================================================
  // WRITE-BACK AXI SIGNALS
  //==========================================================================
  always_comb begin
    s_awvalid = '0;
    s_awaddr  = '{default:'0};
    s_awid    = '{default:'0};
    s_awlen   = '{default:'0};
    s_awsize  = '{default:3'b011};
    s_awburst = '{default:2'b01};

    s_wvalid  = '0;
    s_wdata   = '{default:'0};
    s_wstrb   = '{default:{(DATA_WIDTH/8){1'b1}}};
    s_wlast   = '0;

    s_bready  = '1;

    if (wb_active) begin
      int sid,idx,way;

      sid = mshr[wb_mshr_id].slave;
      idx = mshr[wb_mshr_id].index;
      way = mshr[wb_mshr_id].way;

      case (wb_state)

        WB_AW: begin
          s_awvalid[sid] = 1'b1;
          s_awaddr[sid]  = { tag_array[idx][way],
                             idx,
                             {OFFSET_BITS{1'b0}} };
          s_awid[sid]    = mshr[wb_mshr_id].axi_id;
          s_awlen[sid]   = WORDS_PER_LINE - 1;
        end

        WB_W: begin
          s_wvalid[sid] = 1'b1;
          s_wdata[sid]  = data_array[idx][way][wb_beat];
          s_wlast[sid]  = (wb_beat == WORDS_PER_LINE-1);
        end

        default: ;
      endcase
    end
  end

  //==========================================================================
  // AXI READ ADDRESS CHANNEL
  //==========================================================================
  always_comb begin
    s_arvalid = '0;
    s_araddr  = '{default:'0};
    s_arlen   = '{default:'0};
    s_arid    = '{default:'0};
    s_arsize  = '{default:3'b011};
    s_arburst = '{default:2'b01};

    for (int s = 0; s < NO_OF_SLAVES; s++) begin
      for (int i = 0; i < NUM_MSHR; i++) begin
        if (mshr[i].valid &&
            !mshr[i].ar_sent &&
            mshr[i].slave == s[$clog2(NO_OF_SLAVES)-1:0] &&
            (!mshr[i].needs_writeback || mshr[i].wb_done)) begin

          s_arvalid[s] = 1'b1;
          s_araddr[s]  = {mshr[i].addr[ADDR_WIDTH-1:OFFSET_BITS],
                         {OFFSET_BITS{1'b0}}};
          s_arlen[s]   = WORDS_PER_LINE - 1;
          s_arid[s]    = mshr[i].axi_id;
          break;
        end
      end
    end
  end

  //==========================================================================
  // AR SENT FLAG UPDATE
  //==========================================================================
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      // handled in reset
    end
    else begin
      for (int i = 0; i < NUM_MSHR; i++) begin
        if (mshr[i].valid &&
            !mshr[i].ar_sent &&
            s_arvalid[mshr[i].slave] &&
            s_arready[mshr[i].slave] &&
            (!mshr[i].needs_writeback || mshr[i].wb_done) &&
            !active_r_valid[mshr[i].slave]) begin

          mshr[i].ar_sent <= 1'b1;
          active_r_valid[mshr[i].slave] <= 1'b1;
          active_r_mshr[mshr[i].slave]  <= i[$clog2(NUM_MSHR)-1:0];
        end

        if (!mshr[i].valid)
          mshr[i].ar_sent <= 1'b0;
      end
    end
  end

  //==========================================================================
  // AXI READ DATA CHANNEL
  //==========================================================================
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      // Handled in main reset
    end
    else begin
      for (int s = 0; s < NO_OF_SLAVES; s++) begin
        if (active_r_valid[s]) begin
          int i;
          i = active_r_mshr[s];

          if (mshr[i].valid && s_rvalid[s] && s_rid[s] == mshr[i].axi_id) begin

            data_array[mshr[i].index][mshr[i].way][mshr[i].beat]
              <= s_rdata[s];

            mshr[i].beat <= mshr[i].beat + 1'b1;

            if (s_rresp[s] != 2'b00) begin
              mshr[i].resp_code <= s_rresp[s];
            end

            if (s_rlast[s]) begin

              if (mshr[i].resp_code == 2'b00) begin
                tag_array[mshr[i].index][mshr[i].way]   <= mshr[i].tag;
                valid_array[mshr[i].index][mshr[i].way] <= 1'b1;

                // Write-allocate merge (FIX ISSUE #4 - Use buffered data)
                if (mshr[i].is_write) begin
                  for (int wb = 0; wb < WORDS_PER_LINE; wb++) begin
                    for (int b = 0; b < DATA_WIDTH/8; b++) begin
                      if (mshr[i].wstrb_buf[wb][b]) begin
                        data_array[mshr[i].index][mshr[i].way][wb][8*b +: 8]
                          <= mshr[i].wdata_buf[wb][8*b +: 8];
                      end
                    end
                  end
                  dirty_array[mshr[i].index][mshr[i].way] <= 1'b1;
                end
                else begin
                  dirty_array[mshr[i].index][mshr[i].way] <= 1'b0;
                end
              end

              mshr[i].done <= 1'b1;
              active_r_valid[s] <= 1'b0;
            end
          end
        end
      end
    end
  end

  //==========================================================================
  // AXI READ READY
  //==========================================================================
  always_comb begin
    s_rready = '0;

    for (int s = 0; s < NO_OF_SLAVES; s++) begin
      if (active_r_valid[s]) begin
        s_rready[s] = 1'b1;
      end
    end
  end

  //==========================================================================
  // READ RESPONSE ROUTING (FIX: hit vs miss arbitration)
  //==========================================================================
  always_comb begin
  for (int m = 0; m < NO_OF_MASTERS; m++) begin
    rd_data_valid[m] = 1'b0;
    rd_data_last[m]  = 1'b0;
    rd_cache_data[m] = '0;
    rd_resp[m]       = 2'b00;
    rd_data_id[m]    = '0;
  end

  // 1) MSHR COMPLETION PRIORITY
  for (int i = 0; i < NUM_MSHR; i++) begin
    if (mshr[i].valid && mshr[i].done && !mshr[i].is_write) begin
      int m;
      m = mshr[i].master;

      rd_data_valid[m] = 1'b1;
      rd_data_last[m]  = 1'b1;
      rd_data_id[m]    = mshr[i].axi_id;
      rd_resp[m]       = mshr[i].resp_code;

      if (mshr[i].resp_code == 2'b00) begin
        rd_cache_data[m] =
          data_array[mshr[i].index][mshr[i].way]
                    [get_word_index(mshr[i].addr)];
      end

      break;
    end
  end

  // 2) READ HIT ONLY IF NO MSHR DONE
  for (int m = 0; m < NO_OF_MASTERS; m++) begin
    bit mshr_done_for_m;

    mshr_done_for_m = 1'b0;

    for (int i = 0; i < NUM_MSHR; i++) begin
      if (mshr[i].valid && mshr[i].done && mshr[i].master == m)
        mshr_done_for_m = 1'b1;
    end

    if (rd_cache_hit[m] && !mshr_done_for_m) begin
       rd_data_valid[m] = 1'b1;
       rd_data_last[m]  = 1'b1;
       rd_resp[m]       = 2'b00;
       rd_data_id[m]    = rd_req_id[m];
       rd_cache_data[m] =
         data_array[rd_index[m]][rd_hit_way[m]][rd_word_idx[m]];
    end
   end
  end

  //==========================================================================
  // WRITE RESPONSE GENERATION
  //==========================================================================
  always_comb begin
    for (int m = 0; m < NO_OF_MASTERS; m++) begin
      wr_complete[m]   = 1'b0;
      wr_resp_valid[m] = 1'b0;
      wr_resp[m]       = 2'b00;
    end

    // Priority: MSHR-based writes
    for (int i = 0; i < NUM_MSHR; i++) begin
      if (mshr[i].valid && mshr[i].done && mshr[i].is_write) begin
        int m;
        m = mshr[i].master;
        wr_complete[m]   = 1'b1;
        wr_resp_valid[m] = 1'b1;
        wr_resp[m]       = mshr[i].resp_code;
      end
    end

    // Write hit only if no MSHR exists
    for (int m = 0; m < NO_OF_MASTERS; m++) begin
      bit has_mshr;
      has_mshr = 1'b0;

      for (int i = 0; i < NUM_MSHR; i++) begin
        if (mshr[i].valid && mshr[i].master == m)
          has_mshr = 1'b1;
      end

      if (!has_mshr &&
          wr_cache_hit[m] &&
          wr_data_last_g[m] &&
          m == w_owner) begin
        wr_complete[m]   = 1'b1;
        wr_resp_valid[m] = 1'b1;
        wr_resp[m]       = 2'b00;
      end
    end
  end

  //==========================================================================
  // MSHR CLEANUP
  //==========================================================================
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      // reset handled elsewhere
    end
    else begin
      for (int i = 0; i < NUM_MSHR; i++) begin
        int m;
        m= mshr[i].master;

        if (mshr[i].done &&
            ((mshr[i].is_write && wr_resp_valid[m]) ||
             (!mshr[i].is_write && rd_data_valid[m]))) begin
          mshr[i].valid    <= 1'b0;
          mshr[i].done     <= 1'b0;
          mshr[i].ar_sent  <= 1'b0;
          mshr[i].wb_done  <= 1'b0;
        end
      end
    end
  end

 endmodule
