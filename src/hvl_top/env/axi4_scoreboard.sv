`ifndef AXI4_L3_CACHE_SCOREBOARD_INCLUDED_
`define AXI4_L3_CACHE_SCOREBOARD_INCLUDED_

class axi4_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi4_scoreboard)

  axi4_master_tx axi4_master_tx_h;
  axi4_slave_tx axi4_slave_tx_h;
  bit[61:0]master_aw_queue[int][$];
  int wb_beat_tracker[int];
   //=============================================================================
  // L3 CACHE CONFIGURATION (SHARED CACHE)
  //=============================================================================
  localparam int L3_CACHE_SIZE_BYTES       = 4096; //16*4*64
  localparam int L3_CACHE_LINE_SIZE_BYTES  = 16; // 4 Words
  localparam int L3_CACHE_ASSOCIATIVITY    = 4;

  localparam int L3_NUM_CACHE_LINES = L3_CACHE_SIZE_BYTES / L3_CACHE_LINE_SIZE_BYTES; //256
  localparam int L3_NUM_CACHE_SETS  = L3_NUM_CACHE_LINES / L3_CACHE_ASSOCIATIVITY; // 64

  localparam int L3_OFFSET_BITS = $clog2(L3_CACHE_LINE_SIZE_BYTES);
  localparam int L3_INDEX_BITS  = $clog2(L3_NUM_CACHE_SETS);
  localparam int L3_TAG_BITS    = ADDRESS_WIDTH - L3_INDEX_BITS - L3_OFFSET_BITS;
  localparam int MAX_MSHR = 4;
  
  localparam int WORDS_PER_LINE = L3_CACHE_LINE_SIZE_BYTES / (DATA_WIDTH/8);
  localparam int AXI_DATA_BYTES = DATA_WIDTH / 8;

  //=============================================================================
  // L3 CACHE LINE STRUCTURE (SHARED)
  //=============================================================================

  typedef enum logic [1:0] {
   L3_INVALID,
   L3_CLEAN,
   L3_DIRTY,
   L3_FILLING
  } l3_state_e;
  
  typedef struct {
    bit valid;
    bit [L3_TAG_BITS-1:0] tag;
    byte data[L3_CACHE_LINE_SIZE_BYTES];
    l3_state_e state;
  } scb_cache_line_s;

  typedef struct {
    bit device; 
    bit cacheable;
    bit write_back;
    bit write_through;
    bit read_allocate;
    bit write_allocate;
    bit bufferable;
    bit modifiable;
  } axi_cache_policy_s;

  //=============================================================================
  // UNIFIED L3 CACHE STORAGE (SINGLE SHARED CACHE)
  //=============================================================================
  
  scb_cache_line_s l3_cache[L3_NUM_CACHE_SETS][L3_CACHE_ASSOCIATIVITY];
  int l3_lru_counter[L3_NUM_CACHE_SETS][L3_CACHE_ASSOCIATIVITY];
  int l3_global_lru_tick;

  //=============================================================================
  // L3 CACHE STATISTICS (GLOBAL)
  //=============================================================================
  
  int l3_read_hits_per_master[int];
  int l3_read_misses_per_master[int];
  int l3_write_hits_per_master[int];
  int l3_write_misses_per_master[int];
  
  int l3_total_read_hits;
  int l3_total_read_misses;
  int l3_total_write_hits;
  int l3_total_write_misses;
  int l3_evictions;
  int l3_writebacks_to_memory;
  int l3_writeback_errors;

  //======================================================
  // SCB MISS TRACKING (Matches DUT refill pipeline)
  //======================================================
typedef struct {

   // ---------------- Allocation ----------------
   bit valid;
   bit is_write;
   int master;
   int txn_id;

   bit [L3_INDEX_BITS-1:0] index;
   bit [L3_TAG_BITS-1:0]   tag;
  bit [ADDRESS_WIDTH-1:0]    line_addr;

   int way;

   // ---------------- Write Offset Tracking 
   int start_word;
   int start_byte;

   // ---------------- AXI Tracking ----------------
   int slave;
   int beat_count;
   int expected_beats;

   bit ar_sent;
   bit resp_sent;
   bit done;

   // ---------------- Writeback FSM ----------------
   bit needs_writeback;
   bit wb_done;
   bit wb_error;
   bit[1:0] resp_code;

   // ---------------- Write Data Buffer 
  logic [DATA_WIDTH-1:0] wdata_buf[WORDS_PER_LINE];
  logic [STROBE_WIDTH-1:0] wstrb_buf[WORDS_PER_LINE];
  int wbeat_count;
  bit wlast_seen;
  bit rlast_seen;

   axi_cache_policy_s policy;

} scb_mshr_t;

  scb_mshr_t scb_mshr[MAX_MSHR];

  //Active R-channel tracking per slave
  int  active_r_mshr[NO_OF_SLAVES];
  bit  active_r_valid[NO_OF_SLAVES];

  // Write ownership locking
  bit scb_write_locked;
  int scb_write_owner;
  int scb_write_owner_set;
  int scb_write_owner_way;
  bit scb_write_owner_is_hit;
  bit [ADDRESS_WIDTH-1:0] scb_write_line;

  //Performance counter tracking
  bit wr_hit_counted[NO_OF_MASTERS];

  //=============================================================================
  // TRANSACTION TRACKING STRUCTURES
  //=============================================================================
  
  typedef struct {
    axi4_master_tx tx;
    int master_id;
    int slave_id;
    bit address_granted;
    bit write_data_complete;
    int beats_received;
  } pending_write_transaction_t;

  typedef struct {
    axi4_master_tx tx;
    int master_id;
    int slave_id;
    bit address_granted;
    bit expected_l3_hit;
    time addr_request_time;
    bit prediction_made;
    bit [ADDRESS_WIDTH-1:0] line_addr;
  } pending_read_transaction_t;

  pending_write_transaction_t pending_write_txns[int][int][bit[ID_WIDTH-1:0]][$];
  pending_read_transaction_t pending_read_txns[int][bit[ID_WIDTH-1:0]][$];

  //=============================================================================
  // REFERENCE MEMORY (MAIN DRAM)
  //=============================================================================
  
  logic[7:0] referenceData[int][longint];

  //=============================================================================
  // ROUND-ROBIN ARBITRATION TRACKING
  //=============================================================================
  
  int rr_write_next_master[int];
  int rr_write_pending_cnt[int][int];
  int rr_write_last_granted[int];
  
  int rr_read_next_master[int];
  int rr_read_pending_cnt[int][int];
  int rr_read_last_granted[int];

  event slave_write_addr_granted[int];
  event slave_read_addr_granted[int];

  //=============================================================================
  // TLM FIFOs
  //=============================================================================
  
  uvm_tlm_analysis_fifo#(axi4_master_tx) axi4_master_read_address_analysis_fifo[];
  uvm_tlm_analysis_fifo#(axi4_master_tx) axi4_master_read_data_analysis_fifo[];
  uvm_tlm_analysis_fifo#(axi4_master_tx) axi4_master_write_address_analysis_fifo[];
  uvm_tlm_analysis_fifo#(axi4_master_tx) axi4_master_write_data_analysis_fifo[];
  uvm_tlm_analysis_fifo#(axi4_master_tx) axi4_master_write_response_analysis_fifo[];
  
  uvm_tlm_analysis_fifo#(axi4_slave_tx) axi4_slave_read_address_analysis_fifo[];
  uvm_tlm_analysis_fifo#(axi4_slave_tx) axi4_slave_read_data_analysis_fifo[];
  uvm_tlm_analysis_fifo#(axi4_slave_tx) axi4_slave_write_address_analysis_fifo[];
  uvm_tlm_analysis_fifo#(axi4_slave_tx) axi4_slave_write_data_analysis_fifo[];
  uvm_tlm_analysis_fifo#(axi4_slave_tx) axi4_slave_write_response_analysis_fifo[];

  //=============================================================================
  // TRANSACTION COUNTERS
  //=============================================================================
  
  int axi4_master_tx_awaddr_count[];
  int axi4_slave_tx_awaddr_count[];
  int axi4_master_tx_wdata_count[];
  int axi4_slave_tx_wdata_count[];
  int axi4_master_tx_bresp_count[];
  int axi4_slave_tx_bresp_count[];
  int axi4_master_tx_araddr_count[];
  int axi4_slave_tx_araddr_count[];
  int axi4_master_tx_rdata_count[];
  int axi4_slave_tx_rdata_count[];
  int axi4_master_tx_rresp_count[];
  int axi4_slave_tx_rresp_count[];

  int total_master_tx_count = 0;
  int total_slave_tx_count = 0;
  
  //=============================================================================
  // COMPARISON RESULT COUNTERS
  //=============================================================================
  
  int byte_data_cmp_verified_awid_count;
  int byte_data_cmp_verified_awaddr_count;
  int byte_data_cmp_verified_awsize_count;
  int byte_data_cmp_verified_awlen_count;
  int byte_data_cmp_verified_awburst_count;
  int byte_data_cmp_verified_awcache_count;
  int byte_data_cmp_verified_awlock_count;
  int byte_data_cmp_verified_awprot_count;
  int byte_data_cmp_verified_wdata_count;
  int byte_data_cmp_verified_wstrb_count;
  int byte_data_cmp_verified_wlast_count;
  int byte_data_cmp_verified_bid_count;
  int byte_data_cmp_verified_bresp_count;
  int byte_data_cmp_verified_arid_count;
  int byte_data_cmp_verified_araddr_count;
  int byte_data_cmp_verified_arsize_count;
  int byte_data_cmp_verified_arlen_count;
  int byte_data_cmp_verified_arburst_count;
  int byte_data_cmp_verified_arcache_count;
  int byte_data_cmp_verified_arlock_count;
  int byte_data_cmp_verified_arprot_count;
  int byte_data_cmp_verified_arregion_count;
  int byte_data_cmp_verified_arqos_count;
  int byte_data_cmp_verified_rid_count;
  int byte_data_cmp_verified_rdata_count;
  int byte_data_cmp_verified_rresp_count;
  int byte_data_cmp_verified_rlast_count;
  
  int byte_data_cmp_failed_awid_count;
  int byte_data_cmp_failed_awaddr_count;
  int byte_data_cmp_failed_awsize_count;
  int byte_data_cmp_failed_awlen_count;
  int byte_data_cmp_failed_awburst_count;
  int byte_data_cmp_failed_awcache_count;
  int byte_data_cmp_failed_awlock_count;
  int byte_data_cmp_failed_awprot_count;
  int byte_data_cmp_failed_wdata_count;
  int byte_data_cmp_failed_wstrb_count;
  int byte_data_cmp_failed_wlast_count;
  int byte_data_cmp_failed_bid_count;
  int byte_data_cmp_failed_bresp_count;
  int byte_data_cmp_failed_arid_count;
  int byte_data_cmp_failed_araddr_count;
  int byte_data_cmp_failed_arsize_count;
  int byte_data_cmp_failed_arlen_count;
  int byte_data_cmp_failed_arburst_count;
  int byte_data_cmp_failed_arcache_count;
  int byte_data_cmp_failed_arlock_count;
  int byte_data_cmp_failed_arprot_count;
  int byte_data_cmp_failed_arregion_count;
  int byte_data_cmp_failed_arqos_count;
  int byte_data_cmp_failed_rid_count;
  int byte_data_cmp_failed_rdata_count;
  int byte_data_cmp_failed_rresp_count;
  int byte_data_cmp_failed_rlast_count;

  int rr_write_violations;
  int rr_read_violations;
  int rr_write_grants;
  int rr_read_grants;

  //=============================================================================
  // SLAVE ADDRESS CONFIGURATION
  //=============================================================================
  
  bit[ADDRESS_WIDTH-1:0] SLAVE_START_ADDR[];
  bit[ADDRESS_WIDTH-1:0] SLAVE_END_ADDR[];

  int nonExistantMemRead;
  
  axi4_env_config axi4_env_cfg_h;
  axi4_slave_agent_config axi4_slave_agent_cfg_h[];

  //=============================================================================
  // FUNCTION PROTOTYPES
  //=============================================================================
  
  // Constructor and UVM phases
  extern function new(string name = "axi4_scoreboard", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);
  extern virtual function void check_phase(uvm_phase phase);
  extern virtual function void report_phase(uvm_phase phase);
  
  // L3 cache functions
  extern virtual function void init_l3_cache_model();
    
  extern virtual function void l3_cache_decode_address(
    input  bit [ADDRESS_WIDTH-1:0] addr,
    output bit [L3_TAG_BITS-1:0]   tag,
    output bit [L3_INDEX_BITS-1:0] index,
    output bit [L3_OFFSET_BITS-1:0] offset
  );

  extern virtual function bit l3_cache_lookup(
    input  bit [ADDRESS_WIDTH-1:0] addr,
    input  axi_cache_policy_s   policy,
    output int                  hit_way,
    output l3_state_e           state
  );

  extern virtual function int unsigned l3_find_lru_way(
    input int unsigned set_index
  );

  extern virtual function void l3_update_lru(
    input int unsigned set_index,
    input int unsigned way
  );

  extern virtual function void l3_set_line_state(
    input int set_index,
    input int way,
    input l3_state_e new_state
  );

  extern virtual function void l3_writeback_to_memory(
    input int set_index,
    input int way
  );

  extern virtual function int scb_allocate_mshr(
    input bit [ADDRESS_WIDTH-1:0] addr,
    input int master,
    input int txn_id,
    input bit is_write
  );
  
  extern virtual function int scb_find_existing_mshr(
    input bit [ADDRESS_WIDTH-1:0] addr
  );
  
  extern virtual function void scb_update_mshr_beat(
    input int slave,
    input logic [DATA_WIDTH-1:0] data,
    input bit rlast
  );
  
  extern virtual function void scb_update_mshr_write_data(
  input int master, input int txn_id,
  input logic [DATA_WIDTH-1:0] data,
  input logic [(DATA_WIDTH/8)-1:0] strb);
  
  extern virtual function void scb_release_mshr(input int i, input bit resp_accepted);

  // Request handlers
  extern virtual function void l3_handle_read_request(
    input int master_id,
    input axi4_master_tx m_tx,
    output bit expected_hit
  );
  
  extern virtual function void l3_handle_write_request(
    input int master_id,
    input axi4_master_tx m_tx,
    input int slave_idx
  );
  
  extern virtual function void l3_handle_write_data(
    input int master_id,
    input axi4_master_tx m_tx
  );
  
    extern virtual function bit[ADDRESS_WIDTH-1:0] get_line_base_addr(
    bit[ADDRESS_WIDTH-1:0] addr
  );
  
  // NEW: Helper functions for fixes
  extern virtual function bit line_under_refill(
    input int index,
    input int tag
  );
  
  extern virtual function bit line_has_active_mshr(
    input int index,
    input int way
  );
  
  // Reference model and utility functions
    extern virtual function int get_slave_index(logic[ADDRESS_WIDTH-1:0] addr);
  extern virtual function void ref_model_write(axi4_master_tx m_tx, int slave_idx, int master_idx);
  extern virtual function void ref_model_read(axi4_master_tx m_tx, int slave_idx);
  
  // Arbitration checking
  extern virtual function void check_write_rr_arbitration(int slave_id, int granted_master);
  extern virtual function void check_read_rr_arbitration(int slave_id, int granted_master);
  
  // AXI cache policy decoder
  extern virtual function axi_cache_policy_s axi_decode_cache_policy(
    bit [3:0] axcache,
    bit is_read
  );
  
 // Comparison tasks
 extern virtual task axi4_write_address_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id, input int slave_id);
 extern virtual task axi4_write_data_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id, input int slave_id);
 extern virtual task axi4_write_response_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id, input int slave_id);
 extern virtual task axi4_read_address_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id, input int slave_id);
 extern virtual task axi4_read_data_comparison(input axi4_master_tx exp_tx, input axi4_master_tx act_tx, input int master_id, input int slave_id, input bit expected_hit);
endclass : axi4_scoreboard

//=============================================================================
// IMPLEMENTATION
//=============================================================================

