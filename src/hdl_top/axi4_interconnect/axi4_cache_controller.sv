module axi_cache_controller #(
  parameter int NO_OF_SLAVES    = 2,
  parameter int ADDRESS_WIDTH   = 32,
  parameter int DATA_WIDTH      = 32,
  parameter int ID_WIDTH        = 4,
  parameter int MASTER_BITS     = 2,
  parameter int EXT_ID_WIDTH    = ID_WIDTH + MASTER_BITS,
  parameter int SLAVE_MEM_SIZE  = 12,

  // Cache parameters
  parameter int CACHE_LINE_SIZE = 16,
  parameter int NUM_SETS        = 64,
  parameter int ASSOCIATIVITY   = 4,
  parameter int NUM_MSHR        = 4
)(
  input  logic aclk,
  input  logic aresetn,

  // WRITE ADDRESS (input from interconnect)
  input  logic [NO_OF_SLAVES-1:0]       cache_awvalid,
  output logic [NO_OF_SLAVES-1:0]       cache_awready,
  input  logic [EXT_ID_WIDTH-1:0]       cache_awid    [NO_OF_SLAVES],
  input  logic [ADDRESS_WIDTH-1:0]      cache_awaddr  [NO_OF_SLAVES],
  input  logic [7:0]                    cache_awlen   [NO_OF_SLAVES],
  input  logic [2:0]                    cache_awsize  [NO_OF_SLAVES],
  input  logic [1:0]                    cache_awburst [NO_OF_SLAVES],
  input  logic [3:0]                    cache_awcache [NO_OF_SLAVES],

  // WRITE DATA (input from interconnect)
  input  logic [NO_OF_SLAVES-1:0]       cache_wvalid,
  output logic [NO_OF_SLAVES-1:0]       cache_wready,
  input  logic [DATA_WIDTH-1:0]         cache_wdata   [NO_OF_SLAVES],
  input  logic [(DATA_WIDTH/8)-1:0]     cache_wstrb   [NO_OF_SLAVES],
  input  logic [NO_OF_SLAVES-1:0]       cache_wlast,

  // WRITE RESPONSE (output to interconnect)
  output logic [NO_OF_SLAVES-1:0]       cache_bvalid,
  input  logic [NO_OF_SLAVES-1:0]       cache_bready,
  output logic [EXT_ID_WIDTH-1:0]       cache_bid     [NO_OF_SLAVES],
  output logic [1:0]                    cache_bresp   [NO_OF_SLAVES],

  // READ ADDRESS (input from interconnect)
  input  logic [NO_OF_SLAVES-1:0]       cache_arvalid,
  output logic [NO_OF_SLAVES-1:0]       cache_arready,
  input  logic [EXT_ID_WIDTH-1:0]       cache_arid    [NO_OF_SLAVES],
  input  logic [ADDRESS_WIDTH-1:0]      cache_araddr  [NO_OF_SLAVES],
  input  logic [7:0]                    cache_arlen   [NO_OF_SLAVES],
  input  logic [2:0]                    cache_arsize  [NO_OF_SLAVES],
  input  logic [1:0]                    cache_arburst [NO_OF_SLAVES],
  input  logic [3:0]                    cache_arcache [NO_OF_SLAVES],

  // READ DATA (output to interconnect)
  output logic [NO_OF_SLAVES-1:0]       cache_rvalid,
  input  logic [NO_OF_SLAVES-1:0]       cache_rready,
  output logic [DATA_WIDTH-1:0]         cache_rdata   [NO_OF_SLAVES],
  output logic [EXT_ID_WIDTH-1:0]       cache_rid     [NO_OF_SLAVES],
  output logic [1:0]                    cache_rresp   [NO_OF_SLAVES],
  output logic [NO_OF_SLAVES-1:0]       cache_rlast,

  // WRITE ADDRESS (to slave)
  output logic [NO_OF_SLAVES-1:0]       s_awvalid,
  input  logic [NO_OF_SLAVES-1:0]       s_awready,
  output logic [ADDRESS_WIDTH-1:0]      s_awaddr  [NO_OF_SLAVES],
  output logic [EXT_ID_WIDTH-1:0]       s_awid    [NO_OF_SLAVES],
  output logic [7:0]                    s_awlen   [NO_OF_SLAVES],
  output logic [2:0]                    s_awsize  [NO_OF_SLAVES],
  output logic [1:0]                    s_awburst [NO_OF_SLAVES],
  output logic [3:0]                    s_awcache [NO_OF_SLAVES],

  // WRITE DATA (to slave)
  output logic [NO_OF_SLAVES-1:0]       s_wvalid,
  input  logic [NO_OF_SLAVES-1:0]       s_wready,
  output logic [DATA_WIDTH-1:0]         s_wdata   [NO_OF_SLAVES],
  output logic [(DATA_WIDTH/8)-1:0]     s_wstrb   [NO_OF_SLAVES],
  output logic [NO_OF_SLAVES-1:0]       s_wlast,

  // WRITE RESPONSE (from slave)
  input  logic [NO_OF_SLAVES-1:0]       s_bvalid,
  output logic [NO_OF_SLAVES-1:0]       s_bready,
  input  logic [1:0]                    s_bresp   [NO_OF_SLAVES],
  input  logic [EXT_ID_WIDTH-1:0]       s_bid     [NO_OF_SLAVES],

  // READ ADDRESS (to slave)
  output logic [NO_OF_SLAVES-1:0]       s_arvalid,
  input  logic [NO_OF_SLAVES-1:0]       s_arready,
  output logic [ADDRESS_WIDTH-1:0]      s_araddr  [NO_OF_SLAVES],
  output logic [EXT_ID_WIDTH-1:0]       s_arid    [NO_OF_SLAVES],
  output logic [7:0]                    s_arlen   [NO_OF_SLAVES],
  output logic [2:0]                    s_arsize  [NO_OF_SLAVES],
  output logic [1:0]                    s_arburst [NO_OF_SLAVES],
  output logic [3:0]                    s_arcache [NO_OF_SLAVES],

  // READ DATA (from slave)
  input  logic [NO_OF_SLAVES-1:0]       s_rvalid,
  output logic [NO_OF_SLAVES-1:0]       s_rready,
  input  logic [DATA_WIDTH-1:0]         s_rdata   [NO_OF_SLAVES],
  input  logic [EXT_ID_WIDTH-1:0]       s_rid     [NO_OF_SLAVES],
  input  logic [1:0]                    s_rresp   [NO_OF_SLAVES],
  input  logic [NO_OF_SLAVES-1:0]       s_rlast
);

  // =========================================================================
  // DERIVED PARAMETERS
  // =========================================================================
  localparam int OFFSET_BITS      = $clog2(CACHE_LINE_SIZE);
  localparam int INDEX_BITS       = $clog2(NUM_SETS);
  localparam int TAG_BITS         = ADDRESS_WIDTH - OFFSET_BITS - INDEX_BITS;
  localparam int WORDS_PER_LINE   = CACHE_LINE_SIZE / (DATA_WIDTH / 8);
  localparam int WORD_OFFSET_BITS = $clog2(WORDS_PER_LINE);

  // =========================================================================
  // INTERNAL SIGNAL ALIASES
  // =========================================================================
  logic [ADDRESS_WIDTH-1:0]    rd_req_addr  [NO_OF_SLAVES];
  logic [EXT_ID_WIDTH-1:0]     rd_req_id    [NO_OF_SLAVES];
  logic                        wr_req_valid [NO_OF_SLAVES];
  logic [ADDRESS_WIDTH-1:0]    wr_req_addr  [NO_OF_SLAVES];
  logic [EXT_ID_WIDTH-1:0]     wr_req_id    [NO_OF_SLAVES];
  logic                        wr_req_ready [NO_OF_SLAVES];
  logic                        wr_data_valid[NO_OF_SLAVES];
  logic                        wr_data_last [NO_OF_SLAVES];
  logic [DATA_WIDTH-1:0]       wr_data      [NO_OF_SLAVES];
  logic [(DATA_WIDTH/8)-1:0]   wr_strb      [NO_OF_SLAVES];

  always_comb begin
    for (int m = 0; m < NO_OF_SLAVES; m++) begin
      rd_req_addr[m]   = cache_araddr[m];
      rd_req_id[m]     = cache_arid[m];
      wr_req_valid[m]  = cache_awvalid[m];
      wr_req_addr[m]   = cache_awaddr[m];
      wr_req_id[m]     = cache_awid[m];
      wr_data_valid[m] = cache_wvalid[m];
      wr_data_last[m]  = cache_wlast[m];
      wr_data[m]       = cache_wdata[m];
      wr_strb[m]       = cache_wstrb[m];
    end
  end

  // =========================================================================
  // CACHE POLICY DECODE
  // =========================================================================
  typedef struct packed {
    logic write_back;
    logic write_through;
    logic read_allocate;
    logic write_allocate;
    logic cacheable;
    logic device;
    logic modifiable;
    logic bufferable;
  } axi_cache_policy_s;

  axi_cache_policy_s wr_policy [NO_OF_SLAVES];
  axi_cache_policy_s rd_policy [NO_OF_SLAVES];

  function automatic axi_cache_policy_s axi_decode_cache_policy(
    input logic [3:0] axcache,
    input logic       is_read
  );
    axi_cache_policy_s p;
    p = '{default: '0};
    p.bufferable = axcache[0];
    p.modifiable = axcache[1];
    if (axcache == 4'b0000 || axcache == 4'b0001) begin
      p.device     = 1'b1;
      p.modifiable = 1'b0;
      return p;
    end
    if (axcache[3:2] == 2'b00) begin
      p.cacheable = 1'b0;
      return p;
    end
    p.cacheable = 1'b1;
    case (axcache)
      4'b1010, 4'b0110, 4'b1110: p.write_through = 1'b1;
      4'b1011, 4'b0111, 4'b1111: p.write_back    = 1'b1;
      default:                    p.write_through = 1'b1;
    endcase
    if (is_read) p.read_allocate  = axcache[2];
    else         p.write_allocate = axcache[3];
    return p;
  endfunction

  always_comb begin
    for (int s = 0; s < NO_OF_SLAVES; s++) begin
      wr_policy[s] = axi_decode_cache_policy(cache_awcache[s], 1'b0);
      rd_policy[s] = axi_decode_cache_policy(cache_arcache[s], 1'b1);
    end
  end

  // =========================================================================
  // SLAVE ADDRESS DECODE
  // =========================================================================
  function automatic logic [$clog2(NO_OF_SLAVES)-1:0] decode_slave(
    input logic [ADDRESS_WIDTH-1:0] addr_in
  );
    logic [$clog2(NO_OF_SLAVES)-1:0] slave_id;
    slave_id = '1;
    for (int i = 0; i < NO_OF_SLAVES; i++) begin
      if (addr_in >= (i * (1 << SLAVE_MEM_SIZE)) &&
          addr_in <  ((i + 1) * (1 << SLAVE_MEM_SIZE))) begin
        slave_id = i;
        break;
      end
    end
    return slave_id;
  endfunction

  // =========================================================================
  // MSHR STRUCTURE
  // =========================================================================
  typedef struct {
    logic valid;
    logic is_write;
    logic done;
    logic [$clog2(NO_OF_SLAVES)-1:0]   master;
    logic [ADDRESS_WIDTH-1:0]           addr;
    logic [INDEX_BITS-1:0]              index;
    logic [TAG_BITS-1:0]                tag;
    logic [$clog2(ASSOCIATIVITY)-1:0]   way;
    logic [$clog2(NO_OF_SLAVES)-1:0]    slave;
    logic [$clog2(WORDS_PER_LINE)-1:0]  beat;
    logic [EXT_ID_WIDTH-1:0]            axi_id;
    logic needs_writeback;
    logic [DATA_WIDTH-1:0]              wdata_buf   [WORDS_PER_LINE];
    logic [(DATA_WIDTH/8)-1:0]          wstrb_buf   [WORDS_PER_LINE];
    logic [$clog2(WORDS_PER_LINE)-1:0]  wbeat_count;
    logic [1:0]  resp_code;
    logic ar_sent;
    logic wb_done;
    logic wb_error;
    logic wlast_seen;
    logic rlast_seen;
    logic [7:0] arlen;
    logic ar_pending;
  } mshr_t;

  mshr_t mshr [NUM_MSHR];

  logic [$clog2(NUM_MSHR)-1:0] active_r_mshr  [NO_OF_SLAVES];
  logic                         active_r_valid [NO_OF_SLAVES];

  // =========================================================================
  // ADDRESS DECODE FUNCTIONS
  // =========================================================================
  function automatic logic [TAG_BITS-1:0] get_tag(
    input logic [ADDRESS_WIDTH-1:0] addr
  );
    return addr[ADDRESS_WIDTH-1 : OFFSET_BITS+INDEX_BITS];
  endfunction

  function automatic logic [INDEX_BITS-1:0] get_index(
    input logic [ADDRESS_WIDTH-1:0] addr
  );
    return addr[OFFSET_BITS+INDEX_BITS-1 : OFFSET_BITS];
  endfunction

  function automatic logic [OFFSET_BITS-1:0] get_offset(
    input logic [ADDRESS_WIDTH-1:0] addr
  );
    return addr[OFFSET_BITS-1:0];
  endfunction

  function automatic logic [$clog2(WORDS_PER_LINE)-1:0] get_word_index(
    input logic [ADDRESS_WIDTH-1:0] addr
  );
    logic [OFFSET_BITS-1:0] byte_offset;
    byte_offset = get_offset(addr);
    return byte_offset[OFFSET_BITS-1 : $clog2(DATA_WIDTH/8)];
  endfunction

  // =========================================================================
  // ADDRESS BREAKDOWN SIGNALS
  // =========================================================================
  logic [TAG_BITS-1:0]               rd_tag      [NO_OF_SLAVES];
  logic [INDEX_BITS-1:0]             rd_index    [NO_OF_SLAVES];
  logic [$clog2(WORDS_PER_LINE)-1:0] rd_word_idx [NO_OF_SLAVES];
  logic [$clog2(ASSOCIATIVITY)-1:0]  rd_hit_way  [NO_OF_SLAVES];
  logic [7:0] rd_beat_count [NO_OF_SLAVES];   //for read data beat count tracking
    logic [ADDRESS_WIDTH-1:0]          rd_hit_addr_latched [NO_OF_SLAVES];
  logic [7:0]                        rd_hit_arlen_latched[NO_OF_SLAVES];
  logic [EXT_ID_WIDTH-1:0]           rd_hit_id_latched   [NO_OF_SLAVES];
  logic [$clog2(ASSOCIATIVITY)-1:0]  rd_hit_way_latched  [NO_OF_SLAVES];

  logic [TAG_BITS-1:0]               wr_tag      [NO_OF_SLAVES];
  logic [INDEX_BITS-1:0]             wr_index    [NO_OF_SLAVES];
  logic [$clog2(WORDS_PER_LINE)-1:0] wr_word_idx [NO_OF_SLAVES];
  logic [$clog2(ASSOCIATIVITY)-1:0]  wr_hit_way  [NO_OF_SLAVES];

  genvar gm;
  generate
    for (gm = 0; gm < NO_OF_SLAVES; gm++) begin : G_RD_ADDR_DECODE
      always_comb begin
        rd_tag[gm]      = get_tag(rd_req_addr[gm]);
        rd_index[gm]    = get_index(rd_req_addr[gm]);
        rd_word_idx[gm] = get_word_index(rd_req_addr[gm]);
      end
    end
  endgenerate

  generate
    for (gm = 0; gm < NO_OF_SLAVES; gm++) begin : G_WR_ADDR_DECODE
      always_comb begin
        wr_tag[gm]      = get_tag(wr_req_addr[gm]);
        wr_index[gm]    = get_index(wr_req_addr[gm]);
        wr_word_idx[gm] = get_word_index(wr_req_addr[gm]);
      end
    end
  endgenerate

  // =========================================================================
  // CACHE MEMORY ARRAYS
  // =========================================================================
  logic [TAG_BITS-1:0]   tag_array   [NUM_SETS][ASSOCIATIVITY];
  logic [DATA_WIDTH-1:0] data_array  [NUM_SETS][ASSOCIATIVITY][WORDS_PER_LINE];
  logic                  valid_array [NUM_SETS][ASSOCIATIVITY];
  logic                  dirty_array [NUM_SETS][ASSOCIATIVITY];
  logic [7:0]            lru_counter [NUM_SETS][ASSOCIATIVITY];

  // =========================================================================
  // HIT/MISS AND RESPONSE SIGNALS
  // =========================================================================
  logic rd_cache_hit  [NO_OF_SLAVES];
  logic rd_cache_miss [NO_OF_SLAVES];
  logic wr_cache_hit  [NO_OF_SLAVES];
  logic wr_cache_miss [NO_OF_SLAVES];

  logic                     rd_data_valid [NO_OF_SLAVES];
  logic                     rd_data_last  [NO_OF_SLAVES];
  logic [DATA_WIDTH-1:0]    rd_cache_data [NO_OF_SLAVES];
  logic [1:0]               rd_resp       [NO_OF_SLAVES];
  logic [EXT_ID_WIDTH-1:0]  rd_data_id    [NO_OF_SLAVES];

  logic                     wr_complete   [NO_OF_SLAVES];
  logic                     wr_resp_valid [NO_OF_SLAVES];
  logic [1:0]               wr_resp       [NO_OF_SLAVES];
  logic [EXT_ID_WIDTH-1:0]  wr_resp_id    [NO_OF_SLAVES];

  logic [EXT_ID_WIDTH-1:0]  wr_hit_id     [NO_OF_SLAVES];
  
  logic [$clog2(WORDS_PER_LINE)-1:0] wr_hit_beat [NO_OF_SLAVES]; 

  // =========================================================================
  // WRITE DATA OWNERSHIP
  // =========================================================================
  logic [NO_OF_SLAVES-1:0] w_locked;      // one bit per slave port
  logic [NO_OF_SLAVES-1:0] r_locked;
  logic [EXT_ID_WIDTH-1:0] w_locked_id [NO_OF_SLAVES];  // one id per slave port
  logic [ADDRESS_WIDTH-1:0] wr_latched_addr [NO_OF_SLAVES];
  logic w_locked_was_hit [NO_OF_SLAVES];
  
  logic                        wr_data_valid_g [NO_OF_SLAVES];
  logic                        wr_data_last_g  [NO_OF_SLAVES];
  logic [DATA_WIDTH-1:0]       wr_data_g       [NO_OF_SLAVES];
  logic [(DATA_WIDTH/8)-1:0]   wr_strb_g       [NO_OF_SLAVES];

  // =========================================================================
  // WB FSM STATE
  // =========================================================================
  typedef enum logic [1:0] {
    WB_IDLE, WB_AW, WB_W, WB_RESP
  } wb_state_t;

  wb_state_t                         wb_state;
  logic                              wb_active;
  logic [$clog2(NUM_MSHR)-1:0]       wb_mshr_id;
  logic [$clog2(WORDS_PER_LINE)-1:0] wb_beat;

  // =========================================================================
  // MSHR FULL FLAG  (combinational)
  // =========================================================================
  logic mshr_full;
  always_comb begin
    mshr_full = 1'b1;
    for (int i = 0; i < NUM_MSHR; i++)
      if (!mshr[i].valid) mshr_full = 1'b0;
  end

// Modified find_victim_way — takes way_being_used as input ref
function automatic logic [$clog2(ASSOCIATIVITY)-1:0] find_victim_way(
  input logic [INDEX_BITS-1:0] idx,
  ref   bit                    way_being_used [NUM_SETS][ASSOCIATIVITY]
);
  logic [7:0] max_lru;
  logic [$clog2(ASSOCIATIVITY)-1:0] victim_way;

   // Mark ways already owned by in-flight MSHRs for this index
  for (int i = 0; i < NUM_MSHR; i++) begin
    if (mshr[i].valid && mshr[i].index == idx)
      way_being_used[idx][mshr[i].way] = 1'b1;  // already in use
  end

  // First: prefer invalid ways not yet claimed this cycle
  for (int w = 0; w < ASSOCIATIVITY; w++) begin
    if (!valid_array[idx][w] && !way_being_used[idx][w]) begin
      way_being_used[idx][w] = 1'b1;
      return w[$clog2(ASSOCIATIVITY)-1:0];
    end
  end
  // All ways valid: pick LRU way not yet claimed this cycle
  max_lru    = '0;
  victim_way = '0;
  for (int w = 0; w < ASSOCIATIVITY; w++) begin
    if (!way_being_used[idx][w]) begin
      if (lru_counter[idx][w] >= max_lru) begin
        max_lru    = lru_counter[idx][w];
        victim_way = w[$clog2(ASSOCIATIVITY)-1:0];
      end
    end
  end
  way_being_used[idx][victim_way] = 1'b1;
  return victim_way;
endfunction

  // =========================================================================
  // LINE-UNDER-REFILL HELPER
  // =========================================================================
  function automatic bit line_under_refill(
    input logic [INDEX_BITS-1:0] idx,
    input logic [TAG_BITS-1:0]   tag
  );
    for (int i = 0; i < NUM_MSHR; i++) begin
      if (mshr[i].valid && !mshr[i].done &&
          mshr[i].index == idx && mshr[i].tag == tag)
        return 1'b1;
    end
    return 1'b0;
  endfunction

  // =========================================================================
  // READ HIT / MISS DETECTION  (combinational)
  // =========================================================================
  generate
    for (genvar gm = 0; gm < NO_OF_SLAVES; gm++) begin : G_RD_HIT
      always_comb begin
        rd_cache_hit[gm]  = 1'b0;
        rd_cache_miss[gm] = 1'b0;
        rd_hit_way[gm]    = '0;
        if (cache_arvalid[gm] || r_locked) begin    //added r_locked
          for (int w = 0; w < ASSOCIATIVITY; w++) begin
            if (valid_array[rd_index[gm]][w] &&
                tag_array[rd_index[gm]][w] == rd_tag[gm] &&
                !line_under_refill(rd_index[gm], rd_tag[gm])) begin
              if (!(w_locked[gm] && wr_cache_hit[gm] && wr_index[gm] == rd_index[gm] && wr_hit_way[gm] == w[$clog2(ASSOCIATIVITY)-1:0])) begin
                rd_cache_hit[gm] = 1'b1;
                rd_hit_way[gm]   = w[$clog2(ASSOCIATIVITY)-1:0];
              end
              break;
            end
          end
          rd_cache_miss[gm] = ~rd_cache_hit[gm];
          $display("CACHE_DEBUG [%0t] slave=%0d arvalid=%0b set_index=%0d tag=%0h -> HIT=%0b MISS=%0b WAY=%0d",$time, gm,cache_arvalid[gm],rd_index[gm], rd_tag[gm],rd_cache_hit[gm], rd_cache_miss[gm], rd_hit_way[gm]);
        end
      end
    end
  endgenerate

  // =========================================================================
  // WRITE HIT / MISS DETECTION  (combinational)
  // =========================================================================
  generate
    for (genvar gm = 0; gm < NO_OF_SLAVES; gm++) begin : G_WR_HIT
      logic [ADDRESS_WIDTH-1:0] eff_addr;
      always_comb begin
        wr_cache_hit[gm]  = 1'b0;
        wr_cache_miss[gm] = 1'b0;
        wr_hit_way[gm]    = '0;

        // Use latched address during data phase, live address during AW phase
        eff_addr = (w_locked[gm] && w_locked_was_hit[gm]) ? wr_latched_addr[gm]: wr_req_addr[gm];  // miss or new AW: use live addr
        
        if ((wr_req_valid[gm] || w_locked[gm]) && !wb_active && !line_under_refill(get_index(eff_addr), get_tag(eff_addr))) begin   //  added || w_locked 
          for (int w = 0; w < ASSOCIATIVITY; w++) begin   //added line_under_refill
            if (valid_array[get_index(eff_addr)][w] &&
                tag_array[get_index(eff_addr)][w] == get_tag(eff_addr)) begin
              wr_cache_hit[gm]  = 1'b1;
              wr_hit_way[gm]    = w[$clog2(ASSOCIATIVITY)-1:0];
              break;
            end
          end
          wr_cache_miss[gm] = ~wr_cache_hit[gm];
         $display("CACHE_DEBUG [%0t] slave=%0d wr_req_valid=%0b w_locked=%0b set_index=%0d tag=%0h -> HIT=%0b MISS=%0b WAY=%0d",$time, gm, wr_req_valid[gm], w_locked[gm], wr_index[gm], wr_tag[gm],wr_cache_hit[gm], wr_cache_miss[gm], wr_hit_way[gm]);
        end
      end
    end
  endgenerate

  // =========================================================================
  // READY SIGNALS  (combinational)
  // =========================================================================
  logic rd_ready [NO_OF_SLAVES];
  always_comb begin
    for (int m = 0; m < NO_OF_SLAVES; m++) begin
      rd_ready[m] = 1'b0;
      if (rd_cache_hit[m]  && !r_locked[m]) begin
        rd_ready[m] = 1'b1;
        $display("%0t: Sending cache_arready = 1 because rd_cache_hit[%0d] = %b",$time, m, rd_cache_hit[m]);
      end else begin
        bit conflict;
        conflict = 1'b0;
        for (int i = 0; i < NUM_MSHR; i++) begin
          if (mshr[i].valid &&
              mshr[i].index == rd_index[m] &&
              mshr[i].tag   == rd_tag[m])
            conflict = 1'b1;
        end
       if (!mshr_full && !conflict && !r_locked[m]) begin
          rd_ready[m] = 1'b1;
          $display("%0t: Sending cache_arready=1 !mshr_full && !conflict && !r_locked master=%0d",$time, m);
        end
      end
    end
  end
  always_comb begin
    for (int m = 0; m < NO_OF_SLAVES; m++)
      cache_arready[m] = rd_ready[m];
  end

  always_comb begin
    for (int m = 0; m < NO_OF_SLAVES; m++) begin
      wr_req_ready[m] = 1'b0;
      if (wr_cache_hit[m] && !w_locked[m]) begin 
        wr_req_ready[m] = 1'b1;
        $display("%0t: Sending wr_req_ready = 1 becuase wr_cache_hit[%0b] = %b && !w_locked[m] = %b",$time, m, wr_cache_hit[m], w_locked[m]);
      end else begin
        bit conflict;
        conflict = 1'b0;
        for (int i = 0; i < NUM_MSHR; i++) begin
          if (mshr[i].valid &&
              mshr[i].index == wr_index[m] &&
              mshr[i].tag   == wr_tag[m])
            conflict = 1'b1;
        end
        if (!mshr_full && !conflict && !wr_cache_hit[m] )begin  //added && !wr_cache_hit[m] (for next hit , it was coming here , becuase no mshr and no conflict )
          wr_req_ready[m] = 1'b1;
          $display("at time %0t: inside if (!mshr_full && !conflict) wr_req_ready[%b] = 1'b1; == %b ",$time,m,wr_req_ready[m]);
        end
        
      end
    end
  end
  always_comb begin
    for (int m = 0; m < NO_OF_SLAVES; m++)
      cache_awready[m] = wr_req_ready[m];
  end

  always_comb begin
  for (int m = 0; m < NO_OF_SLAVES; m++)
    cache_wready[m] = w_locked[m];
  end

  // =========================================================================
  // GATED WRITE SIGNALS  (combinational)
  // =========================================================================
  always_comb begin
  for (int m = 0; m < NO_OF_SLAVES; m++) begin
    if (w_locked[m]) begin
      wr_data_valid_g[m] = cache_wvalid[m];
      wr_data_last_g[m]  = wr_data_last[m];
      wr_data_g[m]       = wr_data[m];
      wr_strb_g[m]       = wr_strb[m];
    end else begin
      wr_data_valid_g[m] = 1'b0;
      wr_data_last_g[m]  = 1'b0;
      wr_data_g[m]       = '0;
      wr_strb_g[m]       = '0;
    end
  end
end

  // =========================================================================
  // BLOCK A — w_locked, w_owner
  // =========================================================================
  always_ff @(posedge aclk or negedge aresetn) begin
  if (!aresetn) begin
    for (int m = 0; m < NO_OF_SLAVES; m++) begin
      w_locked[m]    <= 1'b0;
      w_locked_id[m] <= '0;
      wr_latched_addr[m]   <= cache_awaddr[m];
      w_locked_was_hit[m]  <= wr_cache_hit[m];  // ← was it a hit or miss?
    end
  end else begin
    for (int m = 0; m < NO_OF_SLAVES; m++) begin
      // Lock when handshake happens on this slave port
      if (!w_locked[m] && wr_req_valid[m] && wr_req_ready[m]) begin    //only for starting first transaction on that slave port.
        w_locked[m]    <= 1'b1;
        w_locked_id[m] <= cache_awid[m];
        $display("(Non blocking) w_locked=1 id=%0h",cache_awid[m]);
      end
      // Release when transaction completes on this slave port
      if (w_locked[m] && wr_complete[m]) begin
        w_locked[m]    <= 1'b0;
        w_locked_id[m] <= '0;
        $display("(Non blocking) w_locked=0 id=0");
        for (int i = 0; i < NUM_MSHR; i++) begin     //Immediately check for any pending write MSHR on same slave port
          if (mshr[i].valid && mshr[i].is_write && int'(mshr[i].master) == m && !mshr[i].wlast_seen && mshr[i].axi_id != w_locked_id[m]) begin
            w_locked[m]    <= 1'b1;
            w_locked_id[m] <= mshr[i].axi_id;
            break;
        end
       end
    end
  end
end
  end

  always_ff @(posedge aclk or negedge aresetn) begin  //added new BLOCK A_R
    if (!aresetn) begin
      for (int m = 0; m < NO_OF_SLAVES; m++)
        r_locked[m] <= 1'b0;
    end else begin
      for (int m = 0; m < NO_OF_SLAVES; m++) begin
        // Set on AR handshake — mirrors Block A set condition
        if (!r_locked[m] && cache_arvalid[m] && cache_arready[m]) begin
          r_locked[m] <= 1'b1;
          $display("(Non blocking) r_locked=1 master=%0d araddr=0x%0h",
                   m, cache_araddr[m]);
        end
        // Clear on R accepted — mirrors Block A: w_locked && wr_complete
        // wr_complete = bvalid && bready
        // rd_complete = rvalid && rready
        if (r_locked[m] && cache_rvalid[m] && cache_rready[m] && cache_rlast[m]) begin
          r_locked[m] <= 1'b0;
          $display("(Non blocking) r_locked=0 master=%0d", m);
        end
 
      end
    end
  end
// =========================================================================
  // BLOCK A_R2 — Latch hit-path AR attributes at the exact accept cycle.
  // cache_araddr/arlen/arid are only valid combinationally during the single
  // cycle rd_active_master[s] is granted — they revert to '0 the very next
  // cycle. The hit-generation logic below needs these values for the ENTIRE
  // multi-beat burst, so latch them here, exactly like the miss path already
  // does via the MSHR.
  // =========================================================================
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      for (int s = 0; s < NO_OF_SLAVES; s++) begin
        rd_hit_addr_latched[s]  <= '0;
        rd_hit_arlen_latched[s] <= '0;
        rd_hit_id_latched[s]    <= '0;
        rd_hit_way_latched[s]   <= '0;
      end
    end else begin
      for (int s = 0; s < NO_OF_SLAVES; s++) begin
        if (rd_cache_hit[s] && cache_arvalid[s] && cache_arready[s]) begin
          rd_hit_addr_latched[s]  <= cache_araddr[s];
          rd_hit_arlen_latched[s] <= cache_arlen[s];
          rd_hit_id_latched[s]    <= cache_arid[s];
          rd_hit_way_latched[s]   <= rd_hit_way[s];
          $display("[RD_HIT_LATCH] time=%0t slave=%0d addr=0x%0h arlen=%0d id=0x%0h way=%0d",
                    $time, s, cache_araddr[s], cache_arlen[s], cache_arid[s], rd_hit_way[s]);
        end
      end
    end
  end
  // =========================================================================
  // BLOCK B — wr_hit_id[]
  // =========================================================================
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      for (int m = 0; m < NO_OF_SLAVES; m++)begin
        wr_hit_id[m] <= '0;
        wr_hit_beat[m] <= '0;
      end
    end else begin
      for (int m = 0; m < NO_OF_SLAVES; m++) begin
        if (cache_awvalid[m] && cache_awready[m]) begin
          wr_hit_id[m] <= cache_awid[m];
          wr_hit_beat[m] <= get_word_index(cache_awaddr[m]); // start at base word
        end
        else if (wr_data_valid_g[m] && cache_wready[m] && w_locked[m])
          wr_hit_beat[m] <= wr_hit_beat[m] + 1'b1;
        end
    end
  end

  // =========================================================================
  // BLOCK C — lru_counter[]
  // =========================================================================
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      for (int s = 0; s < NUM_SETS; s++)
        for (int w = 0; w < ASSOCIATIVITY; w++)
          lru_counter[s][w] <= '0;
    end else begin
      for (int m = 0; m < NO_OF_SLAVES; m++) begin
        if (rd_cache_hit[m]) begin
          for (int w = 0; w < ASSOCIATIVITY; w++)
            if (lru_counter[rd_index[m]][w] < 8'hFF)
              lru_counter[rd_index[m]][w] <= lru_counter[rd_index[m]][w] + 1;
          lru_counter[rd_index[m]][rd_hit_way[m]] <= 8'h00;
        end
      end
      for (int m = 0; m < NO_OF_SLAVES; m++) begin
        if (wr_cache_hit[m] && wr_data_last_g[m] && w_locked[m]) begin
          for (int w = 0; w < ASSOCIATIVITY; w++)
            if (lru_counter[wr_index[m]][w] < 8'hFF)
              lru_counter[wr_index[m]][w] <= lru_counter[wr_index[m]][w] + 1;
          lru_counter[wr_index[m]][wr_hit_way[m]] <= 8'h00;
        end
      end
    end
  end

  // =========================================================================
  // BLOCK D — wb_state, wb_active, wb_mshr_id, wb_beat  (FSM control only)
  //
  // mshr field writes that were previously here (needs_writeback, wb_done,
  // wb_error, resp_code) are now in BLOCK E.
  // dirty_array write that was previously here is now in BLOCK F.
  // =========================================================================
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      wb_state   <= WB_IDLE;
      wb_active  <= 1'b0;
      wb_mshr_id <= '0;
      wb_beat    <= '0;
    end else begin
      case (wb_state)
        WB_IDLE: begin
          wb_active <= 1'b0;
          wb_beat   <= '0;
          for (int i = 0; i < NUM_MSHR; i++) begin
            if (mshr[i].valid && mshr[i].needs_writeback && !mshr[i].wb_done) begin
              $display("In WB IDLE state and made wb_active using NBA");
              wb_mshr_id <= i[$clog2(NUM_MSHR)-1:0];
              wb_state   <= WB_AW;
              wb_active  <= 1'b1;
              break;
            end
          end
        end
        WB_AW: begin
          if (s_awready[mshr[wb_mshr_id].slave]) begin
            $display("In WB ADDRESS state and received s_awready,moving to WB_W");
            wb_state <= WB_W;
            wb_beat  <= '0;
          end
        end
        WB_W: begin
          if (s_wready[mshr[wb_mshr_id].slave]) begin
            $display("In WB WRITE DATA state and received s_wready,moving to WB_RESP");
            if (wb_beat == WORDS_PER_LINE-1)
              wb_state <= WB_RESP;
            else
              wb_beat <= wb_beat + 1'b1;
          end
        end
        WB_RESP: begin
          if (s_bvalid[mshr[wb_mshr_id].slave]) begin
            wb_state  <= WB_IDLE;
            wb_active <= 1'b0;
          end
        end
        default: wb_state <= WB_IDLE;
      endcase
    end
  end

  // =========================================================================
  // BLOCK E — mshr[], active_r_mshr[], active_r_valid[]
  //
  // Sole owner of every mshr field and active_r_* signal.
  // Sub-sections in priority order:
  //   E-1  Cleanup  (retire done entries)
  //   E-2  WB_RESP mshr updates  (wb_done, wb_error, resp_code, needs_writeback)
  //   E-3  AR sent flag + active_r tracking
  //   E-4  Read data fill  (beat counter, resp_code on error, done on rlast)
  //   E-5  Write-miss data capture  (wdata_buf, wstrb_buf, wbeat_count)
  //   E-6  MSHR allocation  (read miss, then write miss)
  // =========================================================================
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      for (int i = 0; i < NUM_MSHR; i++) begin
        mshr[i].valid           <= 1'b0;
        mshr[i].is_write        <= 1'b0;
        mshr[i].done            <= 1'b0;
        mshr[i].ar_sent         <= 1'b0;
        mshr[i].wb_done         <= 1'b0;
        mshr[i].wb_error        <= 1'b0;
        mshr[i].master          <= '0;
        mshr[i].addr            <= '0;
        mshr[i].index           <= '0;
        mshr[i].tag             <= '0;
        mshr[i].way             <= '0;
        mshr[i].slave           <= '0;
        mshr[i].beat            <= '0;
        mshr[i].axi_id          <= '0;
        mshr[i].needs_writeback <= 1'b0;
        mshr[i].resp_code       <= 2'b00;
        mshr[i].wbeat_count     <= '0;
        mshr[i].wlast_seen <= 1'b0;
        mshr[i].rlast_seen <= 1'b0;
        mshr[i].ar_pending <= 1'b0;
        for (int wb = 0; wb < WORDS_PER_LINE; wb++) begin
          mshr[i].wdata_buf[wb] <= '0;
          mshr[i].wstrb_buf[wb] <= '0;
        end
      end
      for (int s = 0; s < NO_OF_SLAVES; s++) begin
        active_r_valid[s] <= 1'b0;
        active_r_mshr[s]  <= '0;
      end
    end else begin

      // E-1: CLEANUP — retire completed MSHRs
      for (int i = 0; i < NUM_MSHR; i++) begin
        int m;
        m = int'(mshr[i].master);
        if (mshr[i].done &&
            ((mshr[i].is_write  && wr_resp_valid[m] && cache_bready[m]) ||
             (!mshr[i].is_write && rd_data_valid[m] && cache_rready[m] && mshr[i].arlen==rd_beat_count[m]))) begin
          if (mshr[i].is_write) begin
            $display("[CACHE_LINE_FINAL_DATA] time=%0t mshr=%0d set=%0d way=%0d tag=0x%0h",$time, i, mshr[i].index, mshr[i].way, mshr[i].tag);
            for (int wb = 0; wb < WORDS_PER_LINE; wb++)
                $display("  word[%0d] = 0x%0h", wb, data_array[mshr[i].index][mshr[i].way][wb]);
          end
          mshr[i].valid   <= 1'b0;
          mshr[i].done    <= 1'b0;
          mshr[i].ar_sent <= 1'b0;
          mshr[i].wb_done <= 1'b0;
          mshr[i].wlast_seen  <= 1'b0;   // ← add
          mshr[i].wbeat_count <= '0;     // ← add
          mshr[i].way <= '0;   // ← add this
          mshr[i].needs_writeback <= 1'b0;  // ← add this too
          for (int wb = 0; wb < WORDS_PER_LINE; wb++) begin
           mshr[i].wdata_buf[wb] <= '0;  // ← add
           mshr[i].wstrb_buf[wb] <= '0;
          end
        end
      end

      // E-2: WB_RESP mshr field updates
      if (wb_state == WB_RESP && s_bvalid[mshr[wb_mshr_id].slave]) begin
        if (s_bresp[mshr[wb_mshr_id].slave] == 2'b00) begin
          mshr[wb_mshr_id].needs_writeback <= 1'b0;
          mshr[wb_mshr_id].wb_done         <= 1'b1;
          mshr[wb_mshr_id].wb_error        <= 1'b0;
        end else begin
          mshr[wb_mshr_id].wb_done         <= 1'b1;
          mshr[wb_mshr_id].wb_error        <= 1'b1;
          mshr[wb_mshr_id].resp_code       <= s_bresp[mshr[wb_mshr_id].slave];
        end
      end

      // E-3: AR SENT flag
      for (int i = 0; i < NUM_MSHR; i++) begin
        if (mshr[i].valid &&
            !mshr[i].ar_sent &&
            s_arvalid[mshr[i].slave] &&
            s_arready[mshr[i].slave] &&
            (!mshr[i].needs_writeback || mshr[i].wb_done) &&
            !active_r_valid[mshr[i].slave]) begin
          mshr[i].ar_sent               <= 1'b1;
          mshr[i].ar_pending           <= 1'b0;
          active_r_valid[mshr[i].slave] <= 1'b1;
          active_r_mshr [mshr[i].slave] <= i[$clog2(NUM_MSHR)-1:0];
         $display("[%0t] CACHE_AR_SENT: mshr=%0d slave=%0d addr=0x%0h id=%0h",$time, i, mshr[i].slave, mshr[i].addr, mshr[i].axi_id);
        end
        else if (mshr[i].valid && !mshr[i].ar_sent) begin
          if (active_r_valid[mshr[i].slave]) begin
             mshr[i].ar_pending <= 1'b1;
             $display("[%0t] CACHE AR_PENDING: mshr=%0d slave=%0d | active_r_valid is HIGH, marking as pending",$time, i, mshr[i].slave);
          end
          else begin
             $display("[%0t] CACHE AR_BLOCKED: mshr=%0d slave=%0d | arvalid=%0b arready=%0b WB_needed=%0b WB_done=%0b active_r_valid=%0b",$time,i,mshr[i].slave,s_arvalid[mshr[i].slave],s_arready[mshr[i].slave],mshr[i].needs_writeback,mshr[i].wb_done,active_r_valid[mshr[i].slave]);
          end
        end
        if (!mshr[i].valid) begin
          mshr[i].ar_sent <= 1'b0;
          mshr[i].ar_pending <= 1'b0;
        end
      end

            // E-4: Read data fill — beat counter, error capture, done handling
      for (int s = 0; s < NO_OF_SLAVES; s++) begin
        if (active_r_valid[s]) begin
          int i;
          i = int'(active_r_mshr[s]);
          $display("[%0t] CACHE ACTIVE_R: slave=%0d -> mshr=%0d | ar_sent=%0b beat=%0d done=%0b",$time,s,i,mshr[i].ar_sent,mshr[i].beat,mshr[i].done);

          // -------------------------
          // PART 1: Capture read data
          // -------------------------
          if (mshr[i].valid && s_rvalid[s] &&  s_rid[s] == mshr[i].axi_id) begin //s_rid[s] == mshr[i].axi_id
            $display("[%0t] CACHE R_BEAT: slave=%0d mshr=%0d | beat=%0d rlast=%0b",$time,s,i,mshr[i].beat,s_rlast[s]);
            mshr[i].beat <= mshr[i].beat + 1'b1;

            if (s_rresp[s] != 2'b00)
              mshr[i].resp_code <= s_rresp[s];

            if (s_rlast[s]) begin
              mshr[i].rlast_seen <= 1'b1; // optional (can keep or remove)
              $display("[REFILL_COMPLETE] time=%0t mshr=%0d set=%0d way=%0d — printing existing data_array BEFORE merge:",$time, i, mshr[i].index, mshr[i].way);
              for (int wb = 0; wb < WORDS_PER_LINE; wb++)
                $display("  word[%0d] = 0x%0h", wb, data_array[mshr[i].index][mshr[i].way][wb]);
             end
          end
          
          else begin
            $display("CACHE [%0t] R_BEAT_SKIP: slave=%0d mshr=%0d | valid=%0b rvalid=%0b rid=%h exp_id=%h match=%0b", $time,s,i,mshr[i].valid,s_rvalid[s], s_rid[s],mshr[i].axi_id,(s_rid[s] == mshr[i].axi_id));
          end

          // -------------------------
          // PART 2: DONE logic (FIXED)
          // -------------------------
          if (mshr[i].valid) begin

            // READ MISS COMPLETE
            if (!mshr[i].is_write) begin
              if (s_rvalid[s] && s_rready[s] && s_rlast[s] && s_rid[s] == mshr[i].axi_id) begin
                 $display("[DEBUG] READ DONE time=%0t | mshr=%0d | rvalid=%0b | rready=%0b | rlast=%0b | rid=%0d | axi_id=%0d",$time, i,s_rvalid[s],s_rready[s],s_rlast[s],s_rid[s],mshr[i].axi_id);

               mshr[i].done <= 1'b1;
               active_r_valid[s] <= 1'b0;

           end
           else begin
              $display("[DEBUG] READ NOT DONE time=%0t | mshr=%0d | rvalid=%0b | rready=%0b | rlast=%0b | rid=%0d | axi_id=%0d | id_match=%0b",$time, i,s_rvalid[s], s_rready[s],s_rlast[s],s_rid[s],mshr[i].axi_id,(s_rid[s] == mshr[i].axi_id));
         end
      end

            //  WRITE MISS COMPLETE
            else begin
              if (s_rvalid[s] && s_rready[s] && s_rlast[s] && mshr[i].wlast_seen && s_rid[s] == mshr[i].axi_id) begin

                $display("[CACHE_DEBUG] WRITE DONE time=%0t | mshr=%0d", $time, i);

                mshr[i].done <= 1'b1;
                active_r_valid[s] <= 1'b0;   // clear AFTER handshake
              end
            end

          end

        end
      end

      // E-4.5: Fire pending ARs when active_r_valid clears
      for (int s = 0; s < NO_OF_SLAVES; s++) begin
        if (active_r_valid[s]) begin
          int i;
          i = int'(active_r_mshr[s]);
          // Detect rlast handshake on this slave
          if (mshr[i].valid && s_rvalid[s] && s_rready[s] && s_rlast[s] && 
              s_rid[s] == mshr[i].axi_id) begin
            // Scan for pending ARs for this slave
            bit found_pending;
            found_pending = 1'b0;
            for (int j = 0; j < NUM_MSHR; j++) begin
              if (mshr[j].valid && mshr[j].ar_pending && 
                  mshr[j].slave == s &&
                  !mshr[j].ar_sent &&
                  (!mshr[j].needs_writeback || mshr[j].wb_done)) begin
                // Fire this pending AR
                mshr[j].ar_pending           <= 1'b0;
                mshr[j].ar_sent              <= 1'b1;
                active_r_valid[s]            <= 1'b1;
                active_r_mshr[s]             <= j[$clog2(NUM_MSHR)-1:0];
                found_pending = 1'b1;
                $display("[%0t] CACHE_FIRE_PENDING_AR: pending_mshr=%0d slave=%0d addr=0x%0h id=%0h",
                         $time, j, s, mshr[j].addr, mshr[j].axi_id);
                break;
              end
            end
            // Only clear active_r_valid if no pending AR was found
            if (!found_pending) begin
              mshr[i].done       <= 1'b1;
              active_r_valid[s]  <= 1'b0;
            end
          end
        end
      end
      
// E-5: Write-miss data capture
for (int i = 0; i < NUM_MSHR; i++) begin
  if (mshr[i].valid && mshr[i].is_write && !mshr[i].wlast_seen) begin
    int m;
    m = int'(mshr[i].master);
    // Each MSHR listens to its own master port directly
    // No w_owner/w_locked check needed for miss path
    if (wr_data_valid_g[m] && cache_wready[m] && mshr[i].axi_id == w_locked_id[m]) begin
      automatic logic [$clog2(WORDS_PER_LINE)-1:0] base;
      automatic logic [$clog2(WORDS_PER_LINE)-1:0] widx;
      base = get_word_index(mshr[i].addr);
      widx = base + mshr[i].wbeat_count;
      if (widx < WORDS_PER_LINE) begin
        mshr[i].wdata_buf[widx] <= wr_data_g[m];
        mshr[i].wstrb_buf[widx] <= wr_strb_g[m];
        $display("[WBUF_COLLECT] time=%0t mshr=%0d widx=%0d wdata=0x%0h wstrb=0x%0h beat_count=%0d",
                 $time, i, widx, wr_data_g[m], wr_strb_g[m], mshr[i].wbeat_count);
      end
      if (!wr_data_last_g[m])
        mshr[i].wbeat_count <= mshr[i].wbeat_count + 1;
      if (wr_data_last_g[m])
        mshr[i].wlast_seen <= 1'b1;
    end
  end
end

   // E-6: MSHR allocation
      begin
        bit being_allocated [NUM_MSHR];
        bit way_being_used    [NUM_SETS][ASSOCIATIVITY];
        
        for (int i = 0; i < NUM_MSHR; i++)
          being_allocated[i] = 1'b0;
        for (int s = 0; s < NUM_SETS; s++)
          for (int w = 0; w < ASSOCIATIVITY; w++)
             way_being_used[s][w] = 1'b0;

        // Priority 1: read miss
        for (int m = 0; m < NO_OF_SLAVES; m++) begin
          if (cache_arvalid[m] && rd_cache_miss[m] && !mshr_full) begin
            bit conflict;
            conflict = 1'b0;
            for (int j = 0; j < NUM_MSHR; j++) begin
              if (mshr[j].valid &&
                  mshr[j].index == rd_index[m] &&
                  mshr[j].tag   == rd_tag[m])
                conflict = 1'b1;
            end
            if (!conflict) begin
              for (int i = 0; i < NUM_MSHR; i++) begin
                if (!mshr[i].valid && !being_allocated[i]) begin
                  automatic logic [$clog2(ASSOCIATIVITY)-1:0] vway;
                  vway = find_victim_way(rd_index[m],way_being_used);
                  being_allocated[i]      = 1'b1;
                  $display("Inside CACHE READ MSHR ALLOCATION BLOCK");
                  mshr[i].valid           <= 1'b1;
                  mshr[i].is_write        <= 1'b0;
                  mshr[i].master          <= m[$clog2(NO_OF_SLAVES)-1:0];
                  mshr[i].addr            <= rd_req_addr[m];
                  mshr[i].index           <= rd_index[m];
                  mshr[i].tag             <= rd_tag[m];
                  mshr[i].way             <= vway;
                  mshr[i].slave           <= decode_slave(rd_req_addr[m]);
                  mshr[i].beat            <= '0;
                  mshr[i].axi_id          <= rd_req_id[m];
                  mshr[i].arlen           <= cache_arlen[m];   //added for read beat count
                  mshr[i].done            <= 1'b0;
                  mshr[i].ar_sent         <= 1'b0;
                  mshr[i].wb_done         <= 1'b0;
                  mshr[i].wb_error        <= 1'b0;
                  mshr[i].resp_code       <= 2'b00;
                  mshr[i].wbeat_count     <= '0;
                  mshr[i].wlast_seen      <= 1'b0;
                  mshr[i].needs_writeback <=
                    valid_array[rd_index[m]][vway] &&
                    dirty_array[rd_index[m]][vway];
                  if (valid_array[rd_index[m]][vway] && dirty_array[rd_index[m]][vway])
                    $display("Needs writeback made 1 for way=%0d (read miss)", vway);

                  $display("[%0t] CACHE_READ_MSHR_ALLOC: master=%0d -> mshr_idx=%0d | addr=%0h index=%0d tag=%0h way=%0d | write=%0b | victim_dirty=%0b",$time, m, i,rd_req_addr[m], rd_index[m], rd_tag[m], vway,1'b0,valid_array[rd_index[m]][vway] && dirty_array[rd_index[m]][vway]);
                  break;
                end
              end
            end
          end
        end

        // Priority 2: write miss
        for (int m = 0; m < NO_OF_SLAVES; m++) begin
          if (wr_req_valid[m] && wr_cache_miss[m] && !mshr_full) begin
            bit conflict;
            conflict = 1'b0;
            for (int j = 0; j < NUM_MSHR; j++) begin
              if (mshr[j].valid &&
                  mshr[j].index == wr_index[m] &&
                  mshr[j].tag   == wr_tag[m])
                conflict = 1'b1;
            end
            if (!conflict) begin
              for (int i = 0; i < NUM_MSHR; i++) begin
                if (!mshr[i].valid && !being_allocated[i]) begin
                  automatic logic [$clog2(ASSOCIATIVITY)-1:0] vway;
                  vway = find_victim_way(wr_index[m],way_being_used);
                  being_allocated[i]      = 1'b1;
                  $display("Inside CACHE WRITE MSHR ALLOCATION BLOCK");
                  mshr[i].valid           <= 1'b1;
                  mshr[i].is_write        <= 1'b1;
                  mshr[i].master          <= m[$clog2(NO_OF_SLAVES)-1:0];
                  mshr[i].addr            <= wr_req_addr[m];
                  mshr[i].index           <= wr_index[m];
                  mshr[i].tag             <= wr_tag[m];
                  mshr[i].way             <= vway;
                  mshr[i].slave           <= decode_slave(wr_req_addr[m]);
                  mshr[i].beat            <= '0;
                  mshr[i].axi_id          <= wr_req_id[m];
                  mshr[i].done            <= 1'b0;
                  mshr[i].ar_sent         <= 1'b0;
                  mshr[i].wb_done         <= 1'b0;
                  mshr[i].wb_error        <= 1'b0;
                  mshr[i].resp_code       <= 2'b00;
                  mshr[i].wbeat_count     <= '0;
                  mshr[i].needs_writeback <=
                    valid_array[wr_index[m]][vway] &&
                    dirty_array[wr_index[m]][vway];
                  if(valid_array[wr_index[m]][vway] && dirty_array[wr_index[m]][vway])
                    begin
                      $display("Needs writeback made 1 for way=%0d",vway);
                    end
                  for (int wb = 0; wb < WORDS_PER_LINE; wb++) begin
                    mshr[i].wdata_buf[wb] <= '0;
                    mshr[i].wstrb_buf[wb] <= '0;
                  end
                  $display("[%0t] CACHE_MSHR_ALLOC: slave=%0d -> mshr_idx=%0d | addr=%0h index=%0d tag=%0h way=%0d | write=%0b | victim_dirty=%0b",
                           $time,m,i,wr_req_addr[m],wr_index[m],wr_tag[m],vway,1'b1,
                           valid_array[wr_index[m]][vway] && dirty_array[wr_index[m]][vway]);
                  break;
                end
              end
            end
          end
        end
      end // being_allocated scope

    end // else
  end // BLOCK E

  // =========================================================================
  // BLOCK F — tag_array[], valid_array[], dirty_array[], data_array[]
  //
  // Sole owner of all cache memory arrays.
  // Sub-sections:
  //   F-1  WB_RESP dirty clear
  //   F-2  Write-hit byte update  (data_array, dirty_array)
  //   F-3  Read data line fill    (data_array, tag_array, valid_array, dirty_array)
  // =========================================================================
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      for (int s = 0; s < NUM_SETS; s++) begin
        for (int w = 0; w < ASSOCIATIVITY; w++) begin
          valid_array[s][w] <= 1'b0;
          dirty_array[s][w] <= 1'b0;
          tag_array[s][w]   <= '0;
          for (int b = 0; b < WORDS_PER_LINE; b++)
            data_array[s][w][b] <= '0;
        end
      end
    end else begin

      // F-1: WB_RESP — clear dirty bit after successful writeback
      if (wb_state == WB_RESP && s_bvalid[mshr[wb_mshr_id].slave]) begin
        if (s_bresp[mshr[wb_mshr_id].slave] == 2'b00) begin
          dirty_array[mshr[wb_mshr_id].index]
                     [mshr[wb_mshr_id].way] <= 1'b0;
        end
      end

      // F-2: Write-hit byte update
     for (int m = 0; m < NO_OF_SLAVES; m++) begin
         if (wr_cache_hit[m] && wr_data_valid_g[m] && w_locked[m]) begin
           $display("[%0t] inside write hit byte update slave_port=%0d w_locked=%0b w_locked_id=%0h",$time, m, w_locked[m], w_locked_id[m]);
          for (int b = 0; b < (DATA_WIDTH/8); b++) begin
            if (wr_strb_g[m][b]) begin
              data_array[wr_index[m]][wr_hit_way[m]][wr_hit_beat[m]][8*b +: 8] <=  wr_data_g[m][8*b +: 8];
            end
            if ((b % 4 == 3)) begin
              $display("WRITE HIT WORD WRITE (bytes %0d-%0d): old=%0h new=%0h",b-3, b,data_array[wr_index[m]][wr_hit_way[m]][wr_hit_beat[m]][32*(b/4) +: 32],wr_data_g[m][32*(b/4) +: 32]);
            end
        end
          dirty_array[wr_index[m]][wr_hit_way[m]] <= 1'b1;
      end
    end

      // F-3: Read data line fill
      for (int s = 0; s < NO_OF_SLAVES; s++) begin
        if (active_r_valid[s]) begin
          int i;
          i = int'(active_r_mshr[s]);
          if (mshr[i].valid && s_rvalid[s] &&
               s_rid[s][ID_WIDTH-1:0] == mshr[i].axi_id[ID_WIDTH-1:0]) begin // s_rid[s] == mshr[i].axi_id
            // Write word-by-word using mshr beat (read from E-4 which increments it)
            // Use current beat value before E-4 increments it this cycle
            data_array[mshr[i].index][mshr[i].way][mshr[i].beat] <= s_rdata[s];
            $display("[REFILL_STORE] time=%0t mshr=%0d slave=%0d slave_id=%h mshr_id=%h set=%0d way=%0d beat=%0d rdata=0x%0h rlast=%0b",
                     $time, i, s,s_rid[s],mshr[i].axi_id,mshr[i].index, mshr[i].way, mshr[i].beat, s_rdata[s], s_rlast[s]);
            
            if (s_rlast[s]) begin
              $display(" inside if s_rlast[s] mshr[i].resp_code == %b ",mshr[i].resp_code);
              if (mshr[i].resp_code == 2'b00) begin
                $display("at time %0t :mshr[i].resp_code == 2'b00 and making valid_array[mshr[i].index][mshr[i].way] <= 1'b1; ",$time);
                tag_array  [mshr[i].index][mshr[i].way] <= mshr[i].tag;
                valid_array[mshr[i].index][mshr[i].way] <= 1'b1;
                if (mshr[i].is_write) begin
                   $display("[PRE_MERGE_CHECK] mshr=%0d wbeat_count=%0d wlast_seen=%0b", 
             i, mshr[i].wbeat_count, mshr[i].wlast_seen);
                  for (int wb = 0; wb < WORDS_PER_LINE; wb++) begin
                    for (int b = 0; b < DATA_WIDTH/8; b++) begin
                      if (mshr[i].wstrb_buf[wb][b])
                        data_array[mshr[i].index][mshr[i].way][wb][8*b +: 8]
                          <= mshr[i].wdata_buf[wb][8*b +: 8];
                       
                    end
                     $display("[WBUF_MERGE] time=%0t mshr=%0d word=%0d wdata=0x%0h wstrb=0x%0h -> cache[%0d][%0d][%0d]",
                       $time, i, wb, mshr[i].wdata_buf[wb], mshr[i].wstrb_buf[wb],
                       mshr[i].index, mshr[i].way, wb);
                  end
                  dirty_array[mshr[i].index][mshr[i].way] <= 1'b1;
                  $display("[DIRTY_SET] time=%0t dirty_array made 1 for set=%0d way=%0d | mshr=%0d valid=%0b is_write=%0b tag=%h axi_id=%h beat=%0d resp=%0b",$time,mshr[i].index,mshr[i].way,i,mshr[i].valid,mshr[i].is_write,mshr[i].tag,mshr[i].axi_id,mshr[i].beat,mshr[i].resp_code);
                end else begin
                  dirty_array[mshr[i].index][mshr[i].way] <= 1'b0;
                  $display("[PRE_MERGE_CHECK_ELSE] mshr=%0d wbeat_count=%0d wlast_seen=%0b", 
             i, mshr[i].wbeat_count, mshr[i].wlast_seen);
                end
              end
            end
          end
        end
      end

    end // else
  end // BLOCK F

  // =========================================================================
  // WRITE-BACK AXI DOWNSTREAM  (combinational)
  // =========================================================================
  always_comb begin
    s_awvalid = '0;
    s_awaddr  = '{default:'0};
    s_awid    = '{default:'0};
    s_awlen   = '{default:'0};
    s_awsize  = '{default:3'b010};
    s_awburst = '{default:2'b01};
    s_awcache = '{default:'0};
    s_wvalid  = '0;
    s_wdata   = '{default:'0};
    s_wstrb   = '{default:{(DATA_WIDTH/8){1'b1}}};
    s_wlast   = '0;
    s_bready  = '1;
    if (wb_active) begin
      int sid, idx, way;
      sid = int'(mshr[wb_mshr_id].slave);
      idx = int'(mshr[wb_mshr_id].index);
      way = int'(mshr[wb_mshr_id].way);
      case (wb_state)
        WB_AW: begin
          s_awvalid[sid] = 1'b1;
          s_awaddr[sid]  = {tag_array[idx][way], idx[INDEX_BITS-1:0],
                            {OFFSET_BITS{1'b0}}};
          s_awid[sid]    = mshr[wb_mshr_id].axi_id;
          s_awlen[sid]   = 8'(WORDS_PER_LINE - 1);
          $display("[%0t] WB_AW -> SLAVE=%0d AWADDR=%h AWID=%0d AWLEN=%0d AWSIZE=%0d AWBURST=%0d",$time,sid,s_awaddr[sid],s_awid[sid],s_awlen[sid],s_awsize[sid],s_awburst[sid]);
        end
        WB_W: begin
          s_wvalid[sid] = 1'b1;
          s_wdata[sid]  = data_array[idx][way][wb_beat];
          s_wlast[sid]  = (wb_beat == WORDS_PER_LINE-1);
          $display("[%0t] WB_W  -> SLAVE=%0d WDATA=%h WSTRB=%h WLAST=%0b BEAT=%0d",$time,sid,s_wdata[sid],s_wstrb[sid],s_wlast[sid],wb_beat);
        end
        default: ;
      endcase
    end
  end

  // =========================================================================
  // AXI READ ADDRESS DOWNSTREAM  (combinational)
  // =========================================================================
  always_comb begin
    s_arvalid = '0;
    s_araddr  = '{default:'0};
    s_arlen   = '{default:'0};
    s_arid    = '{default:'0};
    s_arsize  = '{default:3'b010};
    s_arburst = '{default:2'b01};
    s_arcache = '{default:'0};
    for (int s = 0; s < NO_OF_SLAVES; s++) begin
      for (int i = 0; i < NUM_MSHR; i++) begin
        if (mshr[i].valid &&
            !mshr[i].ar_sent &&
            mshr[i].slave == s[$clog2(NO_OF_SLAVES)-1:0] &&
            (!mshr[i].needs_writeback || mshr[i].wb_done)) begin
          s_arvalid[s] = 1'b1;
          s_araddr[s]  = {mshr[i].addr[ADDRESS_WIDTH-1:OFFSET_BITS],
                          {OFFSET_BITS{1'b0}}};
          s_arlen[s]   = 8'(WORDS_PER_LINE - 1);
          s_arid[s]    = mshr[i].axi_id;
         // $display("[CACHE_AR_ISSUE] time=%0t | mshr=%0d | slave=%0d | valid=%0b | ar_sent=%0b | needs_wb=%0b | wb_done=%0b | mshr_addr=0x%0h | slave_addr=0x%0h | id=%0d | len=%0d",$time,i,s,mshr[i].valid,mshr[i].ar_sent,mshr[i].needs_writeback,mshr[i].wb_done,mshr[i].addr,s_araddr[s],mshr[i].axi_id,(WORDS_PER_LINE - 1));
          break;
        end
      end
    end
  end

  // =========================================================================
  // AXI READ READY DOWNSTREAM  (combinational)
  // =========================================================================
  always_comb begin
    s_rready = '0;
    for (int s = 0; s < NO_OF_SLAVES; s++)
      if (active_r_valid[s]) s_rready[s] = 1'b1;
  end

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        for (int m = 0; m < NO_OF_SLAVES; m++)
            rd_beat_count[m] <= '0;
    end else begin
        for (int m = 0; m < NO_OF_SLAVES; m++) begin
            if (cache_rvalid[m] && cache_rready[m]) begin
              $display("READ DATA HANDSHAKE rvalid=%0d rready=%0d slave=%0d",cache_rvalid[m],cache_rready[m],m);
              if (cache_rlast[m]) begin
                  rd_beat_count[m] <= '0; // reset after last beat
                  $display("Resetting rd_beat_count to 0 on rlast");
              end
                else begin
                  rd_beat_count[m] <= rd_beat_count[m] + 1;
                  $display("READ BEAT COUNT=%0d for slave=%0d",rd_beat_count[m],m);
                end
            end
        end
    end
end
  
  // =========================================================================
  // READ RESPONSE GENERATION  (combinational)
  // =========================================================================
  always_comb begin
    for (int m = 0; m < NO_OF_SLAVES; m++) begin
      rd_data_valid[m] = 1'b0;
      rd_data_last[m]  = 1'b0;
      rd_cache_data[m] = '0;
      rd_resp[m]       = 2'b00;
      rd_data_id[m]    = '0;
    end
    for (int i = 0; i < NUM_MSHR; i++) begin
    if (mshr[i].valid && mshr[i].done && !mshr[i].is_write) begin
    int m;
    automatic logic [$clog2(WORDS_PER_LINE)-1:0] base_word;
    automatic logic [$clog2(WORDS_PER_LINE)-1:0] cur_word;
    m         = int'(mshr[i].master);
    base_word = get_word_index(mshr[i].addr);
    cur_word  = base_word + rd_beat_count[m];       // walk the cache line

    rd_data_valid[m] = 1'b1;
    rd_data_last[m]  = (rd_beat_count[m] == mshr[i].arlen);  // last when count hits arlen
    rd_data_id[m]    = mshr[i].axi_id;
    rd_resp[m]       = mshr[i].resp_code;
    rd_cache_data[m] = data_array[mshr[i].index][mshr[i].way][cur_word];

    $display("[%0t] RGEN(miss): master=%0d beat=%0d/%0d word=%0d rdata=0x%0h rlast=%0b",$time, m, rd_beat_count[m], mshr[i].arlen, cur_word, rd_cache_data[m], rd_data_last[m]);
  end
end
    for (int m = 0; m < NO_OF_SLAVES; m++) begin
      bit mshr_done_for_m;
      mshr_done_for_m = 1'b0;
      for (int i = 0; i < NUM_MSHR; i++) begin
        if (mshr[i].valid && mshr[i].done && int'(mshr[i].master) == m)
          mshr_done_for_m = 1'b1;
          $display("[DEBUG-RGEN] time=%0t m=%0d mshr=%0d mshr_done_for_m=%b rd_cache_hit=%b arvalid=%b",$time, m, i,mshr_done_for_m, rd_cache_hit[m], cache_arvalid[m]);
      end
if (rd_cache_hit[m] && !mshr_done_for_m) begin
       automatic logic [$clog2(WORDS_PER_LINE)-1:0] base_word;
       automatic logic [$clog2(WORDS_PER_LINE)-1:0] cur_word;
       base_word = get_word_index(rd_hit_addr_latched[m]);
       cur_word  = base_word + rd_beat_count[m];       // walk the cache line

       rd_data_valid[m] = 1'b1;
       rd_data_last[m]  = (rd_beat_count[m] == rd_hit_arlen_latched[m]);  // last when count hits latched arlen
       rd_resp[m]       = 2'b00;
       rd_data_id[m]    = rd_hit_id_latched[m];
       rd_cache_data[m] = data_array[get_index(rd_hit_addr_latched[m])][rd_hit_way_latched[m]][cur_word];

       $display("[%0t] RGEN(hit): master=%0d beat=%0d/%0d word=%0d rdata=0x%0h rlast=%0b",
                 $time, m, rd_beat_count[m], rd_hit_arlen_latched[m], cur_word, rd_cache_data[m], rd_data_last[m]);
  end

  always_comb begin
    for (int m = 0; m < NO_OF_SLAVES; m++) begin
      cache_rvalid[m] = rd_data_valid[m];
      cache_rlast[m]  = rd_data_last[m];
      cache_rdata[m]  = rd_cache_data[m];
      cache_rresp[m]  = rd_resp[m];
      cache_rid[m]    = rd_data_id[m];
    end
  end

  // =========================================================================
  // WRITE RESPONSE GENERATION  (combinational)
  // =========================================================================
  always_comb begin
    for (int m = 0; m < NO_OF_SLAVES; m++) begin
      wr_complete[m]   = 1'b0;
      wr_resp_valid[m] = 1'b0;
      wr_resp[m]       = 2'b00;
      wr_resp_id[m]    = '0;
    end
    for (int i = 0; i < NUM_MSHR; i++) begin
      if (mshr[i].valid && mshr[i].done && mshr[i].is_write ) begin   
        int m;
        m = int'(mshr[i].master);
        if (w_locked[m] && mshr[i].axi_id == w_locked_id[m]) 
          wr_complete[m]   = 1'b1;  //only set wr_complete based on w_locked
        wr_resp_valid[m] = 1'b1;
        wr_resp[m]       = mshr[i].resp_code;
        wr_resp_id[m]    = mshr[i].axi_id;
        $display("%0t inisde WRITE RESPONSE GENERATION  : if (mshr[i].valid && mshr[i].done && mshr[i].is_write) making wr_complete[m] = 1'b1;);  master = %d ",$time,m);
  end
end
    for (int m = 0; m < NO_OF_SLAVES; m++) begin
      bit has_mshr;
      has_mshr = 1'b0;
      for (int i = 0; i < NUM_MSHR; i++) begin
        if (mshr[i].valid && int'(mshr[i].master) == m && mshr[i].axi_id == w_locked_id[m])begin   //added w_locked_id here
          has_mshr = 1'b1;
        end
        $display("[DEBUG-BGEN] time=%0t m=%0d has_mshr=%b wr_cache_hit=%b wr_data_last_g=%b w_locked=%b w_locked_id=%0h",$time, m, has_mshr, wr_cache_hit[m], wr_data_last_g[m], w_locked[m], w_locked_id[m]);    
      end
//       $display("has_mshr = %0d  wr_cache_hit[m] = %0d ",has_mshr,wr_cache_hit[m]);
      if (!has_mshr &&
          wr_cache_hit[m] &&
          wr_data_last_g[m] && w_locked[m]) begin
        wr_complete[m]   = 1'b1;
        wr_resp_valid[m] = 1'b1;
        wr_resp[m]       = 2'b00;
        wr_resp_id[m]    = wr_hit_id[m];
        $display("inside !has_mshr");
        $display("%0t inside WRITE RESPONSE GENERATION: hit path !has_mshr && wr_cache_hit[m] && wr_data_last_g[m] && w_locked[m] master=%0d", $time, m);
    end
  end
end

  always_comb begin
    for (int m = 0; m < NO_OF_SLAVES; m++) begin
      cache_bvalid[m] = wr_resp_valid[m];
      cache_bresp[m]  = wr_resp[m];
      cache_bid[m]    = wr_resp_id[m];
    end
  end

endmodule
