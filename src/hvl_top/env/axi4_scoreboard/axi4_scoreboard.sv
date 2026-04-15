import uvm_pkg::*;
import axi4_globals_pkg::*;
`include "uvm_macros.svh"

class axi4_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi4_scoreboard)

  axi4_master_tx axi4_master_tx_h;
  axi4_slave_tx axi4_slave_tx_h;

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
  localparam int L3_TAG_BITS    = ADDR_WIDTH - L3_INDEX_BITS - L3_OFFSET_BITS;
  localparam int MAX_MSHR = 2;
  
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
   bit [ADDR_WIDTH-1:0]    line_addr;

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
   bit [1:0] resp_code;

   // ---------------- Write Data Buffer 
   logic [DATA_W-1:0] wdata_buf[WORDS_PER_LINE];
   logic [STRB_W-1:0] wstrb_buf[WORDS_PER_LINE];
   int wbeat_count;

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
  bit [ADDR_WIDTH-1:0] scb_write_line;

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
    bit [ADDR_WIDTH-1:0] line_addr;
  } pending_read_transaction_t;

  pending_write_transaction_t pending_write_txns[int][bit[ID_WIDTH-1:0]][$];
  pending_read_transaction_t pending_read_txns[int][bit[ID_WIDTH-1:0]][$];

  //=============================================================================
  // REFERENCE MEMORY (MAIN MEMORY)
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
  
  bit[ADDR_WIDTH-1:0] SLAVE_START_ADDR[];
  bit[ADDR_WIDTH-1:0] SLAVE_END_ADDR[];

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
    input  bit [ADDR_WIDTH-1:0] addr,
    output bit [L3_TAG_BITS-1:0]   tag,
    output bit [L3_INDEX_BITS-1:0] index,
    output bit [L3_OFFSET_BITS-1:0] offset
  );

  extern virtual function bit l3_cache_lookup(
    input  bit [ADDR_WIDTH-1:0] addr,
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
    input bit [ADDR_WIDTH-1:0] addr,
    input int master,
    input int txn_id,
    input bit is_write
  );
  
  extern virtual function int scb_find_existing_mshr(
    input bit [ADDR_WIDTH-1:0] line_addr
  );
  
  extern virtual function void scb_update_mshr_beat(
    input int slave,
    input logic [DATA_WIDTH-1:0] data,
    input bit rlast
  );
  
  extern virtual function void scb_update_mshr_write_data(
    input int mshr_idx,
    input byte wdata[],
    input bit wstrb[]
  );
  
  extern virtual function void scb_release_mshr(
    input int mshr_idx
  );

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
  
  extern virtual function bit[ADDR_WIDTH-1:0] get_line_base_addr(
    bit[ADDR_WIDTH-1:0] addr
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
  extern virtual function int get_slave_index(logic[ADDR_WIDTH-1:0] addr);
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
  extern virtual task automatic axi4_read_data_comparison(input axi4_master_tx exp_tx, input axi4_master_tx act_tx, input int master_id, input int slave_id, input bit expected_hit);
endclass : axi4_scoreboard

//=============================================================================
// IMPLEMENTATION — split across included files
//=============================================================================

`include "axi4_scoreboard_phases.sv"
`include "axi4_scoreboard_cache.sv"
`include "axi4_scoreboard_ref_model.sv"
`include "axi4_scoreboard_run.sv"