function axi4_scoreboard::new(string name = "axi4_scoreboard", 
                                       uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//=============================================================================
// Function: build_phase
//=============================================================================
function void axi4_scoreboard::build_phase(uvm_phase phase);
  super.build_phase(phase);
  
  if(!uvm_config_db#(axi4_env_config)::get(this, "", "axi4_env_config", axi4_env_cfg_h)) begin
    `uvm_fatal("FATAL_ENV_CONFIG", "Couldn't get axi4_env_config from config_db")
  end
  
  // Initialize L3 cache model
  init_l3_cache_model();
  
  // Allocate arrays for masters
  axi4_master_read_address_analysis_fifo = new[NO_OF_MASTERS];
  axi4_master_read_data_analysis_fifo = new[NO_OF_MASTERS];
  axi4_master_write_address_analysis_fifo = new[NO_OF_MASTERS];
  axi4_master_write_data_analysis_fifo = new[NO_OF_MASTERS];
  axi4_master_write_response_analysis_fifo = new[NO_OF_MASTERS];
  
  axi4_master_tx_awaddr_count = new[NO_OF_MASTERS];
  axi4_master_tx_wdata_count = new[NO_OF_MASTERS];
  axi4_master_tx_bresp_count = new[NO_OF_MASTERS];
  axi4_master_tx_araddr_count = new[NO_OF_MASTERS];
  axi4_master_tx_rdata_count = new[NO_OF_MASTERS];
  axi4_master_tx_rresp_count = new[NO_OF_MASTERS];
  
  
  foreach(l3_read_hits_per_master[i]) begin
    l3_read_hits_per_master[i] = 0;
    l3_read_misses_per_master[i] = 0;
    l3_write_hits_per_master[i] = 0;
    l3_write_misses_per_master[i] = 0;
    wr_hit_counted[i] = 0;
  end
  
  // Allocate arrays for slaves
  axi4_slave_read_address_analysis_fifo = new[NO_OF_SLAVES];
  axi4_slave_read_data_analysis_fifo = new[NO_OF_SLAVES];
  axi4_slave_write_address_analysis_fifo = new[NO_OF_SLAVES];
  axi4_slave_write_data_analysis_fifo = new[NO_OF_SLAVES];
  axi4_slave_write_response_analysis_fifo = new[NO_OF_SLAVES];
  
  axi4_slave_tx_awaddr_count = new[NO_OF_SLAVES];
  axi4_slave_tx_wdata_count = new[NO_OF_SLAVES];
  axi4_slave_tx_bresp_count = new[NO_OF_SLAVES];
  axi4_slave_tx_araddr_count = new[NO_OF_SLAVES];
  axi4_slave_tx_rdata_count = new[NO_OF_SLAVES];
  axi4_slave_tx_rresp_count = new[NO_OF_SLAVES];
  
  axi4_slave_agent_cfg_h = new[NO_OF_SLAVES];
  SLAVE_START_ADDR = new[NO_OF_SLAVES];
  SLAVE_END_ADDR = new[NO_OF_SLAVES];
  
  // Create TLM FIFOs for each master
  foreach(axi4_master_read_address_analysis_fifo[i]) begin
    axi4_master_read_address_analysis_fifo[i] = new($sformatf("axi4_master_read_address_analysis_fifo[%0d]", i), this);
    axi4_master_read_data_analysis_fifo[i] = new($sformatf("axi4_master_read_data_analysis_fifo[%0d]", i), this);
    axi4_master_write_address_analysis_fifo[i] = new($sformatf("axi4_master_write_address_analysis_fifo[%0d]", i), this);
    axi4_master_write_data_analysis_fifo[i] = new($sformatf("axi4_master_write_data_analysis_fifo[%0d]", i), this);
    axi4_master_write_response_analysis_fifo[i] = new($sformatf("axi4_master_write_response_analysis_fifo[%0d]", i), this);
  end
  
  // Create TLM FIFOs for each slave
  foreach(axi4_slave_read_address_analysis_fifo[i]) begin
    axi4_slave_read_address_analysis_fifo[i] = new($sformatf("axi4_slave_read_address_analysis_fifo[%0d]", i), this);
    axi4_slave_read_data_analysis_fifo[i] = new($sformatf("axi4_slave_read_data_analysis_fifo[%0d]", i), this);
    axi4_slave_write_address_analysis_fifo[i] = new($sformatf("axi4_slave_write_address_analysis_fifo[%0d]", i), this);
    axi4_slave_write_data_analysis_fifo[i] = new($sformatf("axi4_slave_write_data_analysis_fifo[%0d]", i), this);
    axi4_slave_write_response_analysis_fifo[i] = new($sformatf("axi4_slave_write_response_analysis_fifo[%0d]", i), this);
    
    if(!uvm_config_db#(axi4_slave_agent_config)::get(this, "", $sformatf("axi4_slave_agent_config[%0d]", i), axi4_slave_agent_cfg_h[i])) begin
      `uvm_fatal("FATAL_SA_AGENT_CONFIG", $sformatf("Couldn't get axi4_slave_agent_config[%0d] from config_db", i))
    end
    
    SLAVE_START_ADDR[i] = axi4_slave_agent_cfg_h[i].min_address;
    SLAVE_END_ADDR[i] = axi4_slave_agent_cfg_h[i].max_address;
  end
  
  // Initialize Round-Robin tracking
  for(int s = 0; s < NO_OF_SLAVES; s++) begin
    rr_write_next_master[s] = 0;
    rr_write_last_granted[s] = -1;
    rr_read_next_master[s] = 0;
    rr_read_last_granted[s] = -1;
    
    for(int m = 0; m < NO_OF_MASTERS; m++) begin
      rr_write_pending_cnt[s][m] = 0;
      rr_read_pending_cnt[s][m] = 0;
    end
  end

  for(int i=0;i<NO_OF_SLAVES; i++) begin
    for(int j=0;j<4096*NO_OF_SLAVES;j++) begin
      referenceData[i][j]=j;
    end
  end
  
endfunction : build_phase

function void axi4_scoreboard::check_phase(uvm_phase phase);
  super.check_phase(phase);
endfunction

function void axi4_scoreboard::report_phase(uvm_phase phase);
  super.report_phase(phase);
endfunction





//=============================================================================
// Function: init_l3_cache_model 
//=============================================================================
function void axi4_scoreboard::init_l3_cache_model();

  `uvm_info("L3_CACHE_INIT",
  $sformatf({
    "L3 Cache Model Configuration (SHARED):\n",
    "  L3 Cache Size    : %0d bytes (%0d KB)\n",
    "  Line Size        : %0d bytes\n",
    "  Associativity    : %0d-way\n",
    "  Number of Lines  : %0d\n",
    "  Number of Sets   : %0d\n",
    "  Offset Bits      : %0d\n",
    "  Index Bits       : %0d\n",
    "  Tag Bits         : %0d\n",
    "  Words Per Line   : %0d\n"
  },
  L3_CACHE_SIZE_BYTES,
  L3_CACHE_SIZE_BYTES/1024,
  L3_CACHE_LINE_SIZE_BYTES,
  L3_CACHE_ASSOCIATIVITY,
  L3_NUM_CACHE_LINES,
  L3_NUM_CACHE_SETS,
  L3_OFFSET_BITS,
  L3_INDEX_BITS,
  L3_TAG_BITS,
  WORDS_PER_LINE
), UVM_LOW)

  if(ADDRESS_WIDTH != L3_TAG_BITS + L3_INDEX_BITS + L3_OFFSET_BITS) begin
    `uvm_fatal("ADDR_DECODE", $sformatf("Address split mismatch: ADDR=%0d TAG+IDX+OFF=%0d", ADDRESS_WIDTH, L3_TAG_BITS+L3_INDEX_BITS+L3_OFFSET_BITS))
  end  

  // CACHE ARRAY RESET
  for(int s = 0; s < L3_NUM_CACHE_SETS; s++) begin
    for(int w = 0; w < L3_CACHE_ASSOCIATIVITY; w++) begin
      l3_cache[s][w].valid = 0;
      l3_cache[s][w].tag   = '0;
      l3_cache[s][w].state = L3_INVALID;

      foreach(l3_cache[s][w].data[i]) begin
        l3_cache[s][w].data[i] = '0;
      end

      l3_lru_counter[s][w] = w;
    end
  end

  // GLOBAL STATE RESET
  l3_total_read_hits      = 0;
  l3_total_read_misses    = 0;
  l3_total_write_hits     = 0;
  l3_total_write_misses   = 0;
  l3_evictions            = 0;
  l3_writebacks_to_memory = 0;
  l3_writeback_errors     = 0;

  l3_global_lru_tick  = 0;

  // Initialize MSHR array
  for(int i = 0; i < MAX_MSHR; i++) begin
    scb_mshr[i].valid = 0;
    scb_mshr[i].done = 0;
    scb_mshr[i].ar_sent = 0;
    scb_mshr[i].wb_done = 0;
    scb_mshr[i].wb_error = 0;
    scb_mshr[i].resp_code = 2'b00;
  end

  // Initialize write ownership (FIX ISSUE #5)
  scb_write_locked = 0;
  scb_write_owner  = -1;
  scb_write_owner_set = -1;
  scb_write_owner_way = -1;
  scb_write_owner_is_hit = 0;

  // Initialize R-channel tracking (FIX ISSUE #2)
  for(int s = 0; s < NO_OF_SLAVES; s++) begin
    active_r_valid[s] = 0;
    active_r_mshr[s] = -1;
  end

endfunction : init_l3_cache_model


   

   
//=============================================================================
// Function: axi_decode_cache_policy
//=============================================================================
function axi4_scoreboard::axi_cache_policy_s axi4_scoreboard::axi_decode_cache_policy(
  bit [3:0] axcache,
  bit is_read
);

  axi_cache_policy_s p;
  p = '{default:0};

  p.bufferable = axcache[0];
  p.modifiable = axcache[1];

  // DEVICE MEMORY
  if(axcache == 4'b0000 || axcache == 4'b0001) begin
    p.device     = 1;
    p.modifiable = 0;
    return p;
  end

  // NON CACHEABLE NORMAL
  if(axcache[3:2] == 2'b00) begin
    p.cacheable = 0;
    return p;
  end

  p.cacheable = 1;

  // CACHE TYPE (PATTERN BASED)
  case(axcache)
    // WRITE THROUGH
    4'b1010, 4'b0110, 4'b1110:
      p.write_through = 1;

    // WRITE BACK
    4'b1011, 4'b0111, 4'b1111:
      p.write_back = 1;
  endcase

  // ALLOCATION (CHANNEL AWARE)
  if(is_read) begin
    p.read_allocate  = axcache[2];
  end
  else begin
    p.write_allocate = axcache[3];
  end

  return p;

endfunction 


//=============================================================================
// Function: l3_cache_decode_address
//=============================================================================
function void axi4_scoreboard::l3_cache_decode_address(
  input  bit [ADDRESS_WIDTH-1:0] addr,
  output bit [L3_TAG_BITS-1:0] tag,
  output bit [L3_INDEX_BITS-1:0] index,
  output bit [L3_OFFSET_BITS-1:0] offset);

  offset = addr[L3_OFFSET_BITS-1:0];
  index  = addr[L3_OFFSET_BITS +: L3_INDEX_BITS];
  tag    = addr[L3_OFFSET_BITS + L3_INDEX_BITS +: L3_TAG_BITS];

endfunction : l3_cache_decode_address

//=============================================================================
// Function: l3_cache_lookup (FIX ISSUE #5 & #8)
// Detects cache hits while blocking:
//   - Lines under refill (FIX #8)
//   - Lines being written by locked master (FIX #5)
//=============================================================================
function bit axi4_scoreboard::l3_cache_lookup(
  input  bit [ADDRESS_WIDTH-1:0] addr,
  input  axi_cache_policy_s    policy,
  output int                   hit_way,
  output l3_state_e            state);
  bit [L3_TAG_BITS-1:0]   tag;
  bit [L3_INDEX_BITS-1:0] index;
  bit [L3_OFFSET_BITS-1:0] offset;

  // Default outputs
  hit_way = -1;
  state   = L3_INVALID;

  // AXI4 RULE — Device or Non-cacheable bypass
  if(policy.device || !policy.cacheable)
    return 0;

  // AXI4 RULE — no lookup if allocate bits = 00
  if(!policy.read_allocate && !policy.write_allocate)
    return 0;

  // Address decode
  l3_cache_decode_address(addr, tag, index, offset);

  // FIX ISSUE #8: Block lookup if line is under refill
  if(line_under_refill(index, tag)) begin
    `uvm_info("L3_LOOKUP_BLOCK", 
      $sformatf("Blocked lookup - line under refill: idx=%0d tag=0x%0h", index, tag), 
      UVM_HIGH)
    return 0;
  end

  // Search set
  for(int w = 0; w < L3_CACHE_ASSOCIATIVITY; w++) begin
    if(l3_cache[index][w].valid &&
       l3_cache[index][w].state != L3_FILLING &&
       l3_cache[index][w].state != L3_INVALID &&
       l3_cache[index][w].tag   == tag) begin

      // FIX ISSUE #5: Block read hit if write-locked on same line
      if(scb_write_locked && 
         scb_write_owner_is_hit &&
         scb_write_owner_set == index &&
         scb_write_owner_way == w) begin
        `uvm_info("L3_LOOKUP_BLOCK", 
          $sformatf("Blocked read hit - write locked: idx=%0d way=%0d owner=M%0d", 
                    index, w, scb_write_owner), 
          UVM_HIGH)
        return 0; // Treat as miss to match RTL behavior
      end

      hit_way = w;
      state   = l3_cache[index][w].state;
      return 1;
    end
  end

  return 0;

endfunction : l3_cache_lookup

//=============================================================================
// Function: l3_find_lru_way
//Lower number = OLDER
//Higher number = NEWER
//=============================================================================
function int unsigned axi4_scoreboard::l3_find_lru_way(int unsigned set_index);
  int victim_way = -1;
  int max_lru    = -1;

  // Prefer INVALID ways (fast allocation, no eviction)
  for(int w = 0; w < L3_CACHE_ASSOCIATIVITY; w++) begin
    if(l3_cache[set_index][w].state == L3_INVALID) begin
      `uvm_info("L3_INAVLID_WAY_LOOP",
        $sformatf("Set=%0d | Selected INVALID way=%0d", set_index, w),
        UVM_LOW)
      return w;
    end
  end

  // Choose true LRU among CLEAN/DIRTY, NEVER select FILLING ways
  for(int w = 0; w < L3_CACHE_ASSOCIATIVITY; w++) begin
    if(l3_cache[set_index][w].state != L3_FILLING && !line_has_active_mshr(set_index, w)) begin
      if(l3_lru_counter[set_index][w] > max_lru) begin
        max_lru    = l3_lru_counter[set_index][w];
        victim_way = w;
      end
    end
  end

  // DUT safety fallback (pipeline saturation)
  if(victim_way == -1) begin
    `uvm_warning("L3_LRU",
      $sformatf("All ways filling in set %0d — forcing way0 (DUT fallback)", set_index))
    victim_way = 0;
  end

  if(victim_way != -1) begin
    `uvm_info("L3_LRU_LOOP",
      $sformatf("Set=%0d | Selected LRU way=%0d | LRU value=%0d",
        set_index, victim_way, max_lru),
      UVM_LOW)
  end

  return victim_way;

endfunction : l3_find_lru_way

//=============================================================================
// Function: l3_update_lru (matches RTL age-based LRU)
//=============================================================================
function void axi4_scoreboard::l3_update_lru(int unsigned set_index, int unsigned way);

  // Don't update invalid or filling lines
  if(l3_cache[set_index][way].state == L3_INVALID ||
     l3_cache[set_index][way].state == L3_FILLING)
    return;

  // Increment all counters in set (aging) - matches RTL
  for(int w = 0; w < L3_CACHE_ASSOCIATIVITY; w++) begin
    if(l3_lru_counter[set_index][w] < 255) begin // 8-bit wrap like RTL
      l3_lru_counter[set_index][w]++;
    end
  end

  // Reset accessed way to 0 (most recently used)
  l3_lru_counter[set_index][way] = 0;

endfunction : l3_update_lru

//=============================================================================
// Function: l3_set_line_state
//=============================================================================
function void axi4_scoreboard::l3_set_line_state(
  input int set_index,
  input int way,
  input l3_state_e new_state);

  l3_cache[set_index][way].state = new_state;

  // Maintain valid bit
  if(new_state == L3_INVALID)
    l3_cache[set_index][way].valid = 0;
  else
    l3_cache[set_index][way].valid = 1;

endfunction : l3_set_line_state

//=============================================================================
// Function: l3_writeback_to_memory 
//=============================================================================
function void axi4_scoreboard::l3_writeback_to_memory(
  input int set_index,
  input int way
);

  bit [ADDRESS_WIDTH-1:0] wb_addr;
  int                  slave_idx;
  int                  word_i;
  int                  lane;

  // ── Only write back if the line is actually dirty ─────────────────────────
  if(l3_cache[set_index][way].state != L3_DIRTY) begin
    `uvm_info("L3_WB_SKIP",
      $sformatf("Skipping writeback: Set=%0d Way=%0d State=%s — not dirty",
                set_index, way, l3_cache[set_index][way].state.name()),
      UVM_HIGH)
    return;
  end

  // ── Reconstruct the cache line base address from tag + index ─────────────
  // Matches DUT:  s_awaddr[sid] = {tag_array[idx][way], idx, {OFFSET_BITS{1'b0}}}
  wb_addr = { l3_cache[set_index][way].tag,
              set_index[L3_INDEX_BITS-1:0],
              {L3_OFFSET_BITS{1'b0}} };

  // ── Validate the address maps to a slave ─────────────────────────────────
  slave_idx = get_slave_index(wb_addr);
  if(slave_idx == -1) begin
    `uvm_error("L3_WB_NO_SLAVE",
      $sformatf("Writeback addr=0x%0h maps to no slave — Set=%0d Way=%0d",
                wb_addr, set_index, way))
    return;
  end

  `uvm_info("L3_WB_START",
    $sformatf("Writeback: Set=%0d Way=%0d Addr=0x%0h Slave=%0d",
              set_index, way, wb_addr, slave_idx),
    UVM_MEDIUM)

  // ── Flush dirty bytes to referenceData[] ─────────────────────────────────

  for(int byte_i = 0; byte_i < L3_CACHE_LINE_SIZE_BYTES; byte_i++) begin
    word_i = byte_i / (DATA_WIDTH/8);
    lane   = byte_i % (DATA_WIDTH/8);
    referenceData[slave_idx][wb_addr + byte_i] =
      l3_cache[set_index][way].data[word_i][8*lane +: 8];
  end

  l3_set_line_state(set_index, way, L3_CLEAN);

  l3_writebacks_to_memory++;

  `uvm_info("L3_WB_FLUSHED",$sformatf("Dirty line flushed to refMem: Set=%0d Way=%0d Addr=0x%0h Slave=%0d — awaiting BRESP",set_index, way, wb_addr, slave_idx),UVM_MEDIUM)

endfunction : l3_writeback_to_memory

//=============================================================================
// Function: line_under_refill (FIX ISSUE #8)
//=============================================================================
function bit axi4_scoreboard::line_under_refill(input int index, input int tag);
  for(int i = 0; i < MAX_MSHR; i++) begin
    if(scb_mshr[i].valid &&
       !scb_mshr[i].done &&
       scb_mshr[i].index == index &&
       scb_mshr[i].tag == tag)
      return 1;
  end
  return 0;
endfunction : line_under_refill

//=============================================================================
// Function: line_has_active_mshr (FIX ISSUE #7)
//=============================================================================
function bit axi4_scoreboard::line_has_active_mshr(input int index, input int way);
  for(int i = 0; i < MAX_MSHR; i++) begin
    if(scb_mshr[i].valid &&
       scb_mshr[i].index == index &&
       scb_mshr[i].way == way)
      return 1;
  end
  return 0;
endfunction : line_has_active_mshr

//=============================================================================
// Function: get_line_base_addr
//=============================================================================
function bit[ADDRESS_WIDTH-1:0] axi4_scoreboard::get_line_base_addr(
  bit[ADDRESS_WIDTH-1:0] addr);
  return {addr[ADDRESS_WIDTH-1:L3_OFFSET_BITS], {L3_OFFSET_BITS{1'b0}}};
endfunction : get_line_base_addr

//=============================================================================
// Function: scb_find_existing_mshr
//=============================================================================
function int axi4_scoreboard::scb_find_existing_mshr(
    input bit [ADDRESS_WIDTH-1:0] addr);

   logic [ADDRESS_WIDTH-1:0] line_base;
   line_base = get_line_base_addr(addr);

   for(int i=0;i<MAX_MSHR;i++) begin
      if(scb_mshr[i].valid &&
         scb_mshr[i].line_addr == line_base)
         return i;
   end

   return -1;
endfunction: scb_find_existing_mshr

//=============================================================================
// Function: scb_allocate_mshr
//=============================================================================
function int axi4_scoreboard::scb_allocate_mshr(
    input bit [ADDRESS_WIDTH-1:0] addr,
    input int                    master,
    input int                    txn_id,
    input bit                    is_write);

  int                      idx;
  int                      slave;
  int                      way;
  bit [L3_TAG_BITS-1:0]    tag;
  bit [L3_INDEX_BITS-1:0]  index;
  bit [L3_OFFSET_BITS-1:0] offset;
  logic [ADDRESS_WIDTH-1:0]   line_base;

  idx = scb_find_existing_mshr(addr);
  if(idx != -1) begin
    `uvm_info("L3_MSHR_MERGE",
              $sformatf("Merging request for line 0x%0h into existing MSHR[%0d]",
                        addr, idx),
              UVM_MEDIUM)
    return idx;
  end

  l3_cache_decode_address(addr, tag, index, offset);
  way       = l3_find_lru_way(index);
  slave     = get_slave_index(addr);
  line_base = get_line_base_addr(addr);

   `uvm_info("MSHR_ALLOC_ENTRY",$sformatf("ENTER scb_allocate_mshr: addr=0x%0h master=%0d txn_id=0x%0h is_write=%0b -> slave=%0d index=%0d way=%0d active_r_valid[slave]=%0b",addr, master, txn_id, is_write, slave, index, way,(slave != -1) ? active_r_valid[slave] : 1'bx),UVM_LOW)
  
  if(slave == -1) begin
    `uvm_error("MSHR_ALLOC", $sformatf("No slave mapped for addr=0x%0h", addr))
    return -1;
  end

  for(int i = 0; i < MAX_MSHR; i++) begin
    if(!scb_mshr[i].valid) begin

      scb_mshr[i].needs_writeback =
        (l3_cache[index][way].valid &&
         l3_cache[index][way].state == L3_DIRTY);
    `uvm_info("MSHR_DEBUG",
  $sformatf("set=%0d way=%0d | mshr_index=%0d | cache_valid=%0d state=%0d | needs_writeback=%0d",
    index,
    way,
    i,
    l3_cache[index][way].valid,
    l3_cache[index][way].state,
    scb_mshr[i].needs_writeback
  ),
  UVM_LOW)

      scb_mshr[i].valid       = 1;
      scb_mshr[i].done        = 0;
      scb_mshr[i].ar_sent     = 0;
      scb_mshr[i].wb_done     = !scb_mshr[i].needs_writeback;
      scb_mshr[i].line_addr   = line_base;
      scb_mshr[i].master      = master;
      scb_mshr[i].txn_id      = txn_id;
      scb_mshr[i].is_write    = is_write;   
      scb_mshr[i].slave       = slave;
      scb_mshr[i].index       = index;
      scb_mshr[i].way         = way;
      scb_mshr[i].tag         = tag;
      scb_mshr[i].beat_count  = 0;
      scb_mshr[i].wbeat_count = 0;
      scb_mshr[i].wlast_seen  = 0;
      scb_mshr[i].rlast_seen  = 0;
      scb_mshr[i].resp_code   = 2'b00;
      scb_mshr[i].wb_error    = 0;

      if(scb_mshr[i].needs_writeback)
        l3_writeback_to_memory(index, way);

      l3_set_line_state(index, way, L3_FILLING);

      $display("[SCB_MSHR_ALLOC] time=%0t mshr=%0d master=%0d addr=0x%0h index=%0d tag=0x%0h way=%0d is_write=%0b needs_wb=%0b slave=%0d", $time, i, master, addr, index, tag, way, is_write,scb_mshr[i].needs_writeback, slave);

      return i;
    end
  end

  `uvm_warning("MSHR_FULL", $sformatf("All MSHRs busy for addr=0x%0h", addr))
  return -1;

endfunction : scb_allocate_mshr

//=============================================================================
// Function: scb_update_mshr_beat
//=============================================================================
function void axi4_scoreboard::scb_update_mshr_beat(
    input int slave,
    input logic [DATA_WIDTH-1:0] data,  
    input bit rlast);
    int i;
   if(!active_r_valid[slave]) return;

   i = active_r_mshr[slave];

   if(!scb_mshr[i].valid) return;
   if(scb_mshr[i].beat_count >= WORDS_PER_LINE) return;

   for(int b = 0; b < AXI_DATA_BYTES; b++) begin
     int byte_offset = scb_mshr[i].beat_count * AXI_DATA_BYTES + b;
     
     if(byte_offset < L3_CACHE_LINE_SIZE_BYTES) begin
       l3_cache[scb_mshr[i].index][scb_mshr[i].way].data[byte_offset] = 
         data[8*b +: 8];
     end
   end

   scb_mshr[i].beat_count++;

   if(rlast)
      scb_mshr[i].done = 1;
      
      `uvm_info("MSHR_REFILL_DONE",
        $sformatf("MSHR[%0d] refill complete: Beats=%0d Index=%0d Way=%0d",
                  i, scb_mshr[i].beat_count, scb_mshr[i].index, scb_mshr[i].way),
        UVM_HIGH)

endfunction : scb_update_mshr_beat

//=============================================================================
// Function: scb_update_mshr_write_data 
//=============================================================================
function void axi4_scoreboard::scb_update_mshr_write_data(
    input int                        master,
    input int                        txn_id,
    input logic [DATA_WIDTH-1:0]     data,
    input logic [(DATA_WIDTH/8)-1:0] strb);

  int b; 

  for(int i = 0; i < MAX_MSHR; i++) begin
    if(scb_mshr[i].valid    &&
       scb_mshr[i].is_write &&      
       scb_mshr[i].master == master &&
       scb_mshr[i].txn_id == txn_id &&
       !scb_mshr[i].done) begin

      b = scb_mshr[i].wbeat_count; 

      if(b < WORDS_PER_LINE) begin
        scb_mshr[i].wdata_buf[b] = data;
        scb_mshr[i].wstrb_buf[b] = strb;
        scb_mshr[i].wbeat_count++;
      end else begin
        `uvm_warning("MSHR_WDATA_OVERFLOW",
          $sformatf("MSHR[%0d] wbeat_count=%0d >= WORDS_PER_LINE=%0d",
                    i, b, WORDS_PER_LINE))
      end

    end
  end

endfunction : scb_update_mshr_write_data

//=============================================================================
// Function: apply_write_merge
// Word-local merge with byte offset support
//=============================================================================
function void apply_write_merge(
  inout logic [DATA_WIDTH-1:0] line_data,
      input  logic [DATA_WIDTH-1:0] wdata,
  input  logic [STROBE_WIDTH-1:0] wstrb);

  if(STROBE_WIDTH*8 != DATA_WIDTH)
   `uvm_error("MERGE","WSTRB width mismatch")

    for(int b = 0; b < STROBE_WIDTH; b++) begin
      if(wstrb[b]) begin
         line_data[b*8 +: 8] = wdata[b*8 +: 8];
      end
   end

endfunction:apply_write_merge

    
//=============================================================================
// Function: scb_release_mshr
//=============================================================================
function void axi4_scoreboard::scb_release_mshr(
    input int i,
    input bit resp_accepted);
    int set,way,base,s;
   if(i < 0 || i >= MAX_MSHR)
      return;

   if(!scb_mshr[i].valid)
      return;

   if(!scb_mshr[i].done)
      return;

   if(!resp_accepted)
      return;

    set  = scb_mshr[i].index;  
    way  = scb_mshr[i].way;
    base = scb_mshr[i].start_word;

   // Apply buffered writes after refill
   for(int b = 0; b < scb_mshr[i].wbeat_count; b++) begin
      int line_word;
       line_word = base + b;
      if(line_word >= WORDS_PER_LINE)
         break;
      $display("[SCB_MERGE_BEAT] time=%0t mshr=%0d set=%0d way=%0d word=%0d wdata=0x%0h wstrb=0x%0h pre_merge=0x%0h",$time, i, set, way, line_word,scb_mshr[i].wdata_buf[b],scb_mshr[i].wstrb_buf[b],l3_cache[set][way].data[line_word]);
      apply_write_merge(
         l3_cache[set][way].data[line_word],
         scb_mshr[i].wdata_buf[b],
         scb_mshr[i].wstrb_buf[b]);
     $display("[SCB_MERGE_BEAT_RESULT] word[%0d] = 0x%0h (after merge)",line_word, l3_cache[set][way].data[line_word]);
   end

   // Update line state
   if(scb_mshr[i].wbeat_count > 0)
      l3_set_line_state(set, way, L3_DIRTY);
   else
      l3_set_line_state(set, way, L3_CLEAN);
  
  $display("[SCB_LINE_FINAL] time=%0t mshr=%0d set=%0d way=%0d tag=0x%0h state=%0s",$time, i, set, way,scb_mshr[i].tag,(scb_mshr[i].wbeat_count > 0) ? "DIRTY" : "CLEAN");
  for(int wb = 0; wb < WORDS_PER_LINE; wb++)
    $display("  [SCB_LINE_FINAL_DATA] word[%0d] = %p",wb, l3_cache[set][way].data[wb*AXI_DATA_BYTES +: AXI_DATA_BYTES]);

   // UPDATE LRU ON SUCCESSFUL COMPLETION
   if(scb_mshr[i].resp_code == 2'b00) begin
     l3_update_lru(set, way);
   end

   // Release slave refill ownership
    s = scb_mshr[i].slave;
   if(s >= 0 && s < NO_OF_SLAVES) begin
      active_r_valid[s] = 0;
      active_r_mshr[s]  = -1;
   end

   $display("[SCB_MSHR_CLEAR] time=%0t mshr=%0d master=%0d slave=%0d set=%0d way=%0d line=0x%0h is_write=%0b wbeat_count=%0d resp=0x%0h",$time, i,scb_mshr[i].master,scb_mshr[i].slave,scb_mshr[i].index,scb_mshr[i].way,scb_mshr[i].line_addr,scb_mshr[i].is_write,scb_mshr[i].wbeat_count,scb_mshr[i].resp_code);
     
    scb_mshr[i] = '{default:0};

endfunction : scb_release_mshr

    
//==========================================================================
//  L3 HANDLE READ REQUEST
//==========================================================================
function void axi4_scoreboard::l3_handle_read_request(
    input int master_id,
    input axi4_master_tx m_tx,
    output bit expected_hit
  );
  
  axi_cache_policy_s policy; // policy : decoded AXI AxCACHE behavior
  int hit_way; // hit_way : which way matched (if hit)
  l3_state_e state; // state : CLEAN / DIRTY / INVALID / FILLING
  
  bit [L3_TAG_BITS-1:0] tag;           // Used for,
  bit [L3_INDEX_BITS-1:0] index;       //  - Address breakdown
  bit [L3_OFFSET_BITS-1:0] offset;     //  - LRU updates
  
  int mshr_id; // If miss -> we allocate an MSHR entry.

  expected_hit = 0; // Intially take it as zero...assumed miss!
  
  // ------------------------------------------------------------------------------
  // 1. Decode AXI cache policy
  // ------------------------------------------------------------------------------
  // Purpose: Converts the raw 4-bit AxCACHE signal into readable memory attributes
  // (Device, Cacheable, Write-Back/Through, Allocation).
  policy = axi_decode_cache_policy(m_tx.arcache, 1);
  
  // ------------------------------------------------------------------------------
  // 2. Device / Non-cacheable
  // ------------------------------------------------------------------------------
  // Purpose: Bypasses L3 for Device or Non-cacheable traffic per AXI rules.
  // Prevents state side-effects: No MSHR allocation, LRU updates, or counter increments.
  if(policy.device || !policy.cacheable) begin
    `uvm_info("L3_READ_BYPASS",
      $sformatf("M[%0d] Addr=0x%0h Non-cacheable",
                master_id, m_tx.araddr),
      UVM_MEDIUM)
    return;
  end
  
  // ------------------------------------------------------------------------------
  // 3. Decode address
  // ------------------------------------------------------------------------------
  // Purpose: Splits raw address into Tag, Index, and Offset fields.
  // Necessary for set-associative indexing and byte-level offset tracking.
  l3_cache_decode_address(m_tx.araddr, tag, index, offset);

  // ------------------------------------------------------------------------------
  // 4. Lookup
  // ------------------------------------------------------------------------------
  // Purpose: Validates Tag match against active lines (checks Valid, Filling, and Lock states).
  // Determines if the transaction is a HIT or requires a MISS/Bypass flow.
  if(l3_cache_lookup(m_tx.araddr, policy, hit_way, state)) begin : L3_READ_HIT
    // ================= READ HIT =================
    expected_hit = 1;

    l3_read_hits_per_master[master_id]++;
    l3_total_read_hits++;

    // Update LRU only on hit
    l3_update_lru(index, hit_way);

    `uvm_info("L3_READ_HIT",
      $sformatf("M[%0d] HIT Set=%0d Way=%0d Addr=0x%0h State=%s",
                master_id, index, hit_way,
                m_tx.araddr, state.name()),
      UVM_MEDIUM)
    
  end : L3_READ_HIT
  else begin : L3_READ_MISS
    // ================= READ MISS =================
    expected_hit = 0;

    l3_read_misses_per_master[master_id]++;
    l3_total_read_misses++;

    mshr_id = scb_allocate_mshr(
                m_tx.araddr,   // addr
                master_id,     // master
                m_tx.arid,     // txn_id
                0              // is_write=0 for reads
              );

    if(mshr_id == -1) begin
      `uvm_warning("L3_READ_MISS_STALL",
        $sformatf("MSHR full for Addr=0x%0h",
                  m_tx.araddr))
      return;
    end

    `uvm_info("L3_READ_MISS",
      $sformatf("M[%0d] MISS Set=%0d Addr=0x%0h → MSHR[%0d]",
                master_id, index,
                m_tx.araddr, mshr_id),
      UVM_MEDIUM)
  end : L3_READ_MISS
  
endfunction : l3_handle_read_request

//==========================================================================
//  L3 HANDLE WRITE REQUEST
//==========================================================================
    
function void axi4_scoreboard::l3_handle_write_request(
  input int master_id,
  input axi4_master_tx m_tx,
  input int slave_idx
);

  axi_cache_policy_s policy;
  int hit_way;
  l3_state_e state;

  bit [L3_TAG_BITS-1:0]   tag;
  bit [L3_INDEX_BITS-1:0] index;
  bit [L3_OFFSET_BITS-1:0] offset;

  policy = axi_decode_cache_policy(m_tx.awcache, 0);

  // bypass
  if(policy.device || !policy.cacheable)
    return;

  l3_cache_decode_address(m_tx.awaddr, tag, index, offset);

  //--------------------------------------------
  // WRITE HIT
  //--------------------------------------------
  if(l3_cache_lookup(m_tx.awaddr, policy, hit_way, state)) begin

    scb_write_locked       = 1;
    scb_write_owner        = master_id;
    scb_write_owner_set    = index;
    scb_write_owner_way    = hit_way;
    scb_write_owner_is_hit = 1;

    l3_write_hits_per_master[master_id]++;
    l3_total_write_hits++;

    `uvm_info("L3_WRITE_HIT",
      $sformatf("M[%0d] HIT Set=%0d Way=%0d Addr=0x%0h",
        master_id, index, hit_way, m_tx.awaddr),
      UVM_MEDIUM)

  end
  //--------------------------------------------
  // WRITE MISS
  //--------------------------------------------
  else begin
    int mshr_id;

    mshr_id = scb_allocate_mshr(
      m_tx.awaddr,
      master_id,
      m_tx.awid,
      1
    );

    if(mshr_id == -1) begin
      `uvm_error("L3_WRITE_MISS", "MSHR allocation failed")
      return;
    end

    l3_write_misses_per_master[master_id]++;
    l3_total_write_misses++;

    `uvm_info("L3_WRITE_MISS",
      $sformatf("M[%0d] MISS Addr=0x%0h → MSHR[%0d]",
        master_id, m_tx.awaddr, mshr_id),
      UVM_MEDIUM)
  end

endfunction
  
//==========================================================================
//  L3 HANDLE WRITE DATA
//==========================================================================
    
function void axi4_scoreboard::l3_handle_write_data(
  input int master_id,
  input axi4_master_tx m_tx
);
   $display("SCB_AWID=%0d",m_tx.awid);
  //--------------------------------------------
  // 1. WRITE MISS → BUFFER IN MSHR
  //--------------------------------------------
  for(int i = 0; i < MAX_MSHR; i++) begin
    if(scb_mshr[i].valid &&
       scb_mshr[i].is_write &&
       scb_mshr[i].master == master_id &&
       scb_mshr[i].txn_id == m_tx.awid &&
       !scb_mshr[i].done) begin

      int b = scb_mshr[i].wbeat_count;

      foreach(m_tx.wdata[beat]) begin
        if(b < WORDS_PER_LINE) begin
          scb_mshr[i].wdata_buf[b] = m_tx.wdata[beat];
          scb_mshr[i].wstrb_buf[b] = m_tx.wstrb[beat];
          $display("[SCB_WBUF_COLLECT] time=%0t mshr=%0d master=%0d widx=%0d wdata=0x%0h wstrb=0x%0h wbeat_count=%0d wlast=%0b",$time, i, master_id,scb_mshr[i].wbeat_count - 1,m_tx.wdata[0], m_tx.wstrb[0],scb_mshr[i].wbeat_count,m_tx.wlast);
          b++;
        end
      end

      scb_mshr[i].wbeat_count = b;
      if(m_tx.wlast) begin
        scb_mshr[i].wlast_seen = 1;
        // Set done only now that both sides are complete
        if(scb_mshr[i].rlast_seen) begin
           scb_mshr[i].done = 1;
           $display("[SCB_WRITE_DONE] time=%0t mshr=%0d master=%0d — both rlast_seen and wlast_seen true, done=1 set",$time, i, master_id);
        end
      end
      
      return;
    end
  end

  //--------------------------------------------
  // 2. WRITE HIT → MERGE INTO CACHE
  //--------------------------------------------
  if(scb_write_locked && scb_write_owner == master_id) begin

    int set = scb_write_owner_set;
    int way = scb_write_owner_way;

    longint temp_addr = m_tx.awaddr;

    foreach(m_tx.wdata[beat]) begin
      for(int b = 0; b < (DATA_WIDTH/8); b++) begin

        int line_offset = temp_addr % L3_CACHE_LINE_SIZE_BYTES;

        if(m_tx.wstrb[beat][b]) begin
          l3_cache[set][way].data[line_offset] =
            m_tx.wdata[beat][8*b +: 8];
        end

        temp_addr++;
      end
    end

    l3_set_line_state(set, way, L3_DIRTY);
    l3_update_lru(set, way);

    `uvm_info("L3_WDATA_HIT",
      $sformatf("Merged WDATA into cache Set=%0d Way=%0d", set, way),
      UVM_HIGH)

    //--------------------------------------------
    // RELEASE LOCK
    //--------------------------------------------
    scb_write_locked       = 0;
    scb_write_owner        = -1;
    scb_write_owner_set    = -1;
    scb_write_owner_way    = -1;
    scb_write_owner_is_hit = 0;
  end

endfunction
    
    

    
    

//=============================================================================
// Function: connect_phase
//=============================================================================
function void axi4_scoreboard::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase

//=============================================================================
// Function: get_slave_index
//=============================================================================
function int axi4_scoreboard::get_slave_index(logic[ADDRESS_WIDTH-1:0] addr);
  for(int i = 0; i < NO_OF_SLAVES; i++) begin
    if(addr >= SLAVE_START_ADDR[i] && addr <= SLAVE_END_ADDR[i]) begin
      return i;
    end
  end
  return -1;
endfunction : get_slave_index

//=============================================================================
// Function: check_write_rr_arbitration
//=============================================================================
function void axi4_scoreboard::check_write_rr_arbitration(int slave_id, int granted_master);
  int expected_master;
  int search_count;
  bit found_pending;
  
  rr_write_grants++;
  
  search_count = 0;
  found_pending = 0;
  expected_master = rr_write_next_master[slave_id];
  
  while(search_count < NO_OF_MASTERS) begin
    if(rr_write_pending_cnt[slave_id][expected_master] > 0) begin
      found_pending = 1;
      break;
    end
    expected_master = (expected_master + 1) % NO_OF_MASTERS;
    search_count++;
  end
  
  if(!found_pending) begin
    `uvm_info("RR_WRITE_NO_CONTENTION", 
              $sformatf("Slave[%0d]: No contention, granted to Master[%0d]", slave_id, granted_master), 
              UVM_HIGH)
    rr_write_last_granted[slave_id] = granted_master;
    return;
  end
  
  if(granted_master != expected_master) begin
    `uvm_error("RR_WRITE_VIOLATION",
              $sformatf("Slave[%0d] Write RR Arbitration Violation: Expected M%0d, Granted M%0d",
                       slave_id, expected_master, granted_master))
    rr_write_violations++;
  end
  
  rr_write_next_master[slave_id] = (granted_master + 1) % NO_OF_MASTERS;
  rr_write_last_granted[slave_id] = granted_master;
  
  if(rr_write_pending_cnt[slave_id][granted_master] > 0) begin
    rr_write_pending_cnt[slave_id][granted_master]--;
  end
  
endfunction : check_write_rr_arbitration

//=============================================================================
// Function: check_read_rr_arbitration
//=============================================================================
function void axi4_scoreboard::check_read_rr_arbitration(int slave_id, int granted_master);
  int expected_master;
  int search_count;
  bit found_pending;
  
  rr_read_grants++;
  
  search_count = 0;
  found_pending = 0;
  expected_master = rr_read_next_master[slave_id];
  
  while(search_count < NO_OF_MASTERS) begin
    if(rr_read_pending_cnt[slave_id][expected_master] > 0) begin
      found_pending = 1;
      break;
    end
    expected_master = (expected_master + 1) % NO_OF_MASTERS;
    search_count++;
  end
  
  if(!found_pending) begin
    `uvm_info("RR_READ_NO_CONTENTION", 
              $sformatf("Slave[%0d]: No contention, granted to Master[%0d]", slave_id, granted_master), 
              UVM_HIGH)
    rr_read_last_granted[slave_id] = granted_master;
    return;
  end
  
  if(granted_master != expected_master) begin
    `uvm_error("RR_READ_VIOLATION",
              $sformatf("Slave[%0d] Read RR Arbitration Violation: Expected M%0d, Granted M%0d",
                       slave_id, expected_master, granted_master))
    rr_read_violations++;
  end
  
  rr_read_next_master[slave_id] = (granted_master + 1) % NO_OF_MASTERS;
  rr_read_last_granted[slave_id] = granted_master;
  
  if(rr_read_pending_cnt[slave_id][granted_master] > 0) begin
    rr_read_pending_cnt[slave_id][granted_master]--;
  end
  
endfunction : check_read_rr_arbitration

//=============================================================================
// Function: ref_model_write
// FIXED: Pass slave_idx to l3_handle_write_request
//=============================================================================
function void axi4_scoreboard::ref_model_write(axi4_master_tx m_tx, int slave_idx, int master_idx);
  int bytes_per_beat;
  longint temp_addr;
  int align_amount;
  longint wrap_start_addr;
  longint wrap_end_addr;
  longint wrap_boundary;
  
  bytes_per_beat = 1 << m_tx.awsize;
  temp_addr = m_tx.awaddr;
  
  wrap_boundary = bytes_per_beat * (m_tx.awlen + 1);
  wrap_start_addr = (temp_addr / wrap_boundary) * wrap_boundary;
  wrap_end_addr = wrap_start_addr + wrap_boundary;
  
  align_amount = temp_addr % bytes_per_beat;
  
  foreach(m_tx.wdata[beat]) begin
    int local_align = (beat == 0) ? align_amount : 0;
    
    case(m_tx.awburst)
      2'b00: begin
        for(int byte_idx = local_align; byte_idx < bytes_per_beat; byte_idx++) begin
          longint byte_addr = m_tx.awaddr + byte_idx;
          int lane = byte_addr % (DATA_WIDTH/8);
          
          if(m_tx.wstrb[beat][lane]) begin
            referenceData[slave_idx][byte_addr] = m_tx.wdata[beat][8*lane+7 -: 8];
          end
        end
      end
      
      2'b01: begin
        for(int byte_idx = local_align; byte_idx < bytes_per_beat; byte_idx++) begin
          int lane = temp_addr % (DATA_WIDTH/8);
          
          if(m_tx.wstrb[beat][lane]) begin
            referenceData[slave_idx][temp_addr] = m_tx.wdata[beat][8*lane+7 -: 8];
          end
          temp_addr++;
        end
      end
      
      2'b10: begin
        for(int byte_idx = local_align; byte_idx < bytes_per_beat; byte_idx++) begin
          int lane = temp_addr % (DATA_WIDTH/8);
          
          if(m_tx.wstrb[beat][lane]) begin
            referenceData[slave_idx][temp_addr] = m_tx.wdata[beat][8*lane+7 -: 8];
          end
          temp_addr++;
          if(temp_addr >= wrap_end_addr) begin
            temp_addr = wrap_start_addr;
          end
        end
      end
    endcase
  end
  
  // L3 cache handles its own memory updates based on policy
  l3_handle_write_request(master_idx, m_tx, slave_idx);
  
endfunction : ref_model_write

//=============================================================================
// Function: ref_model_read
//=============================================================================
function void axi4_scoreboard::ref_model_read(axi4_master_tx m_tx, int slave_idx);
  int bytes_per_beat;
  longint temp_addr;
  int align_amount;
  longint wrap_start_addr;
  longint wrap_end_addr;
  longint wrap_boundary;
  
  bytes_per_beat = 1 << m_tx.arsize;
  temp_addr = m_tx.araddr;
  
  wrap_boundary = bytes_per_beat * (m_tx.arlen + 1);
  wrap_start_addr = (temp_addr / wrap_boundary) * wrap_boundary;
  wrap_end_addr = wrap_start_addr + wrap_boundary;
  
  align_amount = temp_addr % bytes_per_beat;
  
  m_tx.rdata = new[m_tx.arlen + 1];
  
  foreach(m_tx.rdata[beat]) begin
    int local_align = (beat == 0) ? align_amount : 0;
    m_tx.rdata[beat] = '0;
    
    case(m_tx.arburst)
      2'b00: begin
        for(int byte_idx = local_align; byte_idx < bytes_per_beat; byte_idx++) begin
          longint byte_addr = m_tx.araddr + byte_idx;
          int lane = byte_addr % (DATA_WIDTH/8);
          
          if(referenceData[slave_idx].exists(byte_addr)) begin
            m_tx.rdata[beat][8*lane+7 -: 8] = referenceData[slave_idx][byte_addr];
          end else begin
            m_tx.rdata[beat][8*lane+7 -: 8] = 8'h00;
            nonExistantMemRead++;
          end
        end
      end
      
      2'b01: begin
        for(int byte_idx = local_align; byte_idx < bytes_per_beat; byte_idx++) begin
          int lane = temp_addr % (DATA_WIDTH/8);
          
          if(referenceData[slave_idx].exists(temp_addr)) begin
            m_tx.rdata[beat][8*lane+7 -: 8] = referenceData[slave_idx][temp_addr];
          end else begin
            m_tx.rdata[beat][8*lane+7 -: 8] = 8'h00;
            nonExistantMemRead++;
          end
          temp_addr++;
        end
      end
      
      2'b10: begin
        for(int byte_idx = local_align; byte_idx < bytes_per_beat; byte_idx++) begin
          int lane = temp_addr % (DATA_WIDTH/8);
          
          if(referenceData[slave_idx].exists(temp_addr)) begin
            m_tx.rdata[beat][8*lane+7 -: 8] = referenceData[slave_idx][temp_addr];
          end else begin
            m_tx.rdata[beat][8*lane+7 -: 8] = 8'h00;
            nonExistantMemRead++;
          end
          temp_addr++;
          if(temp_addr >= wrap_end_addr) begin
            temp_addr = wrap_start_addr;
          end
        end
      end
    endcase
  end
  
endfunction : ref_model_read

//=============================================================================
// TASK: run_phase
// Combined L3 cache + arbitration + in-order transaction handling
// FIXED: Call l3_complete_fill when read data completes for cache misses
//=============================================================================
task axi4_scoreboard::run_phase(uvm_phase phase);
  super.run_phase(phase);
  
//===========================================================================
// WRITE ADDRESS PATH - Master Side
//===========================================================================

foreach(axi4_master_write_address_analysis_fifo[i]) begin
  automatic int m_idx = i;
  fork
    forever begin
      axi4_master_tx              m_write_addr_tx;
      int                         s_idx;
      pending_write_transaction_t pending_tx;

      //=========================================================
      // 1. RECEIVE AW FROM MASTER
      //=========================================================
      axi4_master_write_address_analysis_fifo[m_idx].get(m_write_addr_tx);

      axi4_master_tx_awaddr_count[m_idx]++;
      total_master_tx_count++;

      `uvm_info("MSTR_WR_ADDR",
        $sformatf("M[%0d] AWID=0x%0h AWADDR=0x%0h AWLEN=%0d AWCACHE=0x%0h",
          m_idx,
          m_write_addr_tx.awid,
          m_write_addr_tx.awaddr,
          m_write_addr_tx.awlen,
          m_write_addr_tx.awcache),
        UVM_MEDIUM)

      //=========================================================
      // 2. DECODE TARGET SLAVE
      //=========================================================
      s_idx = get_slave_index(m_write_addr_tx.awaddr);

      if(s_idx == -1) begin
        `uvm_error("ADDR_DECODE",
          $sformatf("M[%0d] AWADDR=0x%0h doesn't map to any slave",
            m_idx, m_write_addr_tx.awaddr))
        continue;
      end

      //=========================================================
      // 3. L3 CACHE LOOKUP — SINGLE CALL
      //    HIT  → scb_write_locked=1, scb_write_owner=m_idx
      //    MISS → MSHR allocated (is_write=1)
      //    ref_model_write must NOT call this again.
      //=========================================================
      l3_handle_write_request(m_idx, m_write_addr_tx, s_idx);

      //=========================================================
      // 4. ARBITRATION COUNTER
      //=========================================================
      rr_write_pending_cnt[s_idx][m_idx]++;

      //=========================================================
      // 5. PUSH PENDING TRANSACTION
      //    Keyed by LOCAL awid — master monitor uses local IDs.
      //    address_granted=1 immediately — master AW is the grant.
      //=========================================================
      $cast(pending_tx.tx, m_write_addr_tx.clone());

      pending_tx.master_id           = m_idx;
      pending_tx.slave_id            = s_idx;
      pending_tx.address_granted     = 1;
      pending_tx.write_data_complete = 0;
      pending_tx.beats_received      = 0;

      pending_write_txns[s_idx][m_idx][m_write_addr_tx.awid].push_back(pending_tx);

      //=========================================================
      // 6. PUSH TO PER-MASTER ORDERED AW QUEUE
      //    Records (slave, awid) in arrival order.
      //    WDATA path pops front to find the current transaction
      //    without iterating all slaves/IDs.
      //=========================================================
      master_aw_queue[m_idx].push_back({s_idx, int'(m_write_addr_tx.awid)});

      `uvm_info("WR_PENDING", $sformatf("M[%0d]->S[%0d] AWID=0x%0h pushed pending depth=%0d aw_queue depth=%0d", m_idx, s_idx, m_write_addr_tx.awid, pending_write_txns[s_idx][m_idx][m_write_addr_tx.awid].size(), master_aw_queue[m_idx].size()), UVM_HIGH)
    end // forever
  join_none
end


//===========================================================================
// WRITE ADDRESS PATH - Slave Side
//
// Slave AW = writeback evictions ONLY.
// No master write matching here.
//===========================================================================

foreach(axi4_slave_write_address_analysis_fifo[i]) begin
  automatic int s_idx = i;
  fork
    forever begin
      axi4_slave_tx s_write_addr_tx;
      bit           found;

      //=================================================================
      // 1. RECEIVE AW FROM SLAVE
      //=================================================================
      axi4_slave_write_address_analysis_fifo[s_idx].get(s_write_addr_tx);
      axi4_slave_tx_awaddr_count[s_idx]++;

      `uvm_info("SLV_WR_ADDR",$sformatf("S[%0d] AWID=0x%0h AWADDR=0x%0h AWLEN=%0d",s_idx,s_write_addr_tx.awid,s_write_addr_tx.awaddr,s_write_addr_tx.awlen),UVM_MEDIUM)

      found = 0;

      //=================================================================
      // 2. FIND MATCHING WRITEBACK MSHR
      //    valid && needs_writeback && !wb_done && slave==s_idx
      //=================================================================
      for(int wb_idx = 0; wb_idx < MAX_MSHR; wb_idx++) begin

        if(scb_mshr[wb_idx].valid          &&
           scb_mshr[wb_idx].needs_writeback &&
           !scb_mshr[wb_idx].wb_done        &&
           scb_mshr[wb_idx].slave == s_idx) begin

          //=============================================================
          // 3. RECONSTRUCT EXPECTED WB ADDRESS
          //    RTL: s_awaddr = {tag_array[idx][way], idx, {OFFSET{0}}}
          //    l3_writeback_to_memory() preserved tag even after
          //    moving state to L3_CLEAN.
          //=============================================================
          bit [ADDRESS_WIDTH-1:0] expected_wb_addr;
          expected_wb_addr = {
            l3_cache[scb_mshr[wb_idx].index][scb_mshr[wb_idx].way].tag,
            scb_mshr[wb_idx].index[L3_INDEX_BITS-1:0],
            {L3_OFFSET_BITS{1'b0}}
          };

          if(s_write_addr_tx.awaddr == expected_wb_addr) begin

            //===========================================================
            // 4. VERIFY AWLEN == WORDS_PER_LINE - 1
            //===========================================================
            if(s_write_addr_tx.awlen != (WORDS_PER_LINE - 1)) begin
              `uvm_error("WB_AWLEN_MISMATCH",$sformatf("S[%0d] MSHR[%0d] WB AWLEN=%0d expected=%0d",s_idx, wb_idx,s_write_addr_tx.awlen,WORDS_PER_LINE - 1))
            end

            `uvm_info("WB_ADDR_GRANTED",$sformatf("S[%0d] MSHR[%0d] AWID=0x%0h AWADDR=0x%0h WRITEBACK GRANTED",s_idx, wb_idx,s_write_addr_tx.awid,s_write_addr_tx.awaddr),UVM_MEDIUM)

            //===========================================================
            // 5. UNBLOCK SLAVE WDATA PATH
            //===========================================================
            ->slave_write_addr_granted[s_idx];

            found = 1;
            break;
          end
        end
      end

      if(!found) begin
        `uvm_error("WR_ADDR_NO_MATCH",$sformatf("S[%0d] AWID=0x%0h AWADDR=0x%0h:no active writeback MSHR matches", s_idx,s_write_addr_tx.awid,s_write_addr_tx.awaddr))
      end

    end // forever
  join_none
end


//===========================================================================
// WRITE DATA PATH - Master Side
//===========================================================================

foreach(axi4_master_write_data_analysis_fifo[i]) begin
  automatic int m_idx = i;
  fork
    forever begin
      axi4_master_tx              m_write_data_tx;
      pending_write_transaction_t pending_tx;
      int                         s_idx;
      int                         awid_int;
      bit [ID_WIDTH-1:0]          awid;

      //=================================================================
      // 1. RECEIVE W BEAT FROM MASTER
      //=================================================================
      axi4_master_write_data_analysis_fifo[m_idx].get(m_write_data_tx);
      axi4_master_tx_wdata_count[m_idx]++;

      `uvm_info("MSTR_WR_DATA",$sformatf("M[%0d] WDATA[0]=0x%0h WSTRB=0x%0h WLAST=%0b", m_idx,m_write_data_tx.wdata[0],m_write_data_tx.wstrb[0],m_write_data_tx.wlast),UVM_HIGH)

      //=================================================================
      // 2. GET CURRENT PENDING TRANSACTION FROM AW QUEUE
      //    master_aw_queue front always points to the oldest
      //    unfinished AW for this master — no searching needed.
      //=================================================================
      if(master_aw_queue[m_idx].size() == 0) begin
       `uvm_error("MSTR_WR_DATA_NO_AW", $sformatf("M[%0d] W beat received but master_aw_queue is empty. WDATA=0x%0h WLAST=%0b", m_idx, m_write_data_tx.wdata[0], m_write_data_tx.wlast))
        continue;
      end

      s_idx    = master_aw_queue[m_idx][0][0]; // slave index
      awid_int = master_aw_queue[m_idx][0][1]; // local awid
      awid     = bit'(awid_int);

      if(pending_write_txns[s_idx][m_idx][awid].size() == 0) begin
        `uvm_error("MSTR_WR_DATA_NO_PENDING",$sformatf("M[%0d] S[%0d] AWID=0x%0h aw_queue points to empty pending_write_txns entry",m_idx, s_idx, awid))
        continue;
      end

      pending_tx = pending_write_txns[s_idx][m_idx][awid][0];

      //=================================================================
      // 3. COUNT BEATS
      //=================================================================
      pending_tx.beats_received++;

      `uvm_info("MSTR_WR_DATA_BEAT",$sformatf("M[%0d] S[%0d] AWID=0x%0h beat=%0d/%0d WDATA=0x%0h WSTRB=0x%0h",m_idx, s_idx, awid,pending_tx.beats_received,pending_tx.tx.awlen + 1,m_write_data_tx.wdata[0],m_write_data_tx.wstrb[0]),UVM_HIGH)

      //=================================================================
      // 4. CHECK WLAST TIMING
      //=================================================================
      if(m_write_data_tx.wlast) begin
        if(pending_tx.beats_received != (pending_tx.tx.awlen + 1)) begin
          `uvm_error("MSTR_WLAST_EARLY", $sformatf("M[%0d] S[%0d] AWID=0x%0h WLAST at beat=%0d but AWLEN+1=%0d", m_idx, s_idx, awid, pending_tx.beats_received, pending_tx.tx.awlen + 1))
        end
      end else begin
        if(pending_tx.beats_received > pending_tx.tx.awlen) begin
          `uvm_error("MSTR_WLAST_LATE", $sformatf("M[%0d] S[%0d] AWID=0x%0h beat=%0d exceeded AWLEN=%0d no WLAST", m_idx, s_idx, awid, pending_tx.beats_received, pending_tx.tx.awlen))
        end
      end

      l3_handle_write_data(m_idx, m_write_data_tx);

      //=================================================================
      // 6. ON WLAST: MARK COMPLETE, POP AW QUEUE
      //=================================================================
      if(m_write_data_tx.wlast) begin

        if(pending_tx.beats_received == (pending_tx.tx.awlen + 1))
          byte_data_cmp_verified_wlast_count++;

        pending_tx.write_data_complete = 1;

        `uvm_info("MSTR_WR_DATA_COMPLETE",$sformatf("M[%0d] S[%0d] AWID=0x%0h write data COMPLETE beats=%0d",m_idx, s_idx, awid,pending_tx.beats_received),UVM_MEDIUM)

        // Pop front of AW queue — done with this transaction's data
        void'(master_aw_queue[m_idx].pop_front());
      end

      // Write updated struct back to queue
      pending_write_txns[s_idx][m_idx][awid][0] = pending_tx;

    end // forever
  join_none
end


//===========================================================================
// WRITE DATA PATH - Slave Side (Writeback Only)
//===========================================================================

foreach(axi4_slave_write_data_analysis_fifo[i]) begin
  automatic int s_idx = i;
  fork
    forever begin
      axi4_slave_tx s_write_data_tx;
      bit           found;
      int           wb_mshr_idx;

      //=================================================================
      // 1. WAIT FOR WRITEBACK ADDRESS PHASE TO COMPLETE
      //    slave_write_addr_granted is triggered by slave AW path
      //    only after a valid writeback MSHR is matched.
      //=================================================================
      @(slave_write_addr_granted[s_idx]);

      //=================================================================
      // 2. RECEIVE WRITEBACK DATA BEAT
      //=================================================================
      axi4_slave_write_data_analysis_fifo[s_idx].get(s_write_data_tx);
      axi4_slave_tx_wdata_count[s_idx]++;

      `uvm_info("SLV_WR_DATA",$sformatf("S[%0d] WDATA=0x%0h WSTRB=0x%0h WLAST=%0b",s_idx,s_write_data_tx.wdata[0],s_write_data_tx.wstrb[0],s_write_data_tx.wlast),UVM_HIGH)

      found       = 0;
      wb_mshr_idx = -1;

      //=================================================================
      // 3. FIND ACTIVE WRITEBACK MSHR FOR THIS SLAVE
      //    At most one active writeback per slave at any time.
      //=================================================================
      for(int wb_idx = 0; wb_idx < MAX_MSHR; wb_idx++) begin
        if(scb_mshr[wb_idx].valid          &&
           scb_mshr[wb_idx].needs_writeback &&
           !scb_mshr[wb_idx].wb_done        &&
           scb_mshr[wb_idx].slave == s_idx) begin
          found       = 1;
          wb_mshr_idx = wb_idx;
          break;
        end
      end

      if(!found) begin
     `uvm_error("SLV_WR_DATA_NO_WB", $sformatf("S[%0d] WB data beat received but no active writeback MSHR found. WDATA=0x%0h WLAST=%0b", s_idx, s_write_data_tx.wdata[0], s_write_data_tx.wlast))
        continue;
      end

      //=================================================================
      // 4. RECONSTRUCT WB BASE ADDRESS AND COMPUTE BEAT OFFSET
      //=================================================================
      begin : WB_DATA_CHECK
        bit [ADDRESS_WIDTH-1:0] wb_base_addr;
        int                  beat_num;
        longint              beat_base;

        wb_base_addr = {
          l3_cache[scb_mshr[wb_mshr_idx].index]
                  [scb_mshr[wb_mshr_idx].way].tag,
          scb_mshr[wb_mshr_idx].index[L3_INDEX_BITS-1:0],
          {L3_OFFSET_BITS{1'b0}}
        };

        beat_num  = wb_beat_tracker[s_idx];
        beat_base = longint'(wb_base_addr) + beat_num * AXI_DATA_BYTES;

        `uvm_info("WB_DATA_BEAT",
          $sformatf("S[%0d] MSHR[%0d] beat=%0d beat_base=0x%0h",
            s_idx, wb_mshr_idx, beat_num, beat_base),
          UVM_HIGH)

        //=============================================================
        // 5. BYTE-LANE COMPARISON AGAINST referenceData[]
        //    referenceData[] was populated by l3_writeback_to_memory()
        //    at MSHR allocation time.
        //=============================================================
        for(int lane = 0; lane < AXI_DATA_BYTES; lane++) begin
          if(s_write_data_tx.wstrb[0][lane]) begin
            longint byte_addr     = beat_base + lane;
            byte    expected_byte;
            byte    dut_byte;

            expected_byte = referenceData[s_idx].exists(byte_addr)
                            ? referenceData[s_idx][byte_addr]
                            : 8'h00;

            dut_byte = s_write_data_tx.wdata[0][8*lane +: 8];

            if(expected_byte !== dut_byte) begin
           `uvm_error("WB_DATA_MISMATCH", $sformatf("S[%0d] MSHR[%0d] beat=%0d addr=0x%0h lane=%0d Expected=0x%0h Got=0x%0h", s_idx, wb_mshr_idx, beat_num, byte_addr, lane, expected_byte, dut_byte))
            end
          end
        end

        //=============================================================
        // 6. ADVANCE BEAT COUNTER
        //=============================================================
        wb_beat_tracker[s_idx]++;

        //=============================================================
        // 7. WLAST: VERIFY BEAT COUNT AND RESET TRACKER
        //=============================================================
        if(s_write_data_tx.wlast) begin
          if(wb_beat_tracker[s_idx] != WORDS_PER_LINE) begin
            `uvm_error("WB_WLAST_COUNT", $sformatf("S[%0d] MSHR[%0d] WLAST after %0d beats expected %0d", s_idx, wb_mshr_idx, wb_beat_tracker[s_idx], WORDS_PER_LINE))
          end else begin
           `uvm_info("WB_DATA_COMPLETE", $sformatf("S[%0d] MSHR[%0d] WB data COMPLETE beats=%0d base=0x%0h", s_idx, wb_mshr_idx, wb_beat_tracker[s_idx], wb_base_addr), UVM_MEDIUM)
          end
          // Reset for next writeback on this slave
          wb_beat_tracker[s_idx] = 0;
          // wb_done set in BRESP path only — not here
        end

      end : WB_DATA_CHECK

    end // forever
  join_none
end

//===========================================================================
// WRITE RESPONSE PATH - Master Side
//===========================================================================



foreach(axi4_master_write_response_analysis_fifo[i]) begin
  automatic int m_idx = i;
  fork
    forever begin
      axi4_master_tx              m_write_resp_tx;
      pending_write_transaction_t pending_tx;
      int                         mshr_idx;
      int                         s_idx;



      axi4_master_write_response_analysis_fifo[m_idx].get(m_write_resp_tx);
      axi4_master_tx_bresp_count[m_idx]++;
      total_master_tx_count++;



      `uvm_info("MSTR_WR_RESP",
        $sformatf("M[%0d] BID=0x%0h BRESP=0x%0h",
                  m_idx, m_write_resp_tx.bid, m_write_resp_tx.bresp),
        UVM_MEDIUM)



      mshr_idx = -1;
      s_idx    = -1;



      //=================================================================
      // 1. Find which slave queue this BID belongs to
      //=================================================================
      begin : FIND_SLAVE
        for(int s = 0; s < NO_OF_SLAVES; s++) begin
          if(pending_write_txns[s][m_idx].exists(m_write_resp_tx.bid)) begin
            if(pending_write_txns[s][m_idx][m_write_resp_tx.bid].size() > 0) begin
              s_idx = s;
              break;
            end
          end
        end
      end : FIND_SLAVE



      if(s_idx == -1) begin
        `uvm_error("MSTR_BRESP_NO_SLAVE",
          $sformatf("M[%0d] BID=0x%0h cannot find pending master transaction",
                    m_idx, m_write_resp_tx.bid))
        continue;
      end



      //=================================================================
      // 2. Pop the pending transaction
      //=================================================================
      pending_tx = pending_write_txns[s_idx][m_idx][m_write_resp_tx.bid].pop_front();


      if(!pending_tx.write_data_complete) begin
        `uvm_error("BRESP_BEFORE_WLAST",
          $sformatf("M[%0d] S[%0d] BID=0x%0h BRESP received before WLAST",
                    m_idx, s_idx, m_write_resp_tx.bid))
      end



      //=================================================================
      // 4. WRITE HIT vs WRITE MISS detection & MSHR Release
      //=================================================================
      mshr_idx = scb_find_existing_mshr(pending_tx.tx.awaddr);



      if(mshr_idx != -1          &&
         scb_mshr[mshr_idx].valid    &&
         scb_mshr[mshr_idx].is_write &&
         scb_mshr[mshr_idx].master == m_idx) begin



        //-------------------------------------------------------------
        // WRITE MISS COMPLETION
        //-------------------------------------------------------------
        if(scb_mshr[mshr_idx].needs_writeback && !scb_mshr[mshr_idx].wb_done) begin
          `uvm_error("MASTER_BRESP_BEFORE_WB_DONE", $sformatf("M[%0d] S[%0d] BID=0x%0h MSHR[%0d]: master BRESP before writeback BRESP completed", m_idx, s_idx, m_write_resp_tx.bid, mshr_idx))
        end

        if(!scb_mshr[mshr_idx].done) begin
          `uvm_error("MASTER_BRESP_BEFORE_REFILL",
            $sformatf("M[%0d] S[%0d] BID=0x%0h MSHR[%0d]: master BRESP before refill complete",
                      m_idx, s_idx, m_write_resp_tx.bid, mshr_idx))
        end

        // Store BRESP code — scb_release_mshr uses it for LRU update
        scb_mshr[mshr_idx].resp_code = m_write_resp_tx.bresp;

        // Release MSHR: applies buffered wdata, sets L3_DIRTY, updates LRU
        scb_release_mshr(mshr_idx, 1 /*resp_accepted*/);

        `uvm_info("WR_MISS_COMPLETE", $sformatf("M[%0d] S[%0d] BID=0x%0h MSHR[%0d] released — write-miss cycle complete BRESP=0x%0h", m_idx, s_idx, m_write_resp_tx.bid, mshr_idx, m_write_resp_tx.bresp), UVM_MEDIUM)


      end else begin
        //-------------------------------------------------------------
        // WRITE HIT COMPLETION
        // No MSHR exists. Data was already merged in Master W channel.
        //-------------------------------------------------------------
        if(m_write_resp_tx.bresp != 2'b00) begin
          `uvm_error("HIT_BRESP_NOT_OKAY",
            $sformatf("M[%0d] S[%0d] BID=0x%0h write-hit BRESP=0x%0h expected OKAY",
                      m_idx, s_idx, m_write_resp_tx.bid, m_write_resp_tx.bresp))
        end
        `uvm_info("WR_HIT_COMPLETE",$sformatf("M[%0d] S[%0d] BID=0x%0h write-hit complete BRESP=0x%0h", m_idx, s_idx, m_write_resp_tx.bid, m_write_resp_tx.bresp), UVM_MEDIUM)
      end
    end // forever
  join_none
end

//==========================================================================
// WRITE RESPONSE PATH - Slave Side
//===========================================================================
foreach(axi4_slave_write_response_analysis_fifo[i]) begin
  automatic int s_idx = i;
  fork
    forever begin
      axi4_slave_tx s_write_resp_tx;
      bit           found;
      axi4_slave_write_response_analysis_fifo[s_idx].get(s_write_resp_tx);
      axi4_slave_tx_bresp_count[s_idx]++;
      total_slave_tx_count++;
      `uvm_info("SLV_WR_RESP", $sformatf("S[%0d] BID=0x%0h BRESP=0x%0h", s_idx, s_write_resp_tx.bid, s_write_resp_tx.bresp), UVM_MEDIUM)
      found = 0;



      //=================================================================
      // WRITEBACK BRESP
      // Match: valid && needs_writeback && !wb_done && slave == s_idx
      //=================================================================
      for(int wi = 0; wi < MAX_MSHR; wi++) begin
        if(scb_mshr[wi].valid          &&
           scb_mshr[wi].needs_writeback &&
           !scb_mshr[wi].wb_done        &&
           scb_mshr[wi].slave == s_idx) begin
          
          if(s_write_resp_tx.bresp == 2'b00) begin
            // OKAY: writeback succeeded
            scb_mshr[wi].wb_done  = 1;
            scb_mshr[wi].wb_error = 0;
            `uvm_info("WB_BRESP_OK", $sformatf("S[%0d] MSHR[%0d] writeback BRESP=OKAY — refill AR unblocked", s_idx, wi),UVM_MEDIUM)
            
          end else begin
            // ERROR: writeback failed -> Restore L3_DIRTY and undo Reference Data
            bit [ADDRESS_WIDTH-1:0] wb_addr;



            scb_mshr[wi].wb_done   = 1;
            scb_mshr[wi].wb_error  = 1;
            scb_mshr[wi].resp_code = s_write_resp_tx.bresp;



            l3_set_line_state(scb_mshr[wi].index, scb_mshr[wi].way, L3_DIRTY);



            wb_addr = {
              l3_cache[scb_mshr[wi].index][scb_mshr[wi].way].tag,
              scb_mshr[wi].index[L3_INDEX_BITS-1:0],
              {L3_OFFSET_BITS{1'b0}}
            };



            for(int b = 0; b < L3_CACHE_LINE_SIZE_BYTES; b++) begin
              if(referenceData[s_idx].exists(wb_addr + b))
                referenceData[s_idx].delete(wb_addr + b);
            end



            l3_writeback_errors++;



            `uvm_error("WB_BRESP_ERROR", $sformatf("S[%0d] MSHR[%0d] writeback BRESP=0x%0h — line restored DIRTY refMem undone", s_idx, wi, s_write_resp_tx.bresp))
          end
          found = 1;
          break; 
        end
      end



      if(!found) begin
        `uvm_error("SLV_BRESP_UNEXPECTED", $sformatf("S[%0d] BID=0x%0h BRESP=0x%0h: received unexpected slave-side BRESP — no active writeback MSHR matches.", s_idx, s_write_resp_tx.bid, s_write_resp_tx.bresp))
      end



    end // forever
  join_none
end
  
  
//===========================================================================
// READ ADDRESS PATH - Master Side
//===========================================================================
foreach(axi4_master_read_address_analysis_fifo[i]) begin
  automatic int m_idx = i;
  fork
    forever begin
      axi4_master_tx             m_read_addr_tx;
      int                        s_idx;
      pending_read_transaction_t pending_tx;
      bit                        expected_l3_hit;

      axi4_master_read_address_analysis_fifo[m_idx].get(m_read_addr_tx);
      axi4_master_tx_araddr_count[m_idx]++;

      `uvm_info("MSTR_RD_ADDR", $sformatf("M[%0d] ARID=0x%0h ARADDR=0x%0h ARLEN=%0d ARSIZE=%0d  ARBURST=%0d ARCACHE=0x%0h", m_idx, m_read_addr_tx.arid, m_read_addr_tx.araddr, m_read_addr_tx.arlen, m_read_addr_tx.arsize,  m_read_addr_tx.arburst, m_read_addr_tx.arcache), UVM_MEDIUM)

      s_idx = get_slave_index(m_read_addr_tx.araddr);

      if(s_idx == -1) begin
        `uvm_error("ADDR_DECODE", $sformatf("M[%0d] ARADDR=0x%0h doesn't map to any slave", m_idx, m_read_addr_tx.araddr))
        continue;
      end

      // L3 lookup — sets expected_l3_hit, allocates MSHR on miss
      l3_handle_read_request(m_idx, m_read_addr_tx, expected_l3_hit);

      // Arbitration tracking
      rr_read_pending_cnt[s_idx][m_idx]++;

      $cast(pending_tx.tx, m_read_addr_tx.clone());

      if(expected_l3_hit) begin

        bit [L3_TAG_BITS-1:0]    tag;
        bit [L3_INDEX_BITS-1:0]  index;
        bit [L3_OFFSET_BITS-1:0] offset;
        int                      hit_way;
        int                      bytes_per_beat;
        longint                  temp_addr;

        l3_cache_decode_address(m_read_addr_tx.araddr, tag, index, offset);

        // Find the way — same logic as comparison task
        hit_way = -1;
        for(int w = 0; w < L3_CACHE_ASSOCIATIVITY; w++) begin
          if(l3_cache[index][w].valid                &&
             l3_cache[index][w].tag   == tag         &&
             l3_cache[index][w].state != L3_INVALID  &&
             l3_cache[index][w].state != L3_FILLING) begin
            hit_way = w;
            break;
          end
        end

        if(hit_way == -1) begin
          `uvm_error("L3_HIT_WAY_MISSING", $sformatf("M[%0d] Expected HIT but way not found at AR time Addr=0x%0h", m_idx, m_read_addr_tx.araddr))
        end else begin

          bytes_per_beat = 1 << m_read_addr_tx.arsize;
          temp_addr      = m_read_addr_tx.araddr;

          pending_tx.tx.rdata = new[m_read_addr_tx.arlen + 1];

          foreach(pending_tx.tx.rdata[beat]) begin
            pending_tx.tx.rdata[beat] = '0;
            for(int byte_idx = 0; byte_idx < bytes_per_beat; byte_idx++) begin
              int line_offset = int'(temp_addr) % L3_CACHE_LINE_SIZE_BYTES;
              int lane        = int'(temp_addr) % (DATA_WIDTH/8);
              // data[] is flat byte array — index directly by line_offset
              pending_tx.tx.rdata[beat][8*lane +: 8] =
                l3_cache[index][hit_way].data[line_offset];
              temp_addr++;
            end
          end
        end

      end else begin
        // MISS: expected data from reference memory
        ref_model_read(pending_tx.tx, s_idx);
      end

      pending_tx.master_id         = m_idx;
      pending_tx.slave_id          = s_idx;
      pending_tx.expected_l3_hit   = expected_l3_hit;
      pending_tx.addr_request_time = $time;
      pending_tx.prediction_made   = 1;
      pending_tx.line_addr         = get_line_base_addr(m_read_addr_tx.araddr);

      if(expected_l3_hit) begin
        pending_tx.address_granted = 1;
      end else begin
        pending_tx.address_granted = 0;
      end

      pending_read_txns[s_idx][m_read_addr_tx.arid].push_back(pending_tx);

      // For hits: trigger grant event here since slave AR path is bypassed
      if(expected_l3_hit) begin
        ->slave_read_addr_granted[s_idx];
        `uvm_info("RD_HIT_GRANTED", $sformatf("M[%0d] S[%0d] ARID=0x%0h HIT — address_granted set immediately, no slave AR expected", m_idx, s_idx, m_read_addr_tx.arid), UVM_MEDIUM)
      end

      `uvm_info("RD_PENDING", $sformatf("M[%0d]->S[%0d] ARID=0x%0h queued (depth=%0d) L3_HIT=%0b address_granted=%0b", m_idx, s_idx, m_read_addr_tx.arid, pending_read_txns[s_idx][m_read_addr_tx.arid].size(), expected_l3_hit, pending_tx.address_granted), UVM_HIGH)

    end
  join_none
end
  
  //===========================================================================
  // READ ADDRESS PATH - Slave Side
  // Monitor slave read address acceptance and check arbitration
  //===========================================================================
  foreach(axi4_slave_read_address_analysis_fifo[i]) begin
  automatic int s_idx = i;
  fork
    forever begin
      axi4_slave_tx s_read_addr_tx;
      pending_read_transaction_t pending_tx;
      int master_id;
      bit found;
      bit mshr_found;      // ADD: track MSHR binding result

      axi4_slave_read_address_analysis_fifo[s_idx].get(s_read_addr_tx);
      axi4_slave_tx_araddr_count[s_idx]++;

      `uvm_info("SLV_RD_ADDR",
               $sformatf("S[%0d] ARID=0x%0h ARADDR=0x%0h ARLEN=%0d",
                        s_idx, s_read_addr_tx.arid,
                        s_read_addr_tx.araddr, s_read_addr_tx.arlen),
               UVM_MEDIUM)

      found = 0;
      if(pending_read_txns[s_idx].exists(s_read_addr_tx.arid)) begin
        if(pending_read_txns[s_idx][s_read_addr_tx.arid].size() > 0) begin
          pending_tx = pending_read_txns[s_idx][s_read_addr_tx.arid][0];
          master_id  = pending_tx.master_id;
          found      = 1;

          check_read_rr_arbitration(s_idx, master_id);
          axi4_read_address_comparison(pending_tx.tx, s_read_addr_tx,
                                       master_id, s_idx);

          pending_tx.address_granted = 1;
          pending_read_txns[s_idx][s_read_addr_tx.arid][0] = pending_tx;
          ->slave_read_addr_granted[s_idx];

          `uvm_info("RD_ADDR_GRANTED",
                   $sformatf("S[%0d] M[%0d] ARID=0x%0h address granted",
                            s_idx, master_id, s_read_addr_tx.arid),
                   UVM_HIGH)
        end
      end

      if(!found) begin
       `uvm_error("RD_ADDR_NO_MATCH", $sformatf("S[%0d] received ARID=0x%0h but no pending transaction", s_idx, s_read_addr_tx.arid))
      end

      mshr_found = 0;

      // Guard: slave R-channel must not already be active
      if(active_r_valid[s_idx]) begin
     `uvm_error("AR_SLAVE_BUSY", $sformatf("S[%0d] received new AR but active_r_valid already set - DUT issued two ARs on same slave channel", s_idx))
      end else begin

        for(int m = 0; m < MAX_MSHR; m++) begin
          if(scb_mshr[m].valid                                          &&
             !scb_mshr[m].done                                         &&
             !scb_mshr[m].ar_sent                                      &&
             scb_mshr[m].slave   == s_idx                              &&
             scb_mshr[m].wb_done                                       &&
             scb_mshr[m].line_addr == get_line_base_addr(
                                        s_read_addr_tx.araddr)) begin

            // Bind this slave R-channel to this MSHR
            active_r_valid[s_idx]   = 1;
            active_r_mshr[s_idx]    = m;
            scb_mshr[m].ar_sent     = 1;
            mshr_found              = 1;

            `uvm_info("MSHR_AR_BOUND",
              $sformatf("S[%0d] AR bound to MSHR[%0d] line=0x%0h IsWrite=%0b",
                        s_idx, m, scb_mshr[m].line_addr,
                        scb_mshr[m].is_write),
              UVM_MEDIUM)
            break;
          end
        end

        // ── Validate: every slave AR must map to an MSHR ─────────────────
        // If no MSHR found, the DUT issued an AR that the scoreboard has
        // no record of — either a spurious fetch or an MSHR allocation was
        // missed in the master address path.
        if(!mshr_found) begin
        `uvm_error("AR_NO_MSHR", $sformatf("S[%0d] AR addr=0x%0h ARID=0x%0h has no matching MSHR - spurious refill or missed miss allocation", s_idx, s_read_addr_tx.araddr, s_read_addr_tx.arid))
        end

      end // active_r_valid guard

    end // forever
  join_none
end
  
  
 //===========================================================================
 // READ DATA PATH - Master Side     
 //===========================================================================
  foreach(axi4_master_read_data_analysis_fifo[i]) begin
  automatic int m_idx = i;
  fork
    forever begin
      axi4_master_tx             m_read_data_tx;
      pending_read_transaction_t pending_tx;
      int                        s_idx;
      bit                        found;

      axi4_master_read_data_analysis_fifo[m_idx].get(m_read_data_tx);
      axi4_master_tx_rdata_count[m_idx]++;
      axi4_master_tx_rresp_count[m_idx]++;

      `uvm_info("MSTR_RD_DATA",
        $sformatf("M[%0d] RID=0x%0h RDATA[0]=0x%0h RLAST=%0b RRESP=%0s",
                  m_idx, m_read_data_tx.arid, m_read_data_tx.rdata[0],
                  m_read_data_tx.rlast, m_read_data_tx.rresp.name()),
        UVM_MEDIUM)

      // Search pending_read_txns across all slaves by arid and master_id
      s_idx = -1;
      for(int s = 0; s < NO_OF_SLAVES; s++) begin
        if(pending_read_txns[s].exists(m_read_data_tx.arid)) begin
          if(pending_read_txns[s][m_read_data_tx.arid].size() > 0) begin
            if(pending_read_txns[s][m_read_data_tx.arid][0].master_id == m_idx) begin
              s_idx = s;
              break;
            end
          end
        end
      end

      if(s_idx == -1) begin
        `uvm_error("RD_DATA_NO_SLAVE",
          $sformatf("M[%0d] RID=0x%0h cannot find slave for this transaction",
                    m_idx, m_read_data_tx.arid))
        continue;
      end

      // Wait for address grant on first beat only
      // For subsequent beats the grant is already set from the first beat
      @(slave_read_addr_granted[s_idx]);

      found = 0;

      if(pending_read_txns[s_idx].exists(m_read_data_tx.arid) &&
         pending_read_txns[s_idx][m_read_data_tx.arid].size() > 0) begin

        if(pending_read_txns[s_idx][m_read_data_tx.arid][0].address_granted) begin

          // PEEK at [0] — do NOT pop yet, transaction stays in queue
          // until rlast because subsequent beats need to match against it
          pending_tx = pending_read_txns[s_idx][m_read_data_tx.arid][0];

          if(pending_tx.master_id != m_idx) begin
            `uvm_error("RD_MASTER_MISMATCH",
              $sformatf("S[%0d] RID=0x%0h expected M[%0d] got M[%0d]",
                        s_idx, m_read_data_tx.arid,
                        pending_tx.master_id, m_idx))
          end

          // Compare this beat's data against expected
          // For hits: pending_tx.tx.rdata[] filled from cache at AR time
          // For misses: pending_tx.tx.rdata[] filled from referenceData at AR time
          axi4_read_data_comparison(
            pending_tx.tx,
            m_read_data_tx,
            m_idx,
            s_idx,
            pending_tx.expected_l3_hit
          );

          // On last beat: release MSHR and pop the pending transaction
          if(m_read_data_tx.rlast) begin

            // Release MSHR for misses only
            // Hits never allocated an MSHR so nothing to release
            if(!pending_tx.expected_l3_hit) begin
              int mshr_idx;
              mshr_idx = scb_find_existing_mshr(pending_tx.line_addr);

              if(mshr_idx != -1          &&
                 scb_mshr[mshr_idx].valid &&
                 scb_mshr[mshr_idx].done) begin

                scb_release_mshr(mshr_idx, 1);

                `uvm_info("MSHR_RELEASED", $sformatf("M[%0d] S[%0d] MSHR[%0d] released after master rlast confirmed line=0x%0h", m_idx, s_idx, mshr_idx, pending_tx.line_addr), UVM_MEDIUM)

              end else begin
               `uvm_error("MSHR_RELEASE_FAIL", $sformatf("M[%0d] S[%0d] RID=0x%0h MSHR for line=0x%0h not found or not done at rlast", m_idx, s_idx, m_read_data_tx.arid, pending_tx.line_addr))
              end
            end

            // NOW pop — transaction fully complete
            void'(pending_read_txns[s_idx][m_read_data_tx.arid].pop_front());

            byte_data_cmp_verified_rlast_count++;

            `uvm_info("RD_COMPLETE",
              $sformatf("S[%0d] M[%0d] RID=0x%0h complete L3_HIT=%0b",
                        s_idx, m_idx, m_read_data_tx.arid,
                        pending_tx.expected_l3_hit),
              UVM_MEDIUM)

          end

          found = 1;

        end else begin
          `uvm_error("RD_DATA_BEFORE_AR",
            $sformatf("M[%0d] S[%0d] RID=0x%0h read data before AR granted",
                      m_idx, s_idx, m_read_data_tx.arid))
        end
      end

      if(!found) begin
        `uvm_error("RD_DATA_NO_MATCH",
          $sformatf("M[%0d] RID=0x%0h S[%0d] no granted pending transaction",
                    m_idx, m_read_data_tx.arid, s_idx))
      end

    end // forever
  join_none
end
  
  
 //===========================================================================
 // READ DATA PATH - Slave Side     
 //===========================================================================
  foreach(axi4_slave_read_data_analysis_fifo[i]) begin
  automatic int s_idx = i;
  fork
    forever begin
      axi4_slave_tx        s_read_data_tx;
      int                  mshr_id;
      bit [ADDRESS_WIDTH-1:0] line_base;
      int                  index;
      int                  way;
      bit[1:0] snap_resp_code;

      axi4_slave_read_data_analysis_fifo[s_idx].get(s_read_data_tx);
      axi4_slave_tx_rdata_count[s_idx]++;
      axi4_slave_tx_rresp_count[s_idx]++;

      `uvm_info("SLV_RD_DATA",
        $sformatf("S[%0d] RID=0x%0h RDATA[0]=0x%0h RLAST=%0b RRESP=%0s",
                  s_idx, s_read_data_tx.rid, s_read_data_tx.rdata[0],
                  s_read_data_tx.rlast, s_read_data_tx.rresp.name()),
        UVM_HIGH)

      if(!active_r_valid[s_idx]) begin
        `uvm_warning("SLV_RD_UNEXPECTED",
          $sformatf("S[%0d] read data beat but no active refill MSHR", s_idx))
        continue;
      end

      mshr_id = active_r_mshr[s_idx];

      if(s_read_data_tx.rresp != 2'b00) begin
        scb_mshr[mshr_id].resp_code = s_read_data_tx.rresp;
        `uvm_error("REFILL_RRESP_ERROR",
          $sformatf("S[%0d] MSHR[%0d] beat=%0d RRESP=0x%0h",
                    s_idx, mshr_id,
                    scb_mshr[mshr_id].beat_count,
                    s_read_data_tx.rresp))
      end

      scb_mshr[mshr_id].beat_count++;
      $display("[SCB_REFILL_BEAT] time=%0t mshr=%0d slave=%0d beat=%0d rdata=0x%0h rlast=%0b",$time, mshr_id, s_idx,scb_mshr[mshr_id].beat_count,s_read_data_tx.rdata[0],s_read_data_tx.rlast);

      if(s_read_data_tx.rlast) begin

        // Beat count validation
        if(scb_mshr[mshr_id].beat_count != WORDS_PER_LINE) begin
          `uvm_error("REFILL_BEAT_COUNT",
            $sformatf("S[%0d] MSHR[%0d] RLAST after %0d beats expected %0d",
                      s_idx, mshr_id,
                      scb_mshr[mshr_id].beat_count,
                      WORDS_PER_LINE))
        end

        // Snapshot fields — needed for cache fill below
        line_base      = scb_mshr[mshr_id].line_addr;
        index          = scb_mshr[mshr_id].index;
        way            = scb_mshr[mshr_id].way;
        snap_resp_code = scb_mshr[mshr_id].resp_code;

        // For read miss: done=1 on rlast, MSHR released on master rlast
        // For write miss: done is set only after BOTH rlast AND wlast_seen
        // Do NOT set done here for write miss — let the BRESP path own it
        if(!scb_mshr[mshr_id].is_write)
          scb_mshr[mshr_id].done = 1;
       // For write miss: just record that rlast was seen; done stays 0
        else
          scb_mshr[mshr_id].rlast_seen = 1;   // new field needed

        $display("[SCB_REFILL_COMPLETE] time=%0t mshr=%0d slave=%0d set=%0d way=%0d line=0x%0h beats=%0d is_write=%0b wlast_seen=%0b",$time, mshr_id, s_idx,scb_mshr[mshr_id].index,scb_mshr[mshr_id].way,scb_mshr[mshr_id].line_addr,scb_mshr[mshr_id].beat_count,scb_mshr[mshr_id].is_write,scb_mshr[mshr_id].wlast_seen);
        for(int wb = 0; wb < WORDS_PER_LINE; wb++)
          $display("  [SCB_REFILL_DATA] word[%0d] = %p",wb, l3_cache[scb_mshr[mshr_id].index][scb_mshr[mshr_id].way].data[wb*AXI_DATA_BYTES +: AXI_DATA_BYTES]);

        // Fill scoreboard cache from referenceData only on success
        // MSHR is NOT released here — master R data path owns release
        if(snap_resp_code == 2'b00) begin

          for(int byte_i = 0; byte_i < L3_CACHE_LINE_SIZE_BYTES; byte_i++) begin
            if(referenceData[s_idx].exists(line_base + byte_i))
              l3_cache[index][way].data[byte_i] =
                referenceData[s_idx][line_base + byte_i];
            else
              l3_cache[index][way].data[byte_i] = 8'h00;
          end

        `uvm_info("L3_REFILL_COMPLETE", $sformatf("S[%0d] Cache filled from refMem: line=0x%0h Set=%0d Way=%0d - awaiting master R response for MSHR release", s_idx, line_base, index, way), UVM_MEDIUM)

        end else begin
          `uvm_info("L3_REFILL_ERROR_SKIP",
            $sformatf("S[%0d] MSHR[%0d] RRESP error — cache not installed",
                      s_idx, mshr_id),
            UVM_MEDIUM)
        end

      end // rlast

    end // forever
  join_none
end

 endtask
  
task axi4_scoreboard::axi4_write_address_comparison(
  input axi4_master_tx exp_tx,
  input axi4_slave_tx  act_tx,
  input int            master_id,
  input int            slave_id
);

  // ------------------------------------------------------------------
  // R1 — AWID
  // ------------------------------------------------------------------
  if(exp_tx.awid === act_tx.awid) begin
    byte_data_cmp_verified_awid_count++;
    `uvm_info("AW_CMP_AWID_OK",
      $sformatf("M[%0d]->S[%0d] AWID match: 0x%0h",
                master_id, slave_id, act_tx.awid),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_awid_count++;
    `uvm_error("AW_CMP_AWID_FAIL",
      $sformatf("M[%0d]->S[%0d] AWID mismatch — Expected=0x%0h Got=0x%0h",
                master_id, slave_id, exp_tx.awid, act_tx.awid))
  end

  // ------------------------------------------------------------------
  // R2 — AWADDR
  // For cache-line writebacks the slave sees the cache-line-aligned base
  // address, not necessarily the exact byte address the master wrote to.
  // For non-cacheable / device traffic the exact address is forwarded.
  // ------------------------------------------------------------------
  begin
    axi_cache_policy_s policy;
    bit [ADDRESS_WIDTH-1:0] expected_addr;

    policy = axi_decode_cache_policy(exp_tx.awcache, 0 );

    if(policy.cacheable && !policy.device)
      // Writeback: DUT issues cache-line-aligned address
      expected_addr = get_line_base_addr(exp_tx.awaddr);
    else
      // Bypass: exact address forwarded
      expected_addr = exp_tx.awaddr;

    if(act_tx.awaddr === expected_addr) begin
      byte_data_cmp_verified_awaddr_count++;
      `uvm_info("AW_CMP_AWADDR_OK",
        $sformatf("M[%0d]->S[%0d] AWADDR match: 0x%0h",
                  master_id, slave_id, act_tx.awaddr),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_awaddr_count++;
      `uvm_error("AW_CMP_AWADDR_FAIL",
        $sformatf("M[%0d]->S[%0d] AWADDR mismatch — Expected=0x%0h Got=0x%0h",
                  master_id, slave_id, expected_addr, act_tx.awaddr))
    end
  end

  // ------------------------------------------------------------------
  // R3 — AWLEN
  // Cache writeback bursts must be exactly WORDS_PER_LINE beats long.
  // For non-cacheable bypass, master AWLEN is forwarded verbatim.
  // ------------------------------------------------------------------
  begin
    axi_cache_policy_s policy;
    int expected_len;

    policy = axi_decode_cache_policy(exp_tx.awcache, 0);

    if(policy.cacheable && !policy.device)
      expected_len = WORDS_PER_LINE - 1;   // full cache-line writeback
    else
      expected_len = exp_tx.awlen;          // bypass: exact forwarding

    if(act_tx.awlen === expected_len) begin
      byte_data_cmp_verified_awlen_count++;
      `uvm_info("AW_CMP_AWLEN_OK",
        $sformatf("M[%0d]->S[%0d] AWLEN match: %0d",
                  master_id, slave_id, act_tx.awlen),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_awlen_count++;
      `uvm_error("AW_CMP_AWLEN_FAIL",
        $sformatf("M[%0d]->S[%0d] AWLEN mismatch — Expected=%0d Got=%0d",
                  master_id, slave_id, expected_len, act_tx.awlen))
    end
  end

  // ------------------------------------------------------------------
  // R4 — AWSIZE
  // Writeback beats must use the full bus width.
  // ------------------------------------------------------------------
  begin
    axi_cache_policy_s policy;
    int expected_size;
    int full_bus_size;

    full_bus_size = $clog2(DATA_WIDTH / 8);  // e.g. 3 for 64-bit bus
    policy        = axi_decode_cache_policy(exp_tx.awcache, 0);

    if(policy.cacheable && !policy.device)
      expected_size = full_bus_size;
    else
      expected_size = exp_tx.awsize;

    if(act_tx.awsize === expected_size) begin
      byte_data_cmp_verified_awsize_count++;
      `uvm_info("AW_CMP_AWSIZE_OK",
        $sformatf("M[%0d]->S[%0d] AWSIZE match: %0d",
                  master_id, slave_id, act_tx.awsize),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_awsize_count++;
      `uvm_error("AW_CMP_AWSIZE_FAIL",
        $sformatf("M[%0d]->S[%0d] AWSIZE mismatch — Expected=%0d Got=%0d",
                  master_id, slave_id, expected_size, act_tx.awsize))
    end
  end

  // ------------------------------------------------------------------
  // R5 — AWBURST
  // Cache writeback must always use INCR (2'b01).
  // ------------------------------------------------------------------
  begin
    axi_cache_policy_s policy;
    logic [1:0] expected_burst;

    policy = axi_decode_cache_policy(exp_tx.awcache, 0);

    if(policy.cacheable && !policy.device)
      expected_burst = 2'b01;   // INCR — mandatory for cache-line ops
    else
      expected_burst = exp_tx.awburst;

    if(act_tx.awburst === expected_burst) begin
      byte_data_cmp_verified_awburst_count++;
      `uvm_info("AW_CMP_AWBURST_OK",
        $sformatf("M[%0d]->S[%0d] AWBURST match: 0x%0h",
                  master_id, slave_id, act_tx.awburst),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_awburst_count++;
      `uvm_error("AW_CMP_AWBURST_FAIL",
        $sformatf("M[%0d]->S[%0d] AWBURST mismatch — Expected=0x%0h Got=0x%0h",
                  master_id, slave_id, expected_burst, act_tx.awburst))
    end
  end

  // ------------------------------------------------------------------
  // R6 — AWCACHE
  // Cache attributes must be preserved from master to slave.
  // ------------------------------------------------------------------
  if(exp_tx.awcache === act_tx.awcache) begin
    byte_data_cmp_verified_awcache_count++;
    `uvm_info("AW_CMP_AWCACHE_OK",
      $sformatf("M[%0d]->S[%0d] AWCACHE match: 0x%0h",
                master_id, slave_id, act_tx.awcache),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_awcache_count++;
    `uvm_error("AW_CMP_AWCACHE_FAIL",
      $sformatf("M[%0d]->S[%0d] AWCACHE mismatch — Expected=0x%0h Got=0x%0h",
                master_id, slave_id, exp_tx.awcache, act_tx.awcache))
  end

  // ------------------------------------------------------------------
  // R7 — AWPROT
  // ------------------------------------------------------------------
  if(exp_tx.awprot === act_tx.awprot) begin
    byte_data_cmp_verified_awprot_count++;
    `uvm_info("AW_CMP_AWPROT_OK",
      $sformatf("M[%0d]->S[%0d] AWPROT match: 0x%0h",
                master_id, slave_id, act_tx.awprot),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_awprot_count++;
    `uvm_error("AW_CMP_AWPROT_FAIL",
      $sformatf("M[%0d]->S[%0d] AWPROT mismatch — Expected=0x%0h Got=0x%0h",
                master_id, slave_id, exp_tx.awprot, act_tx.awprot))
  end

  // ------------------------------------------------------------------
  // R8 — AWLOCK
  // AXI4 lock type must be preserved.  Note: LOCK must be NORMAL (1'b0)
  // for cache-line burst operations — exclusive accesses to cacheable
  // lines are illegal per AXI4 spec §A7.
  // ------------------------------------------------------------------
  begin
    axi_cache_policy_s policy;
    logic expected_lock;

    policy = axi_decode_cache_policy(exp_tx.awcache, 0);

    if(policy.cacheable && !policy.device) begin
      expected_lock = 1'b0;  // Must be NORMAL for cache-line ops
      if(exp_tx.awlock !== 1'b0) begin
`uvm_warning("AW_LOCK_CACHEABLE", $sformatf("M[%0d]->S[%0d] Master issued EXCLUSIVE LOCK on cacheable write AWADDR=0x%0h - AXI4 spec violation A7", master_id, slave_id, exp_tx.awaddr))
      end
    end
    else begin
      expected_lock = exp_tx.awlock;
    end

    if(act_tx.awlock === expected_lock) begin
      byte_data_cmp_verified_awlock_count++;
      `uvm_info("AW_CMP_AWLOCK_OK",
        $sformatf("M[%0d]->S[%0d] AWLOCK match: %0b",
                  master_id, slave_id, act_tx.awlock),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_awlock_count++;
      `uvm_error("AW_CMP_AWLOCK_FAIL",
        $sformatf("M[%0d]->S[%0d] AWLOCK mismatch — Expected=%0b Got=%0b",
                  master_id, slave_id, expected_lock, act_tx.awlock))
    end
  end

endtask : axi4_write_address_comparison

task axi4_scoreboard::axi4_write_data_comparison(
  input axi4_master_tx exp_tx,
  input axi4_slave_tx  act_tx,
  input int            master_id,
  input int            slave_id
);

  axi_cache_policy_s policy;
  policy = axi_decode_cache_policy(exp_tx.awcache, 0);

  // ------------------------------------------------------------------
  // NON-CACHEABLE / DEVICE BYPASS — exact forwarding
  // ------------------------------------------------------------------
  if(policy.device || !policy.cacheable) begin

    foreach(exp_tx.wdata[beat]) begin

      // R9 — WDATA (per strobe)
      for(int lane = 0; lane < (DATA_WIDTH/8); lane++) begin
        if(exp_tx.wstrb[beat][lane]) begin
          byte exp_byte = exp_tx.wdata[beat][8*lane +: 8];
          byte act_byte = act_tx.wdata[beat][8*lane +: 8];

          if(exp_byte === act_byte) begin
            byte_data_cmp_verified_wdata_count++;
          end
          else begin
            byte_data_cmp_failed_wdata_count++;
`uvm_error("W_CMP_WDATA_FAIL", $sformatf("M[%0d]->S[%0d] WDATA bypass mismatch - Beat=%0d Lane=%0d Expected=0x%0h Got=0x%0h", master_id, slave_id, beat, lane, exp_byte, act_byte))
          end
        end
      end

      // R10 — WSTRB
      if(exp_tx.wstrb[beat] === act_tx.wstrb[beat]) begin
        byte_data_cmp_verified_wstrb_count++;
      end
      else begin
        byte_data_cmp_failed_wstrb_count++;
 `uvm_error("W_CMP_WSTRB_FAIL", $sformatf("M[%0d]->S[%0d] WSTRB bypass mismatch - Beat=%0d Expected=0x%0h Got=0x%0h", master_id, slave_id, beat, exp_tx.wstrb[beat], act_tx.wstrb[beat]))
      end

    end // foreach beat

    // R11 — WLAST on final beat of master burst
    if(act_tx.wlast === 1'b1) begin
      byte_data_cmp_verified_wlast_count++;
    end
    else begin
      byte_data_cmp_failed_wlast_count++;
      `uvm_error("W_CMP_WLAST_FAIL",
        $sformatf("M[%0d]->S[%0d] WLAST not asserted at end of bypass burst",
                  master_id, slave_id))
    end

  end
  else begin

    begin
      logic [(DATA_WIDTH/8)-1:0] expected_strb = {(DATA_WIDTH/8){1'b1}};

      if(act_tx.wstrb[0] === expected_strb) begin
        byte_data_cmp_verified_wstrb_count++;
        `uvm_info("W_CMP_WSTRB_WB_OK",
          $sformatf("M[%0d]->S[%0d] WB WSTRB correct: all-ones",
                    master_id, slave_id),
          UVM_HIGH)
      end
      else begin
        byte_data_cmp_failed_wstrb_count++;
      `uvm_error("W_CMP_WSTRB_WB_FAIL", $sformatf("M[%0d]->S[%0d] WB WSTRB non-all-ones: Got=0x%0h - AXI4 writeback must write all byte lanes", master_id, slave_id, act_tx.wstrb[0]))
      end
    end
    
    if(act_tx.wstrb[0] === {(DATA_WIDTH/8){1'b1}}) begin
      byte_data_cmp_verified_wdata_count++;
    end

    // R11 — WLAST on final writeback beat
    // WLAST position is validated in run_phase; mirror it here for
    // the verified counter.
    if(act_tx.wlast) begin
      byte_data_cmp_verified_wlast_count++;
      `uvm_info("W_CMP_WLAST_WB_OK",
        $sformatf("M[%0d]->S[%0d] WB WLAST correctly asserted on final beat",
                  master_id, slave_id),
        UVM_HIGH)
    end

  end

endtask : axi4_write_data_comparison


task axi4_scoreboard::axi4_write_response_comparison(
  input axi4_master_tx exp_tx,
  input axi4_slave_tx  act_tx,
  input int            master_id,
  input int            slave_id
);

  // ------------------------------------------------------------------
  // R12 — BID must echo AWID
  // ------------------------------------------------------------------
  if(act_tx.bid === exp_tx.awid) begin
    byte_data_cmp_verified_bid_count++;
    `uvm_info("B_CMP_BID_OK",
      $sformatf("M[%0d]->S[%0d] BID match: 0x%0h",
                master_id, slave_id, act_tx.bid),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_bid_count++;
    `uvm_error("B_CMP_BID_FAIL",
      $sformatf("M[%0d]->S[%0d] BID mismatch — AWID=0x%0h Got BID=0x%0h",
                master_id, slave_id, exp_tx.awid, act_tx.bid))
  end

  // ------------------------------------------------------------------
  // R13 — BRESP encoding check
  // ------------------------------------------------------------------
  case(act_tx.bresp)
    2'b00: begin // OKAY
      byte_data_cmp_verified_bresp_count++;
      `uvm_info("B_CMP_BRESP_OKAY",
        $sformatf("M[%0d]->S[%0d] BRESP=OKAY for AWID=0x%0h",
                  master_id, slave_id, exp_tx.awid),
        UVM_HIGH)
    end

    2'b01: begin // EXOKAY — only legal if AWLOCK was set
      if(exp_tx.awlock === 1'b1) begin
        byte_data_cmp_verified_bresp_count++;
        `uvm_info("B_CMP_BRESP_EXOKAY",
          $sformatf("M[%0d]->S[%0d] BRESP=EXOKAY for exclusive AWID=0x%0h — OK",
                    master_id, slave_id, exp_tx.awid),
          UVM_HIGH)
      end
      else begin
        byte_data_cmp_failed_bresp_count++;
    `uvm_error("B_CMP_BRESP_EXOKAY_ILLEGAL", $sformatf("M[%0d]->S[%0d] BRESP=EXOKAY but AWLOCK was NORMAL - AXI4 violation AWID=0x%0h", master_id, slave_id, exp_tx.awid))
      end
    end

    2'b10: begin // SLVERR
      byte_data_cmp_failed_bresp_count++;
      `uvm_error("B_CMP_BRESP_SLVERR",
        $sformatf("M[%0d]->S[%0d] BRESP=SLVERR for AWID=0x%0h AWADDR=0x%0h",
                  master_id, slave_id, exp_tx.awid, exp_tx.awaddr))
    end

    2'b11: begin // DECERR
      byte_data_cmp_failed_bresp_count++;
     `uvm_error("B_CMP_BRESP_DECERR", $sformatf("M[%0d]->S[%0d] BRESP=DECERR for AWID=0x%0h AWADDR=0x%0h - address decode failure", master_id, slave_id, exp_tx.awid, exp_tx.awaddr))
    end

    default: begin
      byte_data_cmp_failed_bresp_count++;
      `uvm_error("B_CMP_BRESP_UNKNOWN",
        $sformatf("M[%0d]->S[%0d] Unknown BRESP=0x%0h AWID=0x%0h",
                  master_id, slave_id, act_tx.bresp, exp_tx.awid))
    end
  endcase

endtask : axi4_write_response_comparison

task axi4_scoreboard::axi4_read_address_comparison(
  input axi4_master_tx exp_tx,
  input axi4_slave_tx  act_tx,
  input int            master_id,
  input int            slave_id
);

  axi_cache_policy_s policy;
  policy = axi_decode_cache_policy(exp_tx.arcache, 1 );

  // ------------------------------------------------------------------
  // R14 — ARID
  // ------------------------------------------------------------------
  if(exp_tx.arid === act_tx.arid) begin
    byte_data_cmp_verified_arid_count++;
    `uvm_info("AR_CMP_ARID_OK",
      $sformatf("M[%0d]->S[%0d] ARID match: 0x%0h",
                master_id, slave_id, act_tx.arid),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_arid_count++;
    `uvm_error("AR_CMP_ARID_FAIL",
      $sformatf("M[%0d]->S[%0d] ARID mismatch — Expected=0x%0h Got=0x%0h",
                master_id, slave_id, exp_tx.arid, act_tx.arid))
  end

  // ------------------------------------------------------------------
  // R15 — ARADDR
  // ------------------------------------------------------------------
  begin
    bit [ADDRESS_WIDTH-1:0] expected_addr;

    if(policy.cacheable && !policy.device)
      expected_addr = get_line_base_addr(exp_tx.araddr);  // refill
    else
      expected_addr = exp_tx.araddr;                       // bypass

    if(act_tx.araddr === expected_addr) begin
      byte_data_cmp_verified_araddr_count++;
      `uvm_info("AR_CMP_ARADDR_OK",
        $sformatf("M[%0d]->S[%0d] ARADDR match: 0x%0h",
                  master_id, slave_id, act_tx.araddr),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_araddr_count++;
      `uvm_error("AR_CMP_ARADDR_FAIL",
        $sformatf("M[%0d]->S[%0d] ARADDR mismatch — Expected=0x%0h Got=0x%0h",
                  master_id, slave_id, expected_addr, act_tx.araddr))
    end
  end

  // ------------------------------------------------------------------
  // R16 — ARLEN
  // ------------------------------------------------------------------
  begin
    int expected_len;

    if(policy.cacheable && !policy.device)
      expected_len = WORDS_PER_LINE - 1;
    else
      expected_len = exp_tx.arlen;

    if(act_tx.arlen === expected_len) begin
      byte_data_cmp_verified_arlen_count++;
      `uvm_info("AR_CMP_ARLEN_OK",
        $sformatf("M[%0d]->S[%0d] ARLEN match: %0d",
                  master_id, slave_id, act_tx.arlen),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_arlen_count++;
      `uvm_error("AR_CMP_ARLEN_FAIL",
        $sformatf("M[%0d]->S[%0d] ARLEN mismatch — Expected=%0d Got=%0d",
                  master_id, slave_id, expected_len, act_tx.arlen))
    end
  end

  // ------------------------------------------------------------------
  // R17 — ARSIZE
  // ------------------------------------------------------------------
  begin
    int expected_size;
    int full_bus_size;

    full_bus_size = $clog2(DATA_WIDTH / 8);
    expected_size = (policy.cacheable && !policy.device) ? full_bus_size
                                                         : exp_tx.arsize;

    if(act_tx.arsize === expected_size) begin
      byte_data_cmp_verified_arsize_count++;
      `uvm_info("AR_CMP_ARSIZE_OK",
        $sformatf("M[%0d]->S[%0d] ARSIZE match: %0d",
                  master_id, slave_id, act_tx.arsize),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_arsize_count++;
      `uvm_error("AR_CMP_ARSIZE_FAIL",
        $sformatf("M[%0d]->S[%0d] ARSIZE mismatch — Expected=%0d Got=%0d",
                  master_id, slave_id, expected_size, act_tx.arsize))
    end
  end

  // ------------------------------------------------------------------
  // R18 — ARBURST — INCR mandatory for cache-line refills
  // ------------------------------------------------------------------
  begin
    logic [1:0] expected_burst;

    expected_burst = (policy.cacheable && !policy.device) ? 2'b01
                                                          : exp_tx.arburst;

    if(act_tx.arburst === expected_burst) begin
      byte_data_cmp_verified_arburst_count++;
      `uvm_info("AR_CMP_ARBURST_OK",
        $sformatf("M[%0d]->S[%0d] ARBURST match: 0x%0h",
                  master_id, slave_id, act_tx.arburst),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_arburst_count++;
      `uvm_error("AR_CMP_ARBURST_FAIL",
        $sformatf("M[%0d]->S[%0d] ARBURST mismatch — Expected=0x%0h Got=0x%0h",
                  master_id, slave_id, expected_burst, act_tx.arburst))
    end
  end

  // ------------------------------------------------------------------
  // R19 — ARCACHE
  // ------------------------------------------------------------------
  if(exp_tx.arcache === act_tx.arcache) begin
    byte_data_cmp_verified_arcache_count++;
    `uvm_info("AR_CMP_ARCACHE_OK",
      $sformatf("M[%0d]->S[%0d] ARCACHE match: 0x%0h",
                master_id, slave_id, act_tx.arcache),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_arcache_count++;
    `uvm_error("AR_CMP_ARCACHE_FAIL",
      $sformatf("M[%0d]->S[%0d] ARCACHE mismatch — Expected=0x%0h Got=0x%0h",
                master_id, slave_id, exp_tx.arcache, act_tx.arcache))
  end

  // ------------------------------------------------------------------
  // R20 — ARPROT
  // ------------------------------------------------------------------
  if(exp_tx.arprot === act_tx.arprot) begin
    byte_data_cmp_verified_arprot_count++;
    `uvm_info("AR_CMP_ARPROT_OK",
      $sformatf("M[%0d]->S[%0d] ARPROT match: 0x%0h",
                master_id, slave_id, act_tx.arprot),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_arprot_count++;
    `uvm_error("AR_CMP_ARPROT_FAIL",
      $sformatf("M[%0d]->S[%0d] ARPROT mismatch — Expected=0x%0h Got=0x%0h",
                master_id, slave_id, exp_tx.arprot, act_tx.arprot))
  end

  // ------------------------------------------------------------------
  // R21 — ARLOCK — must be NORMAL for cacheable refills
  // ------------------------------------------------------------------
  begin
    logic expected_lock;

    if(policy.cacheable && !policy.device) begin
      expected_lock = 1'b0;
      if(exp_tx.arlock !== 1'b0) begin
`uvm_warning("AR_LOCK_CACHEABLE", $sformatf("M[%0d]->S[%0d] Master issued EXCLUSIVE LOCK on cacheable read ARADDR=0x%0h - AXI4 spec violation A7", master_id, slave_id, exp_tx.araddr))
      end
    end
    else begin
      expected_lock = exp_tx.arlock;
    end

    if(act_tx.arlock === expected_lock) begin
      byte_data_cmp_verified_arlock_count++;
      `uvm_info("AR_CMP_ARLOCK_OK",
        $sformatf("M[%0d]->S[%0d] ARLOCK match: %0b",
                  master_id, slave_id, act_tx.arlock),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_arlock_count++;
      `uvm_error("AR_CMP_ARLOCK_FAIL",
        $sformatf("M[%0d]->S[%0d] ARLOCK mismatch — Expected=%0b Got=%0b",
                  master_id, slave_id, expected_lock, act_tx.arlock))
    end
  end

  // ------------------------------------------------------------------
  // R22 — ARQOS
  // ------------------------------------------------------------------
  if(exp_tx.arqos === act_tx.arqos) begin
    byte_data_cmp_verified_arqos_count++;
    `uvm_info("AR_CMP_ARQOS_OK",
      $sformatf("M[%0d]->S[%0d] ARQOS match: 0x%0h",
                master_id, slave_id, act_tx.arqos),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_arqos_count++;
    `uvm_error("AR_CMP_ARQOS_FAIL",
      $sformatf("M[%0d]->S[%0d] ARQOS mismatch — Expected=0x%0h Got=0x%0h",
                master_id, slave_id, exp_tx.arqos, act_tx.arqos))
  end

  // ------------------------------------------------------------------
  // R23 — ARREGION
  // ------------------------------------------------------------------
  if(exp_tx.arregion === act_tx.arregion) begin
    byte_data_cmp_verified_arregion_count++;
    `uvm_info("AR_CMP_ARREGION_OK",
      $sformatf("M[%0d]->S[%0d] ARREGION match: 0x%0h",
                master_id, slave_id, act_tx.arregion),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_arregion_count++;
    `uvm_error("AR_CMP_ARREGION_FAIL",
      $sformatf("M[%0d]->S[%0d] ARREGION mismatch — Expected=0x%0h Got=0x%0h",
                master_id, slave_id, exp_tx.arregion, act_tx.arregion))
  end

endtask : axi4_read_address_comparison

task automatic axi4_scoreboard::axi4_read_data_comparison(
  input axi4_master_tx exp_tx,
  input axi4_master_tx act_tx,
  input int            master_id,
  input int            slave_id,
  input bit            expected_hit
);

  // ------------------------------------------------------------------
  // R24 — RID
  // ------------------------------------------------------------------
  if(act_tx.arid === exp_tx.arid) begin
    byte_data_cmp_verified_rid_count++;
    `uvm_info("R_CMP_RID_OK",
      $sformatf("M[%0d] S[%0d] RID match: 0x%0h",
                master_id, slave_id, act_tx.arid),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_rid_count++;
    `uvm_error("R_CMP_RID_FAIL",
      $sformatf("M[%0d] S[%0d] RID mismatch — ARID=0x%0h Got RID=0x%0h",
                master_id, slave_id, exp_tx.arid, act_tx.arid))
  end

  // ------------------------------------------------------------------
  // R26 — RRESP per beat
  // ------------------------------------------------------------------
  foreach(act_tx.rresp[beat]) begin
    case(act_tx.rresp[beat])
      2'b00: begin // OKAY
        byte_data_cmp_verified_rresp_count++;
      end
      2'b01: begin // EXOKAY
        if(exp_tx.arlock === 1'b1) begin
          byte_data_cmp_verified_rresp_count++;
        `uvm_info("R_CMP_RRESP_EXOKAY", $sformatf("M[%0d] S[%0d] Beat=%0d RRESP=EXOKAY for exclusive ARID=0x%0h - OK", master_id, slave_id, beat, exp_tx.arid), UVM_HIGH)
        end
        else begin
          byte_data_cmp_failed_rresp_count++;
          `uvm_error("R_CMP_RRESP_EXOKAY_ILLEGAL", $sformatf("M[%0d] S[%0d] Beat=%0d RRESP=EXOKAY but ARLOCK=NORMAL - AXI4 violation ARID=0x%0h", master_id, slave_id, beat, exp_tx.arid))
        end
      end
      2'b10: begin // SLVERR
        byte_data_cmp_failed_rresp_count++;
        `uvm_error("R_CMP_RRESP_SLVERR",
          $sformatf("M[%0d] S[%0d] Beat=%0d RRESP=SLVERR ARID=0x%0h",
                    master_id, slave_id, beat, exp_tx.arid))
      end
      2'b11: begin // DECERR
        byte_data_cmp_failed_rresp_count++;
        `uvm_error("R_CMP_RRESP_DECERR",
          $sformatf("M[%0d] S[%0d] Beat=%0d RRESP=DECERR ARID=0x%0h ARADDR=0x%0h",
                    master_id, slave_id, beat, exp_tx.arid, exp_tx.araddr))
      end
      default: begin
        byte_data_cmp_failed_rresp_count++;
        `uvm_error("R_CMP_RRESP_UNKNOWN",
          $sformatf("M[%0d] S[%0d] Beat=%0d Unknown RRESP=0x%0h",
                    master_id, slave_id, beat, act_tx.rresp[beat]))
      end
    endcase
  end

  // ------------------------------------------------------------------
  // R27 — RLAST
  // act_tx.rlast must be 1 only on the final beat (arlen'th beat).
  // The run_phase pops the pending transaction only after rlast so by
  // the time this task sees it, rlast is expected to be asserted.
  // ------------------------------------------------------------------
  if(act_tx.rlast === 1'b1) begin
    byte_data_cmp_verified_rlast_count++;
    `uvm_info("R_CMP_RLAST_OK",
      $sformatf("M[%0d] S[%0d] RLAST correctly asserted ARID=0x%0h",
                master_id, slave_id, exp_tx.arid),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_rlast_count++;
`uvm_error("R_CMP_RLAST_FAIL", $sformatf("M[%0d] S[%0d] RLAST NOT asserted at final beat ARID=0x%0h ARLEN=%0d", master_id, slave_id, exp_tx.arid, exp_tx.arlen))
  end

  // ------------------------------------------------------------------
  // R25 — RDATA per beat
  // ------------------------------------------------------------------
  if(expected_hit) begin
    // ================================================================
    // HIT PATH — compare against L3 cache shadow
    // ================================================================
    bit [L3_TAG_BITS-1:0]   tag;
    bit [L3_INDEX_BITS-1:0] index;
    bit [L3_OFFSET_BITS-1:0] offset;
    int hit_way = -1;

    l3_cache_decode_address(exp_tx.araddr, tag, index, offset);

    for(int w = 0; w < L3_CACHE_ASSOCIATIVITY; w++) begin
      if(l3_cache[index][w].valid                &&
         l3_cache[index][w].tag   == tag         &&
         l3_cache[index][w].state != L3_INVALID  &&
         l3_cache[index][w].state != L3_FILLING) begin
        hit_way = w;
        break;
      end
    end

    if(hit_way == -1) begin
      byte_data_cmp_failed_rdata_count++;
`uvm_error("R_CMP_HIT_WAY_MISSING",
  $sformatf("M[%0d] S[%0d] Expected HIT but cache line not found ARADDR=0x%0h",
            master_id, slave_id, exp_tx.araddr))
    end
    else begin
      int bytes_per_beat = 1 << exp_tx.arsize;
      longint temp_addr  = exp_tx.araddr;
      longint wrap_boundary;
      longint wrap_start_addr;
      longint wrap_end_addr;
      int align_amount;

      wrap_boundary   = bytes_per_beat * (exp_tx.arlen + 1);
      wrap_start_addr = (longint'(exp_tx.araddr) / wrap_boundary) * wrap_boundary;
      wrap_end_addr   = wrap_start_addr + wrap_boundary;
      align_amount    = longint'(exp_tx.araddr) % bytes_per_beat;

      foreach(act_tx.rdata[beat]) begin
        int local_align = (beat == 0) ? align_amount : 0;
        bit beat_ok = 1;

        for(int byte_idx = local_align; byte_idx < bytes_per_beat; byte_idx++) begin
          int line_offset;
          int lane;
          byte cache_byte;
          byte dut_byte;

          line_offset  = int'(temp_addr) % L3_CACHE_LINE_SIZE_BYTES;
          lane         = int'(temp_addr) % (DATA_WIDTH / 8);
          cache_byte   = l3_cache[index][hit_way].data[line_offset];
          dut_byte     = act_tx.rdata[beat][8*lane +: 8];

          if(cache_byte !== dut_byte) begin
            beat_ok = 0;
`uvm_error("R_CMP_HIT_DATA_MISMATCH",
  $sformatf("M[%0d] S[%0d] HIT Beat=%0d ByteIdx=%0d Addr=0x%0h Lane=%0d Expected(cache)=0x%0h Got=0x%0h",
            master_id, slave_id,
            beat, byte_idx,
            temp_addr, lane,
            cache_byte, dut_byte))
          end

          // Advance address per burst type
          case(exp_tx.arburst)
            2'b00: ; // FIXED — temp_addr stays at araddr
            2'b01: temp_addr++;  // INCR
            2'b10: begin         // WRAP
              temp_addr++;
              if(temp_addr >= wrap_end_addr)
                temp_addr = wrap_start_addr;
            end
            default: temp_addr++;
          endcase
        end

        if(beat_ok) begin
          byte_data_cmp_verified_rdata_count++;
          `uvm_info("R_CMP_HIT_DATA_OK",
            $sformatf("M[%0d] S[%0d] HIT Beat=%0d RDATA OK",
                      master_id, slave_id, beat),
            UVM_HIGH)
        end

      end // foreach beat
    end

  end // HIT PATH
  else begin
    // ================================================================
    // MISS PATH — compare against referenceData[]
    // ================================================================
    int bytes_per_beat = 1 << exp_tx.arsize;
    longint temp_addr  = exp_tx.araddr;
    longint wrap_boundary;
    longint wrap_start_addr;
    longint wrap_end_addr;
    int align_amount;

    wrap_boundary   = bytes_per_beat * (exp_tx.arlen + 1);
    wrap_start_addr = (longint'(exp_tx.araddr) / wrap_boundary) * wrap_boundary;
    wrap_end_addr   = wrap_start_addr + wrap_boundary;
    align_amount    = longint'(exp_tx.araddr) % bytes_per_beat;

    foreach(act_tx.rdata[beat]) begin
      int local_align = (beat == 0) ? align_amount : 0;
      bit beat_ok = 1;

      for(int byte_idx = local_align; byte_idx < bytes_per_beat; byte_idx++) begin
        int lane = int'(temp_addr) % (DATA_WIDTH / 8);
        byte expected_byte;
        byte dut_byte;

        expected_byte = referenceData[slave_id].exists(temp_addr)
                        ? referenceData[slave_id][temp_addr]
                        : 8'h00;
        dut_byte      = act_tx.rdata[beat][8*lane +: 8];

        if(expected_byte !== dut_byte) begin
          beat_ok = 0;
          byte_data_cmp_failed_rdata_count++;
          `uvm_error("R_CMP_MISS_DATA_MISMATCH",$sformatf("M[%0d] S[%0d] MISS Beat=%0d ByteIdx=%0d Addr=0x%0h Lane=%0d Expected(refMem)=0x%0h Got=0x%0h",master_id, slave_id,
                      beat, byte_idx,
                      temp_addr, lane,
                      expected_byte, dut_byte))
        end

        // Advance address per burst type
        case(exp_tx.arburst)
          2'b00: ; // FIXED
          2'b01: temp_addr++;  // INCR
          2'b10: begin         // WRAP
            temp_addr++;
            if(temp_addr >= wrap_end_addr)
              temp_addr = wrap_start_addr;
          end
          default: temp_addr++;
        endcase
      end

      if(beat_ok) begin
        byte_data_cmp_verified_rdata_count++;
        `uvm_info("R_CMP_MISS_DATA_OK",$sformatf("M[%0d] S[%0d] MISS Beat=%0d RDATA OK",master_id, slave_id, beat),UVM_HIGH)
      end

    end // foreach beat
  end // MISS PATH

endtask : axi4_read_data_comparison
`endif
