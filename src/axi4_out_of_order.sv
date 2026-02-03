`ifndef AXI4_SCOREBOARD_OOO_INCLUDED_
`define AXI4_SCOREBOARD_OOO_INCLUDED_

class axi4_scoreboard_ooo extends uvm_scoreboard;
  `uvm_component_utils(axi4_scoreboard_ooo)

  axi4_master_tx axi4_master_tx_h;
  axi4_slave_tx axi4_slave_tx_h;

  //--------------------------------------------------------------------------------------------
  // Transaction tracking structures for OUT-OF-ORDER
  //--------------------------------------------------------------------------------------------
  typedef struct {
    axi4_master_tx tx;
    int master_id;
    int slave_id;
    bit address_granted;
    bit write_data_complete;
    int beats_received;
    time addr_grant_time;      // Track when address was granted
  } pending_write_transaction_t;

  typedef struct {
    axi4_master_tx tx;
    int master_id;
    int slave_id;
    bit address_granted;
    bit data_returned;         // Track if read data has been returned
    time addr_grant_time;      // Track when address was granted
  } pending_read_transaction_t;

  // OUT-OF-ORDER: Track pending transactions by ID per slave
  // Multiple transactions with same ID can be outstanding (different masters or different addresses)
  pending_write_transaction_t pending_write_txns[int][bit[ID_WIDTH-1:0]][$];  // [slave_id][awid][$]
  pending_read_transaction_t pending_read_txns[int][bit[ID_WIDTH-1:0]][$];    // [slave_id][arid][$]

  // Reference memory indexed by [slave_id][address]
  logic[7:0] referenceData[int][longint];

  //--------------------------------------------------------------------------------------------
  // Round-Robin Arbitration Tracking (Using counters)
  //--------------------------------------------------------------------------------------------
  // Write channel arbitration
  int rr_write_next_master[int];              // [slave_id] -> next master to check
  int rr_write_pending_cnt[int][int];         // [slave_id][master_id] -> pending request count
  int rr_write_last_granted[int];             // [slave_id] -> last granted master
  
  // Read channel arbitration  
  int rr_read_next_master[int];               // [slave_id] -> next master to check
  int rr_read_pending_cnt[int][int];          // [slave_id][master_id] -> pending request count
  int rr_read_last_granted[int];              // [slave_id] -> last granted master

  // Events for synchronization
  event slave_write_addr_granted[int];        // [slave_id] - triggered per grant
  event slave_read_addr_granted[int];         // [slave_id] - triggered per grant

  //--------------------------------------------------------------------------------------------
  // OUT-OF-ORDER tracking: Outstanding transactions per ID
  //--------------------------------------------------------------------------------------------
  // Track which IDs have outstanding transactions waiting for data
  typedef struct {
    bit[ID_WIDTH-1:0] id;
    int count;
  } id_outstanding_t;
  
  int write_outstanding_by_id[int][bit[ID_WIDTH-1:0]];  // [slave_id][awid] -> count
  int read_outstanding_by_id[int][bit[ID_WIDTH-1:0]];   // [slave_id][arid] -> count

  //--------------------------------------------------------------------------------------------
  // TLM FIFOs
  //--------------------------------------------------------------------------------------------
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

  //--------------------------------------------------------------------------------------------
  // Transaction counters per master/slave
  //--------------------------------------------------------------------------------------------
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

  //--------------------------------------------------------------------------------------------
  // Global transaction counters
  //--------------------------------------------------------------------------------------------
  int total_master_tx_count = 0;
  int total_slave_tx_count = 0;
  
  //--------------------------------------------------------------------------------------------
  // Comparison result counters
  //--------------------------------------------------------------------------------------------
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

  // Arbitration violation counters
  int rr_write_violations;
  int rr_read_violations;
  int rr_write_grants;
  int rr_read_grants;
  
  // OUT-OF-ORDER specific counters
  int ooo_write_reorder_count;  // Count of out-of-order write completions
  int ooo_read_reorder_count;   // Count of out-of-order read completions

  //--------------------------------------------------------------------------------------------
  // Slave address configuration
  //--------------------------------------------------------------------------------------------
  bit[ADDR_WIDTH-1:0] SLAVE_START_ADDR[];
  bit[ADDR_WIDTH-1:0] SLAVE_END_ADDR[];

  //--------------------------------------------------------------------------------------------
  // Helper variables
  //--------------------------------------------------------------------------------------------
  int nonExistantMemRead;
  
  //--------------------------------------------------------------------------------------------
  // Environment configuration handle
  //--------------------------------------------------------------------------------------------
  axi4_env_config axi4_env_cfg_h;
  axi4_slave_agent_config axi4_slave_agent_cfg_h[];

  //--------------------------------------------------------------------------------------------
  // Externally defined functions and tasks
  //--------------------------------------------------------------------------------------------
  extern function new(string name = "axi4_scoreboard_ooo", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);
  extern virtual function int get_slave_index(logic[ADDR_WIDTH-1:0] addr);
  extern virtual function void ref_model_write(axi4_master_tx m_tx, int slave_idx, int master_idx);
  extern virtual function void ref_model_read(axi4_master_tx m_tx, int slave_idx);
  extern virtual function void check_write_rr_arbitration(int slave_id, int granted_master);
  extern virtual function void check_read_rr_arbitration(int slave_id, int granted_master);
  extern virtual function int find_matching_write_txn(int s_idx, bit[ID_WIDTH-1:0] id, axi4_slave_tx s_tx);
  extern virtual function int find_matching_read_txn(int s_idx, bit[ID_WIDTH-1:0] id, axi4_master_tx m_tx);
  extern virtual task axi4_write_address_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id, input int slave_id);
  extern virtual task axi4_write_data_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id, input int slave_id);
  extern virtual task axi4_write_response_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id, input int slave_id);
  extern virtual task axi4_read_address_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id, input int slave_id);
  extern virtual task axi4_read_data_comparison(input axi4_master_tx exp_tx, input axi4_master_tx act_tx, input int master_id, input int slave_id);
  extern virtual function void check_phase(uvm_phase phase);
  extern virtual function void report_phase(uvm_phase phase);

endclass : axi4_scoreboard_ooo

//--------------------------------------------------------------------------------------------
// Function: new
//--------------------------------------------------------------------------------------------
function axi4_scoreboard_ooo::new(string name = "axi4_scoreboard_ooo", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
//--------------------------------------------------------------------------------------------
function void axi4_scoreboard_ooo::build_phase(uvm_phase phase);
  super.build_phase(phase);
  
  if(!uvm_config_db#(axi4_env_config)::get(this, "", "axi4_env_config", axi4_env_cfg_h)) begin
    `uvm_fatal("FATAL_ENV_CONFIG", "Couldn't get axi4_env_config from config_db")
  end
  
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
    
    // Get slave agent configuration
    if(!uvm_config_db#(axi4_slave_agent_config)::get(this, "", $sformatf("axi4_slave_agent_config[%0d]", i), axi4_slave_agent_cfg_h[i])) begin
      `uvm_fatal("FATAL_SA_AGENT_CONFIG", $sformatf("Couldn't get axi4_slave_agent_config[%0d] from config_db", i))
    end
    
    SLAVE_START_ADDR[i] = axi4_slave_agent_cfg_h[i].min_address;
    SLAVE_END_ADDR[i] = axi4_slave_agent_cfg_h[i].max_address;
  end
  
  // Initialize Round-Robin tracking for each slave
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
  
endfunction : build_phase

//--------------------------------------------------------------------------------------------
// Function: connect_phase
//--------------------------------------------------------------------------------------------
function void axi4_scoreboard_ooo::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase

//--------------------------------------------------------------------------------------------
// Function: get_slave_index
// Determines which slave should handle a given address
//--------------------------------------------------------------------------------------------
function int axi4_scoreboard_ooo::get_slave_index(logic[ADDR_WIDTH-1:0] addr);
  for(int i = 0; i < NO_OF_SLAVES; i++) begin
    if(addr >= SLAVE_START_ADDR[i] && addr <= SLAVE_END_ADDR[i]) begin
      return i;
    end
  end
  return -1;
endfunction : get_slave_index

//--------------------------------------------------------------------------------------------
// Function: check_write_rr_arbitration
// Verifies round-robin arbitration for write channel
//--------------------------------------------------------------------------------------------
function void axi4_scoreboard_ooo::check_write_rr_arbitration(int slave_id, int granted_master);
  int expected_master;
  int search_count;
  bit found_pending;
  
  rr_write_grants++;
  
  // Find the next master that has a pending request using round-robin order
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
  
  // If no pending requests found, no contention - skip check
  if(!found_pending) begin
    `uvm_info("RR_WRITE_NO_CONTENTION", 
              $sformatf("Slave[%0d]: No contention, granted to Master[%0d]", slave_id, granted_master), 
              UVM_HIGH)
    rr_write_last_granted[slave_id] = granted_master;
    return;
  end
  
  // Check if granted master matches expected master
  if(granted_master != expected_master) begin
    `uvm_error("RR_WRITE_VIOLATION",
              $sformatf("Slave[%0d] Write RR Arbitration Violation:\n" +
                       "  Expected Master: %0d\n" +
                       "  Granted Master : %0d\n" +
                       "  Next RR Index  : %0d\n" +
                       "  Pending Counts : M0=%0d M1=%0d M2=%0d M3=%0d",
                       slave_id, expected_master, granted_master, 
                       rr_write_next_master[slave_id],
                       rr_write_pending_cnt[slave_id][0],
                       rr_write_pending_cnt[slave_id][1],
                       rr_write_pending_cnt[slave_id][2],
                       rr_write_pending_cnt[slave_id][3]))
    rr_write_violations++;
  end else begin
    `uvm_info("RR_WRITE_PASS",
             $sformatf("Slave[%0d] Write RR Arbitration PASS: Master[%0d] granted as expected",
                      slave_id, granted_master),
             UVM_MEDIUM)
  end
  
  // Update round-robin pointer to next master after the granted one
  rr_write_next_master[slave_id] = (granted_master + 1) % NO_OF_MASTERS;
  rr_write_last_granted[slave_id] = granted_master;
  
  // Decrement the counter for granted master
  if(rr_write_pending_cnt[slave_id][granted_master] > 0) begin
    rr_write_pending_cnt[slave_id][granted_master]--;
  end else begin
    `uvm_error("RR_WRITE_CNT_ERROR", 
              $sformatf("Slave[%0d] Master[%0d] counter already 0!", slave_id, granted_master))
  end
  
endfunction : check_write_rr_arbitration

//--------------------------------------------------------------------------------------------
// Function: check_read_rr_arbitration
// Verifies round-robin arbitration for read channel
//--------------------------------------------------------------------------------------------
function void axi4_scoreboard_ooo::check_read_rr_arbitration(int slave_id, int granted_master);
  int expected_master;
  int search_count;
  bit found_pending;
  
  rr_read_grants++;
  
  // Find the next master that has a pending request using round-robin order
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
  
  // If no pending requests found, no contention - skip check
  if(!found_pending) begin
    `uvm_info("RR_READ_NO_CONTENTION", 
              $sformatf("Slave[%0d]: No contention, granted to Master[%0d]", slave_id, granted_master), 
              UVM_HIGH)
    rr_read_last_granted[slave_id] = granted_master;
    return;
  end
  
  // Check if granted master matches expected master
  if(granted_master != expected_master) begin
    `uvm_error("RR_READ_VIOLATION",
              $sformatf("Slave[%0d] Read RR Arbitration Violation:\n" +
                       "  Expected Master: %0d\n" +
                       "  Granted Master : %0d\n" +
                       "  Next RR Index  : %0d\n" +
                       "  Pending Counts : M0=%0d M1=%0d M2=%0d M3=%0d",
                       slave_id, expected_master, granted_master, 
                       rr_read_next_master[slave_id],
                       rr_read_pending_cnt[slave_id][0],
                       rr_read_pending_cnt[slave_id][1],
                       rr_read_pending_cnt[slave_id][2],
                       rr_read_pending_cnt[slave_id][3]))
    rr_read_violations++;
  end else begin
    `uvm_info("RR_READ_PASS",
             $sformatf("Slave[%0d] Read RR Arbitration PASS: Master[%0d] granted as expected",
                      slave_id, granted_master),
             UVM_MEDIUM)
  end
  
  // Update round-robin pointer to next master after the granted one
  rr_read_next_master[slave_id] = (granted_master + 1) % NO_OF_MASTERS;
  rr_read_last_granted[slave_id] = granted_master;
  
  // Decrement the counter for granted master
  if(rr_read_pending_cnt[slave_id][granted_master] > 0) begin
    rr_read_pending_cnt[slave_id][granted_master]--;
  end else begin
    `uvm_error("RR_READ_CNT_ERROR", 
              $sformatf("Slave[%0d] Master[%0d] counter already 0!", slave_id, granted_master))
  end
  
endfunction : check_read_rr_arbitration

//--------------------------------------------------------------------------------------------
// Function: find_matching_write_txn
// OUT-OF-ORDER: Find matching write transaction by comparing address and other attributes
// Returns index in queue, or -1 if not found
//--------------------------------------------------------------------------------------------
function int axi4_scoreboard_ooo::find_matching_write_txn(
  int s_idx, 
  bit[ID_WIDTH-1:0] id, 
  axi4_slave_tx s_tx
);
  int queue_size;
  
  if(!pending_write_txns[s_idx].exists(id)) return -1;
  
  queue_size = pending_write_txns[s_idx][id].size();
  
  // Search through all pending transactions with this ID
  for(int i = 0; i < queue_size; i++) begin
    pending_write_transaction_t ptx = pending_write_txns[s_idx][id][i];
    
    // Match by address and other key attributes
    if(ptx.tx.awaddr == s_tx.awaddr &&
       ptx.tx.awlen == s_tx.awlen &&
       ptx.tx.awsize == s_tx.awsize &&
       ptx.tx.awburst == s_tx.awburst &&
       !ptx.address_granted) begin  // Not yet granted
      return i;
    end
  end
  
  return -1;
endfunction : find_matching_write_txn

//--------------------------------------------------------------------------------------------
// Function: find_matching_read_txn
// OUT-OF-ORDER: Find matching read transaction by comparing address and other attributes
// Returns index in queue, or -1 if not found
//--------------------------------------------------------------------------------------------
function int axi4_scoreboard_ooo::find_matching_read_txn(
  int s_idx, 
  bit[ID_WIDTH-1:0] id, 
  axi4_master_tx m_tx
);
  int queue_size;
  
  if(!pending_read_txns[s_idx].exists(id)) return -1;
  
  queue_size = pending_read_txns[s_idx][id].size();
  
  // Search through all pending transactions with this ID
  for(int i = 0; i < queue_size; i++) begin
    pending_read_transaction_t ptx = pending_read_txns[s_idx][id][i];
    
    // Match by address and other key attributes
    if(ptx.tx.araddr == m_tx.araddr &&
       ptx.tx.arlen == m_tx.arlen &&
       ptx.tx.arsize == m_tx.arsize &&
       ptx.tx.arburst == m_tx.arburst &&
       ptx.address_granted &&
       !ptx.data_returned) begin  // Address granted but data not yet returned
      return i;
    end
  end
  
  return -1;
endfunction : find_matching_read_txn

//--------------------------------------------------------------------------------------------
// Function: ref_model_write
// Reference model for write operations - called after WLAST
//--------------------------------------------------------------------------------------------
function void axi4_scoreboard_ooo::ref_model_write(axi4_master_tx m_tx, int slave_idx, int master_idx);
  int bytes_per_beat;
  longint temp_addr;
  int align_amount;
  longint wrap_start_addr;
  longint wrap_end_addr;
  longint wrap_boundary;
  
  bytes_per_beat = 1 << m_tx.awsize;
  temp_addr = m_tx.awaddr;
  
  // Calculate wrap boundaries for WRAP burst
  wrap_boundary = bytes_per_beat * (m_tx.awlen + 1);
  wrap_start_addr = (temp_addr / wrap_boundary) * wrap_boundary;
  wrap_end_addr = wrap_start_addr + wrap_boundary;
  
  // Calculate alignment for first beat
  align_amount = temp_addr % bytes_per_beat;
  
  foreach(m_tx.wdata[beat]) begin
    int local_align = (beat == 0) ? align_amount : 0;
    
    case(m_tx.awburst)
      2'b00: begin // FIXED - address doesn't change
        for(int byte_idx = local_align; byte_idx < bytes_per_beat; byte_idx++) begin
          longint byte_addr = m_tx.awaddr + byte_idx;
          int lane = byte_addr % (DATA_WIDTH/8);
          
          if(m_tx.wstrb[beat][lane]) begin
            referenceData[slave_idx][byte_addr] = m_tx.wdata[beat][8*lane+7 -: 8];
            `uvm_info("REF_WRITE", 
                     $sformatf("FIXED: S[%0d] M[%0d] Addr=0x%0h Data=0x%02h Lane=%0d", 
                              slave_idx, master_idx, byte_addr, 
                              m_tx.wdata[beat][8*lane+7 -: 8], lane), 
                     UVM_HIGH)
          end
        end
      end
      
      2'b01: begin // INCR - address increments
        for(int byte_idx = local_align; byte_idx < bytes_per_beat; byte_idx++) begin
          int lane = temp_addr % (DATA_WIDTH/8);
          
          if(m_tx.wstrb[beat][lane]) begin
            referenceData[slave_idx][temp_addr] = m_tx.wdata[beat][8*lane+7 -: 8];
            `uvm_info("REF_WRITE", 
                     $sformatf("INCR: S[%0d] M[%0d] Addr=0x%0h Data=0x%02h Lane=%0d", 
                              slave_idx, master_idx, temp_addr, 
                              m_tx.wdata[beat][8*lane+7 -: 8], lane), 
                     UVM_HIGH)
          end
          temp_addr++;
        end
      end
      
      2'b10: begin // WRAP - address wraps at boundary
        for(int byte_idx = local_align; byte_idx < bytes_per_beat; byte_idx++) begin
          int lane = temp_addr % (DATA_WIDTH/8);
          
          if(m_tx.wstrb[beat][lane]) begin
            referenceData[slave_idx][temp_addr] = m_tx.wdata[beat][8*lane+7 -: 8];
            `uvm_info("REF_WRITE", 
                     $sformatf("WRAP: S[%0d] M[%0d] Addr=0x%0h Data=0x%02h Lane=%0d Boundary=[0x%0h:0x%0h]", 
                              slave_idx, master_idx, temp_addr, 
                              m_tx.wdata[beat][8*lane+7 -: 8], lane,
                              wrap_start_addr, wrap_end_addr-1), 
                     UVM_HIGH)
          end
          temp_addr++;
          if(temp_addr >= wrap_end_addr) begin
            temp_addr = wrap_start_addr;
          end
        end
      end
    endcase
  end
  
endfunction : ref_model_write

//--------------------------------------------------------------------------------------------
// Function: ref_model_read
// Reference model for read operations
//--------------------------------------------------------------------------------------------
function void axi4_scoreboard_ooo::ref_model_read(axi4_master_tx m_tx, int slave_idx);
  int bytes_per_beat;
  longint temp_addr;
  int align_amount;
  longint wrap_start_addr;
  longint wrap_end_addr;
  longint wrap_boundary;
  
  bytes_per_beat = 1 << m_tx.arsize;
  temp_addr = m_tx.araddr;
  
  // Calculate wrap boundaries
  wrap_boundary = bytes_per_beat * (m_tx.arlen + 1);
  wrap_start_addr = (temp_addr / wrap_boundary) * wrap_boundary;
  wrap_end_addr = wrap_start_addr + wrap_boundary;
  
  // Calculate alignment for first beat
  align_amount = temp_addr % bytes_per_beat;
  
  m_tx.rdata = new[m_tx.arlen + 1];
  
  foreach(m_tx.rdata[beat]) begin
    int local_align = (beat == 0) ? align_amount : 0;
    m_tx.rdata[beat] = '0;
    
    case(m_tx.arburst)
      2'b00: begin // FIXED
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
      
      2'b01: begin // INCR
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
      
      2'b10: begin // WRAP
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

//--------------------------------------------------------------------------------------------
// Task: run_phase
// Main comparison logic with OUT-OF-ORDER support
//--------------------------------------------------------------------------------------------
task axi4_scoreboard_ooo::run_phase(uvm_phase phase);
  super.run_phase(phase);
  
  //--------------------------------------------------------------------------------------------
  // WRITE ADDRESS PATH - Master Side
  // Monitor master write address requests and increment pending request counter
  //--------------------------------------------------------------------------------------------
  foreach(axi4_master_write_address_analysis_fifo[i]) begin
    automatic int m_idx = i;
    fork
      forever begin
        axi4_master_tx m_write_addr_tx;
        int s_idx;
        pending_write_transaction_t pending_tx;
        
        axi4_master_write_address_analysis_fifo[m_idx].get(m_write_addr_tx);
        axi4_master_tx_awaddr_count[m_idx]++;
        total_master_tx_count++;
        
        `uvm_info("MSTR_WR_ADDR", 
                 $sformatf("M[%0d] AWID=0x%0h AWADDR=0x%0h AWLEN=%0d AWSIZE=%0d AWBURST=%0d", 
                          m_idx, m_write_addr_tx.awid, m_write_addr_tx.awaddr, 
                          m_write_addr_tx.awlen, m_write_addr_tx.awsize, m_write_addr_tx.awburst), 
                 UVM_MEDIUM)
        
        // Determine target slave based on address
        s_idx = get_slave_index(m_write_addr_tx.awaddr);
        
        if(s_idx != -1) begin
          // Increment pending request counter
          rr_write_pending_cnt[s_idx][m_idx]++;
          
          // Track outstanding transactions by ID
          if(!write_outstanding_by_id[s_idx].exists(m_write_addr_tx.awid)) begin
            write_outstanding_by_id[s_idx][m_write_addr_tx.awid] = 0;
          end
          write_outstanding_by_id[s_idx][m_write_addr_tx.awid]++;
          
          `uvm_info("WR_PENDING_INC", 
                   $sformatf("M[%0d]->S[%0d] AWID=0x%0h pending counter: %0d, outstanding: %0d", 
                            m_idx, s_idx, m_write_addr_tx.awid,
                            rr_write_pending_cnt[s_idx][m_idx],
                            write_outstanding_by_id[s_idx][m_write_addr_tx.awid]), 
                   UVM_HIGH)
          
          // Create pending transaction
          $cast(pending_tx.tx, m_write_addr_tx.clone());
          pending_tx.master_id = m_idx;
          pending_tx.slave_id = s_idx;
          pending_tx.address_granted = 0;
          pending_tx.write_data_complete = 0;
          pending_tx.beats_received = 0;
          pending_tx.addr_grant_time = 0;
          
          // Store in queue - OUT-OF-ORDER: multiple transactions with same ID can be pending
          pending_write_txns[s_idx][m_write_addr_tx.awid].push_back(pending_tx);
          
          `uvm_info("WR_PENDING", 
                   $sformatf("M[%0d]->S[%0d] AWID=0x%0h added to pending queue (size=%0d)", 
                            m_idx, s_idx, m_write_addr_tx.awid, 
                            pending_write_txns[s_idx][m_write_addr_tx.awid].size()), 
                   UVM_HIGH)
        end else begin
          `uvm_error("ADDR_DECODE", 
                    $sformatf("M[%0d] AWADDR=0x%0h doesn't map to any slave", 
                             m_idx, m_write_addr_tx.awaddr))
        end
      end
    join_none
  end
  
  //--------------------------------------------------------------------------------------------
  // WRITE ADDRESS PATH - Slave Side
  // Monitor slave write address acceptance and check arbitration
  // OUT-OF-ORDER: Match by address, not just position in queue
  //--------------------------------------------------------------------------------------------
  foreach(axi4_slave_write_address_analysis_fifo[i]) begin
    automatic int s_idx = i;
    fork
      forever begin
        axi4_slave_tx s_write_addr_tx;
        pending_write_transaction_t pending_tx;
        int master_id;
        int match_idx;
        bit found;
        
        axi4_slave_write_address_analysis_fifo[s_idx].get(s_write_addr_tx);
        axi4_slave_tx_awaddr_count[s_idx]++;
        
        `uvm_info("SLV_WR_ADDR", 
                 $sformatf("S[%0d] AWID=0x%0h AWADDR=0x%0h AWLEN=%0d", 
                          s_idx, s_write_addr_tx.awid, s_write_addr_tx.awaddr, 
                          s_write_addr_tx.awlen), 
                 UVM_MEDIUM)
        
        // OUT-OF-ORDER: Find matching transaction by address
        match_idx = find_matching_write_txn(s_idx, s_write_addr_tx.awid, s_write_addr_tx);
        
        if(match_idx >= 0) begin
          pending_tx = pending_write_txns[s_idx][s_write_addr_tx.awid][match_idx];
          master_id = pending_tx.master_id;
          found = 1;
          
          // Check if this is out-of-order
          if(match_idx != 0) begin
            ooo_write_reorder_count++;
            `uvm_info("OOO_WRITE", 
                     $sformatf("S[%0d] AWID=0x%0h granted out-of-order (pos %0d in queue of %0d)", 
                              s_idx, s_write_addr_tx.awid, match_idx,
                              pending_write_txns[s_idx][s_write_addr_tx.awid].size()), 
                     UVM_MEDIUM)
          end
          
          // Check round-robin arbitration
          check_write_rr_arbitration(s_idx, master_id);
          
          // Compare write address
          axi4_write_address_comparison(pending_tx.tx, s_write_addr_tx, master_id, s_idx);
          
          // Mark address as granted
          pending_tx.address_granted = 1;
          pending_tx.addr_grant_time = $time;
          pending_write_txns[s_idx][s_write_addr_tx.awid][match_idx] = pending_tx;
          
          // Trigger event
          ->slave_write_addr_granted[s_idx];
          
          `uvm_info("WR_ADDR_GRANTED", 
                   $sformatf("S[%0d] M[%0d] AWID=0x%0h address granted (queue_pos=%0d)", 
                            s_idx, master_id, s_write_addr_tx.awid, match_idx), 
                   UVM_HIGH)
        end else begin
          `uvm_error("WR_ADDR_NO_MATCH", 
                    $sformatf("S[%0d] received AWID=0x%0h AWADDR=0x%0h but no matching pending transaction", 
                             s_idx, s_write_addr_tx.awid, s_write_addr_tx.awaddr))
        end
      end
    join_none
  end
  
  //--------------------------------------------------------------------------------------------
  // WRITE DATA PATH - Slave Side
  // OUT-OF-ORDER: Wait for any address grant, then match data to granted transaction
  //--------------------------------------------------------------------------------------------
  foreach(axi4_slave_write_data_analysis_fifo[i]) begin
    automatic int s_idx = i;
    fork
      forever begin
        axi4_slave_tx s_write_data_tx;
        pending_write_transaction_t pending_tx;
        bit found;
        bit [ID_WIDTH-1:0] matched_id;
        int matched_idx;
        
        axi4_slave_write_data_analysis_fifo[s_idx].get(s_write_data_tx);
        axi4_slave_tx_wdata_count[s_idx]++;
        
        `uvm_info("SLV_WR_DATA", 
                 $sformatf("S[%0d] WDATA[0]=0x%0h WSTRB=0x%0h WLAST=%0b", 
                          s_idx, s_write_data_tx.wdata[0], s_write_data_tx.wstrb[0], 
                          s_write_data_tx.wlast), 
                 UVM_HIGH)
        
        // Wait for at least one address grant
        @(slave_write_addr_granted[s_idx]);
        
        // OUT-OF-ORDER: Find ANY granted transaction that needs data
        // Search through all IDs
        found = 0;
        foreach(pending_write_txns[s_idx][id]) begin
          for(int j = 0; j < pending_write_txns[s_idx][id].size(); j++) begin
            if(pending_write_txns[s_idx][id][j].address_granted && 
               !pending_write_txns[s_idx][id][j].write_data_complete) begin
              pending_tx = pending_write_txns[s_idx][id][j];
              matched_id = id;
              matched_idx = j;
              
              // Compare write data
              axi4_write_data_comparison(pending_tx.tx, s_write_data_tx, 
                                        pending_tx.master_id, s_idx);
              
              pending_tx.beats_received++;
              
              // Check if this is the last beat
              if(s_write_data_tx.wlast) begin
                if(pending_tx.beats_received != (pending_tx.tx.awlen + 1)) begin
                  `uvm_error("WLAST_COUNT", 
                           $sformatf("S[%0d] M[%0d] WLAST at beat %0d but AWLEN=%0d", 
                                    s_idx, pending_tx.master_id, 
                                    pending_tx.beats_received, pending_tx.tx.awlen))
                end else begin
                  byte_data_cmp_verified_wlast_count++;
                end
                
                pending_tx.write_data_complete = 1;
                
                // Update reference model
                ref_model_write(pending_tx.tx, s_idx, pending_tx.master_id);
                
                `uvm_info("WR_DATA_COMPLETE", 
                         $sformatf("S[%0d] M[%0d] AWID=0x%0h write data complete", 
                                  s_idx, pending_tx.master_id, pending_tx.tx.awid), 
                         UVM_MEDIUM)
              end
              
              // Update the queue
              pending_write_txns[s_idx][matched_id][matched_idx] = pending_tx;
              found = 1;
              break;
            end
          end
          if(found) break;
        end
        
        if(!found) begin
          `uvm_error("WR_DATA_NO_MATCH", 
                    $sformatf("S[%0d] received write data but no granted pending transaction needs data", s_idx))
        end
      end
    join_none
  end
  
  //--------------------------------------------------------------------------------------------
  // WRITE RESPONSE PATH - Slave Side
  // OUT-OF-ORDER: Match response to completed transaction
  //--------------------------------------------------------------------------------------------
  foreach(axi4_slave_write_response_analysis_fifo[i]) begin
    automatic int s_idx = i;
    fork
      forever begin
        axi4_slave_tx s_write_resp_tx;
        pending_write_transaction_t pending_tx;
        bit found;
        int match_idx;
        
        axi4_slave_write_response_analysis_fifo[s_idx].get(s_write_resp_tx);
        axi4_slave_tx_bresp_count[s_idx]++;
        total_slave_tx_count++;
        
        `uvm_info("SLV_WR_RESP", 
                 $sformatf("S[%0d] BID=0x%0h BRESP=%0s", 
                          s_idx, s_write_resp_tx.bid, s_write_resp_tx.bresp.name()), 
                 UVM_MEDIUM)
        
        // OUT-OF-ORDER: Find the completed transaction with matching BID
        // Look for first transaction that has both address granted and data complete
        found = 0;
        match_idx = -1;
        
        if(pending_write_txns[s_idx].exists(s_write_resp_tx.bid)) begin
          for(int j = 0; j < pending_write_txns[s_idx][s_write_resp_tx.bid].size(); j++) begin
            if(pending_write_txns[s_idx][s_write_resp_tx.bid][j].address_granted &&
               pending_write_txns[s_idx][s_write_resp_tx.bid][j].write_data_complete) begin
              match_idx = j;
              break;
            end
          end
          
          if(match_idx >= 0) begin
            // Check for out-of-order completion
            if(match_idx != 0) begin
              `uvm_info("OOO_WRITE_RESP", 
                       $sformatf("S[%0d] BID=0x%0h response out-of-order (pos %0d)", 
                                s_idx, s_write_resp_tx.bid, match_idx), 
                       UVM_MEDIUM)
            end
            
            // Remove from queue (manual deletion at index)
            pending_tx = pending_write_txns[s_idx][s_write_resp_tx.bid][match_idx];
            pending_write_txns[s_idx][s_write_resp_tx.bid].delete(match_idx);
            
            // Decrement outstanding counter
            if(write_outstanding_by_id[s_idx].exists(s_write_resp_tx.bid)) begin
              write_outstanding_by_id[s_idx][s_write_resp_tx.bid]--;
            end
            
            // Verify transaction completion order
            if(!pending_tx.address_granted) begin
              `uvm_error("BRESP_BEFORE_AW", 
                        $sformatf("S[%0d] M[%0d] BID=0x%0h received before AW granted", 
                                 s_idx, pending_tx.master_id, s_write_resp_tx.bid))
            end
            
            if(!pending_tx.write_data_complete) begin
              `uvm_error("BRESP_BEFORE_WLAST", 
                        $sformatf("S[%0d] M[%0d] BID=0x%0h received before WLAST", 
                                 s_idx, pending_tx.master_id, s_write_resp_tx.bid))
            end
            
            // Compare write response
            axi4_write_response_comparison(pending_tx.tx, s_write_resp_tx, 
                                          pending_tx.master_id, s_idx);
            
            `uvm_info("WR_COMPLETE", 
                     $sformatf("S[%0d] M[%0d] BID=0x%0h write transaction complete (latency=%0t)", 
                              s_idx, pending_tx.master_id, s_write_resp_tx.bid,
                              $time - pending_tx.addr_grant_time), 
                     UVM_MEDIUM)
            found = 1;
          end
        end
        
        if(!found) begin
          `uvm_error("BRESP_NO_MATCH", 
                    $sformatf("S[%0d] received BID=0x%0h but no completed pending transaction", 
                             s_idx, s_write_resp_tx.bid))
        end
      end
    join_none
  end
  
  //--------------------------------------------------------------------------------------------
  // READ ADDRESS PATH - Master Side
  // Monitor master read address requests
  //--------------------------------------------------------------------------------------------
  foreach(axi4_master_read_address_analysis_fifo[i]) begin
    automatic int m_idx = i;
    fork
      forever begin
        axi4_master_tx m_read_addr_tx;
        int s_idx;
        pending_read_transaction_t pending_tx;
        
        axi4_master_read_address_analysis_fifo[m_idx].get(m_read_addr_tx);
        axi4_master_tx_araddr_count[m_idx]++;
        
        `uvm_info("MSTR_RD_ADDR", 
                 $sformatf("M[%0d] ARID=0x%0h ARADDR=0x%0h ARLEN=%0d ARSIZE=%0d ARBURST=%0d", 
                          m_idx, m_read_addr_tx.arid, m_read_addr_tx.araddr, 
                          m_read_addr_tx.arlen, m_read_addr_tx.arsize, m_read_addr_tx.arburst), 
                 UVM_MEDIUM)
        
        // Determine target slave
        s_idx = get_slave_index(m_read_addr_tx.araddr);
        
        if(s_idx != -1) begin
          // Increment pending request counter
          rr_read_pending_cnt[s_idx][m_idx]++;
          
          // Track outstanding transactions by ID
          if(!read_outstanding_by_id[s_idx].exists(m_read_addr_tx.arid)) begin
            read_outstanding_by_id[s_idx][m_read_addr_tx.arid] = 0;
          end
          read_outstanding_by_id[s_idx][m_read_addr_tx.arid]++;
          
          `uvm_info("RD_PENDING_INC", 
                   $sformatf("M[%0d]->S[%0d] ARID=0x%0h pending counter: %0d, outstanding: %0d", 
                            m_idx, s_idx, m_read_addr_tx.arid,
                            rr_read_pending_cnt[s_idx][m_idx],
                            read_outstanding_by_id[s_idx][m_read_addr_tx.arid]), 
                   UVM_HIGH)
          
          // Generate expected read data from reference model
          $cast(pending_tx.tx, m_read_addr_tx.clone());
          ref_model_read(pending_tx.tx, s_idx);
          
          pending_tx.master_id = m_idx;
          pending_tx.slave_id = s_idx;
          pending_tx.address_granted = 0;
          pending_tx.data_returned = 0;
          pending_tx.addr_grant_time = 0;
          
          // Store in queue - OUT-OF-ORDER: multiple transactions with same ID
          pending_read_txns[s_idx][m_read_addr_tx.arid].push_back(pending_tx);
          
          `uvm_info("RD_PENDING", 
                   $sformatf("M[%0d]->S[%0d] ARID=0x%0h added to pending queue (size=%0d)", 
                            m_idx, s_idx, m_read_addr_tx.arid, 
                            pending_read_txns[s_idx][m_read_addr_tx.arid].size()), 
                   UVM_HIGH)
        end else begin
          `uvm_error("ADDR_DECODE", 
                    $sformatf("M[%0d] ARADDR=0x%0h doesn't map to any slave", 
                             m_idx, m_read_addr_tx.araddr))
        end
      end
    join_none
  end
  
  //--------------------------------------------------------------------------------------------
  // READ ADDRESS PATH - Slave Side
  // OUT-OF-ORDER: Match by address
  //--------------------------------------------------------------------------------------------
  foreach(axi4_slave_read_address_analysis_fifo[i]) begin
    automatic int s_idx = i;
    fork
      forever begin
        axi4_slave_tx s_read_addr_tx;
        pending_read_transaction_t pending_tx;
        int master_id;
        int match_idx;
        bit found;
        
        axi4_slave_read_address_analysis_fifo[s_idx].get(s_read_addr_tx);
        axi4_slave_tx_araddr_count[s_idx]++;
        
        `uvm_info("SLV_RD_ADDR", 
                 $sformatf("S[%0d] ARID=0x%0h ARADDR=0x%0h ARLEN=%0d", 
                          s_idx, s_read_addr_tx.arid, s_read_addr_tx.araddr, 
                          s_read_addr_tx.arlen), 
                 UVM_MEDIUM)
        
        // OUT-OF-ORDER: Find matching transaction by address (similar to write path)
        found = 0;
        match_idx = -1;
        
        if(pending_read_txns[s_idx].exists(s_read_addr_tx.arid)) begin
          for(int j = 0; j < pending_read_txns[s_idx][s_read_addr_tx.arid].size(); j++) begin
            pending_read_transaction_t ptx = pending_read_txns[s_idx][s_read_addr_tx.arid][j];
            
            if(ptx.tx.araddr == s_read_addr_tx.araddr &&
               ptx.tx.arlen == s_read_addr_tx.arlen &&
               ptx.tx.arsize == s_read_addr_tx.arsize &&
               ptx.tx.arburst == s_read_addr_tx.arburst &&
               !ptx.address_granted) begin
              match_idx = j;
              break;
            end
          end
          
          if(match_idx >= 0) begin
            pending_tx = pending_read_txns[s_idx][s_read_addr_tx.arid][match_idx];
            master_id = pending_tx.master_id;
            found = 1;
            
            // Check if out-of-order
            if(match_idx != 0) begin
              ooo_read_reorder_count++;
              `uvm_info("OOO_READ", 
                       $sformatf("S[%0d] ARID=0x%0h granted out-of-order (pos %0d in queue of %0d)", 
                                s_idx, s_read_addr_tx.arid, match_idx,
                                pending_read_txns[s_idx][s_read_addr_tx.arid].size()), 
                       UVM_MEDIUM)
            end
            
            // Check round-robin arbitration
            check_read_rr_arbitration(s_idx, master_id);
            
            // Compare read address
            axi4_read_address_comparison(pending_tx.tx, s_read_addr_tx, master_id, s_idx);
            
            // Mark address as granted
            pending_tx.address_granted = 1;
            pending_tx.addr_grant_time = $time;
            pending_read_txns[s_idx][s_read_addr_tx.arid][match_idx] = pending_tx;
            
            // Trigger event
            ->slave_read_addr_granted[s_idx];
            
            `uvm_info("RD_ADDR_GRANTED", 
                     $sformatf("S[%0d] M[%0d] ARID=0x%0h address granted (queue_pos=%0d)", 
                              s_idx, master_id, s_read_addr_tx.arid, match_idx), 
                     UVM_HIGH)
          end
        end
        
        if(!found) begin
          `uvm_error("RD_ADDR_NO_MATCH", 
                    $sformatf("S[%0d] received ARID=0x%0h ARADDR=0x%0h but no matching pending transaction", 
                             s_idx, s_read_addr_tx.arid, s_read_addr_tx.araddr))
        end
      end
    join_none
  end
  
  //--------------------------------------------------------------------------------------------
  // READ DATA PATH - Slave Side (for counting)
  //--------------------------------------------------------------------------------------------
  foreach(axi4_slave_read_data_analysis_fifo[i]) begin
    automatic int s_idx = i;
    fork
      forever begin
        axi4_slave_tx s_read_data_tx;
        
        axi4_slave_read_data_analysis_fifo[s_idx].get(s_read_data_tx);
        axi4_slave_tx_rdata_count[s_idx]++;
        axi4_slave_tx_rresp_count[s_idx]++;
        
        `uvm_info("SLV_RD_DATA", 
                 $sformatf("S[%0d] RID=0x%0h RDATA[0]=0x%0h RLAST=%0b RRESP=%0s", 
                          s_idx, s_read_data_tx.rid, s_read_data_tx.rdata[0], 
                          s_read_data_tx.rlast, s_read_data_tx.rresp[0].name()), 
                 UVM_HIGH)
      end
    join_none
  end
  
  //--------------------------------------------------------------------------------------------
  // READ DATA PATH - Master Side
  // OUT-OF-ORDER: Match by address to find correct pending transaction
  //--------------------------------------------------------------------------------------------
  foreach(axi4_master_read_data_analysis_fifo[i]) begin
    automatic int m_idx = i;
    fork
      forever begin
        axi4_master_tx m_read_data_tx;
        pending_read_transaction_t pending_tx;
        int s_idx;
        int match_idx;
        bit found;
        
        axi4_master_read_data_analysis_fifo[m_idx].get(m_read_data_tx);
        axi4_master_tx_rdata_count[m_idx]++;
        axi4_master_tx_rresp_count[m_idx]++;
        
        `uvm_info("MSTR_RD_DATA", 
                 $sformatf("M[%0d] RID=0x%0h RDATA[0]=0x%0h RLAST=%0b RRESP=%0s", 
                          m_idx, m_read_data_tx.arid, m_read_data_tx.rdata[0], 
                          m_read_data_tx.rlast, m_read_data_tx.rresp[0].name()), 
                 UVM_MEDIUM)
        
        // Find the slave this read went to
        s_idx = get_slave_index(m_read_data_tx.araddr);
        
        if(s_idx != -1) begin
          // Wait for address grant
          @(slave_read_addr_granted[s_idx]);
          
          // OUT-OF-ORDER: Find matching transaction by address
          match_idx = find_matching_read_txn(s_idx, m_read_data_tx.arid, m_read_data_tx);
          
          if(match_idx >= 0) begin
            // Check for out-of-order completion
            if(match_idx != 0) begin
              `uvm_info("OOO_READ_DATA", 
                       $sformatf("S[%0d] RID=0x%0h data returned out-of-order (pos %0d)", 
                                s_idx, m_read_data_tx.arid, match_idx), 
                       UVM_MEDIUM)
            end
            
            pending_tx = pending_read_txns[s_idx][m_read_data_tx.arid][match_idx];
            
            // Verify this is from the correct master
            if(pending_tx.master_id != m_idx) begin
              `uvm_error("RD_MASTER_MISMATCH", 
                        $sformatf("S[%0d] RID=0x%0h expected from M[%0d] but received from M[%0d]", 
                                 s_idx, m_read_data_tx.arid, pending_tx.master_id, m_idx))
            end
            
            // Compare read data
            axi4_read_data_comparison(pending_tx.tx, m_read_data_tx, m_idx, s_idx);
            
            // Remove from queue
            pending_read_txns[s_idx][m_read_data_tx.arid].delete(match_idx);
            
            // Decrement outstanding counter
            if(read_outstanding_by_id[s_idx].exists(m_read_data_tx.arid)) begin
              read_outstanding_by_id[s_idx][m_read_data_tx.arid]--;
            end
            
            `uvm_info("RD_COMPLETE", 
                     $sformatf("S[%0d] M[%0d] RID=0x%0h read transaction complete (latency=%0t)", 
                              s_idx, m_idx, m_read_data_tx.arid,
                              $time - pending_tx.addr_grant_time), 
                     UVM_MEDIUM)
            found = 1;
          end else begin
            `uvm_error("RD_DATA_NO_MATCH", 
                      $sformatf("M[%0d] received RID=0x%0h ARADDR=0x%0h from S[%0d] but no matching granted transaction", 
                               m_idx, m_read_data_tx.arid, m_read_data_tx.araddr, s_idx))
          end
        end
      end
    join_none
  end
  
  wait fork;
  
endtask : run_phase

//--------------------------------------------------------------------------------------------
// Task: axi4_write_address_comparison
//--------------------------------------------------------------------------------------------
task axi4_scoreboard_ooo::axi4_write_address_comparison(
  input axi4_master_tx exp_tx,
  input axi4_slave_tx act_tx,
  input int master_id,
  input int slave_id
);
  
  `uvm_info("CMP_WR_ADDR", $sformatf("Comparing M[%0d]->S[%0d] write address", master_id, slave_id), UVM_HIGH)
  
  if(exp_tx.awid == act_tx.awid) begin
    byte_data_cmp_verified_awid_count++;
  end else begin
    `uvm_error("AWID_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] AWID: Exp=0x%0h Act=0x%0h", 
                       master_id, slave_id, exp_tx.awid, act_tx.awid))
    byte_data_cmp_failed_awid_count++;
  end
  
  if(exp_tx.awaddr == act_tx.awaddr) begin
    byte_data_cmp_verified_awaddr_count++;
  end else begin
    `uvm_error("AWADDR_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] AWADDR: Exp=0x%0h Act=0x%0h", 
                       master_id, slave_id, exp_tx.awaddr, act_tx.awaddr))
    byte_data_cmp_failed_awaddr_count++;
  end
  
  if(exp_tx.awlen == act_tx.awlen) begin
    byte_data_cmp_verified_awlen_count++;
  end else begin
    `uvm_error("AWLEN_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] AWLEN: Exp=%0d Act=%0d", 
                       master_id, slave_id, exp_tx.awlen, act_tx.awlen))
    byte_data_cmp_failed_awlen_count++;
  end
  
  if(exp_tx.awsize == act_tx.awsize) begin
    byte_data_cmp_verified_awsize_count++;
  end else begin
    `uvm_error("AWSIZE_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] AWSIZE: Exp=%0d Act=%0d", 
                       master_id, slave_id, exp_tx.awsize, act_tx.awsize))
    byte_data_cmp_failed_awsize_count++;
  end
  
  if(exp_tx.awburst == act_tx.awburst) begin
    byte_data_cmp_verified_awburst_count++;
  end else begin
    `uvm_error("AWBURST_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] AWBURST: Exp=%0d Act=%0d", 
                       master_id, slave_id, exp_tx.awburst, act_tx.awburst))
    byte_data_cmp_failed_awburst_count++;
  end
  
  if(exp_tx.awlock == act_tx.awlock) begin
    byte_data_cmp_verified_awlock_count++;
  end else begin
    `uvm_error("AWLOCK_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] AWLOCK: Exp=%0d Act=%0d", 
                       master_id, slave_id, exp_tx.awlock, act_tx.awlock))
    byte_data_cmp_failed_awlock_count++;
  end
  
  if(exp_tx.awcache == act_tx.awcache) begin
    byte_data_cmp_verified_awcache_count++;
  end else begin
    `uvm_error("AWCACHE_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] AWCACHE: Exp=0x%0h Act=0x%0h", 
                       master_id, slave_id, exp_tx.awcache, act_tx.awcache))
    byte_data_cmp_failed_awcache_count++;
  end
  
  if(exp_tx.awprot == act_tx.awprot) begin
    byte_data_cmp_verified_awprot_count++;
  end else begin
    `uvm_error("AWPROT_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] AWPROT: Exp=0x%0h Act=0x%0h", 
                       master_id, slave_id, exp_tx.awprot, act_tx.awprot))
    byte_data_cmp_failed_awprot_count++;
  end
  
endtask : axi4_write_address_comparison

//--------------------------------------------------------------------------------------------
// Task: axi4_write_data_comparison
//--------------------------------------------------------------------------------------------
task axi4_scoreboard_ooo::axi4_write_data_comparison(
  input axi4_master_tx exp_tx,
  input axi4_slave_tx act_tx,
  input int master_id,
  input int slave_id
);
  
  if(exp_tx.wdata.size() > 0 && act_tx.wdata.size() > 0) begin
    if(exp_tx.wdata[0] == act_tx.wdata[0]) begin
      byte_data_cmp_verified_wdata_count++;
    end else begin
      `uvm_error("WDATA_MISMATCH", 
                $sformatf("M[%0d]->S[%0d] WDATA: Exp=0x%0h Act=0x%0h", 
                         master_id, slave_id, exp_tx.wdata[0], act_tx.wdata[0]))
      byte_data_cmp_failed_wdata_count++;
    end
    
    if(exp_tx.wstrb[0] == act_tx.wstrb[0]) begin
      byte_data_cmp_verified_wstrb_count++;
    end else begin
      `uvm_error("WSTRB_MISMATCH", 
                $sformatf("M[%0d]->S[%0d] WSTRB: Exp=0x%0h Act=0x%0h", 
                         master_id, slave_id, exp_tx.wstrb[0], act_tx.wstrb[0]))
      byte_data_cmp_failed_wstrb_count++;
    end
  end
  
endtask : axi4_write_data_comparison

//--------------------------------------------------------------------------------------------
// Task: axi4_write_response_comparison
//--------------------------------------------------------------------------------------------
task axi4_scoreboard_ooo::axi4_write_response_comparison(
  input axi4_master_tx exp_tx,
  input axi4_slave_tx act_tx,
  input int master_id,
  input int slave_id
);
  
  `uvm_info("CMP_WR_RESP", $sformatf("Comparing M[%0d]->S[%0d] write response", master_id, slave_id), UVM_HIGH)
  
  if(exp_tx.awid == act_tx.bid) begin
    byte_data_cmp_verified_bid_count++;
  end else begin
    `uvm_error("BID_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] BID: Exp=0x%0h Act=0x%0h", 
                       master_id, slave_id, exp_tx.awid, act_tx.bid))
    byte_data_cmp_failed_bid_count++;
  end
  
  // BRESP - we accept slave's response but log it
  byte_data_cmp_verified_bresp_count++;
  `uvm_info("BRESP", $sformatf("M[%0d]->S[%0d] BRESP=%0s", master_id, slave_id, act_tx.bresp.name()), UVM_HIGH)
  
endtask : axi4_write_response_comparison

//--------------------------------------------------------------------------------------------
// Task: axi4_read_address_comparison
//--------------------------------------------------------------------------------------------
task axi4_scoreboard_ooo::axi4_read_address_comparison(
  input axi4_master_tx exp_tx,
  input axi4_slave_tx act_tx,
  input int master_id,
  input int slave_id
);
  
  `uvm_info("CMP_RD_ADDR", $sformatf("Comparing M[%0d]->S[%0d] read address", master_id, slave_id), UVM_HIGH)
  
  if(exp_tx.arid == act_tx.arid) begin
    byte_data_cmp_verified_arid_count++;
  end else begin
    `uvm_error("ARID_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] ARID: Exp=0x%0h Act=0x%0h", 
                       master_id, slave_id, exp_tx.arid, act_tx.arid))
    byte_data_cmp_failed_arid_count++;
  end
  
  if(exp_tx.araddr == act_tx.araddr) begin
    byte_data_cmp_verified_araddr_count++;
  end else begin
    `uvm_error("ARADDR_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] ARADDR: Exp=0x%0h Act=0x%0h", 
                       master_id, slave_id, exp_tx.araddr, act_tx.araddr))
    byte_data_cmp_failed_araddr_count++;
  end
  
  if(exp_tx.arlen == act_tx.arlen) begin
    byte_data_cmp_verified_arlen_count++;
  end else begin
    `uvm_error("ARLEN_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] ARLEN: Exp=%0d Act=%0d", 
                       master_id, slave_id, exp_tx.arlen, act_tx.arlen))
    byte_data_cmp_failed_arlen_count++;
  end
  
  if(exp_tx.arsize == act_tx.arsize) begin
    byte_data_cmp_verified_arsize_count++;
  end else begin
    `uvm_error("ARSIZE_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] ARSIZE: Exp=%0d Act=%0d", 
                       master_id, slave_id, exp_tx.arsize, act_tx.arsize))
    byte_data_cmp_failed_arsize_count++;
  end
  
  if(exp_tx.arburst == act_tx.arburst) begin
    byte_data_cmp_verified_arburst_count++;
  end else begin
    `uvm_error("ARBURST_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] ARBURST: Exp=%0d Act=%0d", 
                       master_id, slave_id, exp_tx.arburst, act_tx.arburst))
    byte_data_cmp_failed_arburst_count++;
  end
  
  if(exp_tx.arlock == act_tx.arlock) begin
    byte_data_cmp_verified_arlock_count++;
  end else begin
    `uvm_error("ARLOCK_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] ARLOCK: Exp=%0d Act=%0d", 
                       master_id, slave_id, exp_tx.arlock, act_tx.arlock))
    byte_data_cmp_failed_arlock_count++;
  end
  
  if(exp_tx.arcache == act_tx.arcache) begin
    byte_data_cmp_verified_arcache_count++;
  end else begin
    `uvm_error("ARCACHE_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] ARCACHE: Exp=0x%0h Act=0x%0h", 
                       master_id, slave_id, exp_tx.arcache, act_tx.arcache))
    byte_data_cmp_failed_arcache_count++;
  end
  
  if(exp_tx.arprot == act_tx.arprot) begin
    byte_data_cmp_verified_arprot_count++;
  end else begin
    `uvm_error("ARPROT_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] ARPROT: Exp=0x%0h Act=0x%0h", 
                       master_id, slave_id, exp_tx.arprot, act_tx.arprot))
    byte_data_cmp_failed_arprot_count++;
  end
  
  if(exp_tx.arregion == act_tx.arregion) begin
    byte_data_cmp_verified_arregion_count++;
  end else begin
    `uvm_error("ARREGION_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] ARREGION: Exp=0x%0h Act=0x%0h", 
                       master_id, slave_id, exp_tx.arregion, act_tx.arregion))
    byte_data_cmp_failed_arregion_count++;
  end
  
  if(exp_tx.arqos == act_tx.arqos) begin
    byte_data_cmp_verified_arqos_count++;
  end else begin
    `uvm_error("ARQOS_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] ARQOS: Exp=0x%0h Act=0x%0h", 
                       master_id, slave_id, exp_tx.arqos, act_tx.arqos))
    byte_data_cmp_failed_arqos_count++;
  end
  
endtask : axi4_read_address_comparison

//--------------------------------------------------------------------------------------------
// Task: axi4_read_data_comparison
//--------------------------------------------------------------------------------------------
task axi4_scoreboard_ooo::axi4_read_data_comparison(
  input axi4_master_tx exp_tx,
  input axi4_master_tx act_tx,
  input int master_id,
  input int slave_id
);
  
  `uvm_info("CMP_RD_DATA", $sformatf("Comparing M[%0d]->S[%0d] read data", master_id, slave_id), UVM_HIGH)
  
  // Verify RID
  if(exp_tx.arid == act_tx.arid) begin
    byte_data_cmp_verified_rid_count++;
  end else begin
    `uvm_error("RID_MISMATCH", 
              $sformatf("M[%0d]->S[%0d] RID: Exp=0x%0h Act=0x%0h", 
                       master_id, slave_id, exp_tx.arid, act_tx.arid))
    byte_data_cmp_failed_rid_count++;
  end
  
  // Compare each beat of read data
  if(exp_tx.rdata.size() != act_tx.rdata.size()) begin
    `uvm_error("RDATA_SIZE", 
              $sformatf("M[%0d]->S[%0d] RDATA size mismatch: Exp=%0d Act=%0d", 
                       master_id, slave_id, exp_tx.rdata.size(), act_tx.rdata.size()))
    byte_data_cmp_failed_rdata_count += exp_tx.rdata.size();
  end else begin
    foreach(exp_tx.rdata[beat]) begin
      if(exp_tx.rdata[beat] === act_tx.rdata[beat]) begin
        byte_data_cmp_verified_rdata_count++;
        `uvm_info("RDATA_MATCH", 
                 $sformatf("M[%0d]->S[%0d] Beat[%0d] RDATA=0x%0h", 
                          master_id, slave_id, beat, act_tx.rdata[beat]), 
                 UVM_HIGH)
      end else begin
        `uvm_error("RDATA_MISMATCH", 
                  $sformatf("M[%0d]->S[%0d] Beat[%0d] RDATA: Exp=0x%0h Act=0x%0h", 
                           master_id, slave_id, beat, exp_tx.rdata[beat], act_tx.rdata[beat]))
        byte_data_cmp_failed_rdata_count++;
      end
    end
  end
  
  // Verify RLAST
  if(act_tx.rlast) begin
    byte_data_cmp_verified_rlast_count++;
  end else begin
    `uvm_error("RLAST_ERROR", 
              $sformatf("M[%0d]->S[%0d] RLAST not set on last beat", master_id, slave_id))
    byte_data_cmp_failed_rlast_count++;
  end
  
  // RRESP
  byte_data_cmp_verified_rresp_count += act_tx.rresp.size();
  
endtask : axi4_read_data_comparison

//--------------------------------------------------------------------------------------------
// Function: check_phase
//--------------------------------------------------------------------------------------------
function void axi4_scoreboard_ooo::check_phase(uvm_phase phase);
  super.check_phase(phase);
  
  `uvm_info(get_type_name(), "========== SCOREBOARD CHECK PHASE (OUT-OF-ORDER) ==========", UVM_LOW)
  
  // Check for pending transactions
  foreach(pending_write_txns[s]) begin
    foreach(pending_write_txns[s][id]) begin
      if(pending_write_txns[s][id].size() > 0) begin
        `uvm_error("PENDING_WRITE", 
                  $sformatf("S[%0d] has %0d pending write transactions with ID=0x%0h", 
                           s, pending_write_txns[s][id].size(), id))
      end
    end
  end
  
  foreach(pending_read_txns[s]) begin
    foreach(pending_read_txns[s][id]) begin
      if(pending_read_txns[s][id].size() > 0) begin
        `uvm_error("PENDING_READ", 
                  $sformatf("S[%0d] has %0d pending read transactions with ID=0x%0h", 
                           s, pending_read_txns[s][id].size(), id))
      end
    end
  end
  
  // Check for leftover pending counters
  for(int s = 0; s < NO_OF_SLAVES; s++) begin
    for(int m = 0; m < NO_OF_MASTERS; m++) begin
      if(rr_write_pending_cnt[s][m] != 0) begin
        `uvm_error("PENDING_WR_CNT", 
                  $sformatf("S[%0d] M[%0d] write pending counter is %0d (should be 0)", 
                           s, m, rr_write_pending_cnt[s][m]))
      end
      if(rr_read_pending_cnt[s][m] != 0) begin
        `uvm_error("PENDING_RD_CNT", 
                  $sformatf("S[%0d] M[%0d] read pending counter is %0d (should be 0)", 
                           s, m, rr_read_pending_cnt[s][m]))
      end
    end
  end
  
  // Check outstanding by ID counters
  foreach(write_outstanding_by_id[s]) begin
    foreach(write_outstanding_by_id[s][id]) begin
      if(write_outstanding_by_id[s][id] != 0) begin
        `uvm_error("OUTSTANDING_WR", 
                  $sformatf("S[%0d] AWID=0x%0h has %0d outstanding transactions", 
                           s, id, write_outstanding_by_id[s][id]))
      end
    end
  end
  
  foreach(read_outstanding_by_id[s]) begin
    foreach(read_outstanding_by_id[s][id]) begin
      if(read_outstanding_by_id[s][id] != 0) begin
        `uvm_error("OUTSTANDING_RD", 
                  $sformatf("S[%0d] ARID=0x%0h has %0d outstanding transactions", 
                           s, id, read_outstanding_by_id[s][id]))
      end
    end
  end
  
  // Check results
  if((byte_data_cmp_verified_awid_count > 0) && (byte_data_cmp_failed_awid_count == 0)) begin
    `uvm_info(get_type_name(), $sformatf(" AWID comparisons: %0d passed", byte_data_cmp_verified_awid_count), UVM_LOW)
  end else if(byte_data_cmp_failed_awid_count > 0) begin
    `uvm_error("CHECK", $sformatf(" AWID: Verified=%0d Failed=%0d", 
              byte_data_cmp_verified_awid_count, byte_data_cmp_failed_awid_count))
  end
  
  if((byte_data_cmp_verified_awaddr_count > 0) && (byte_data_cmp_failed_awaddr_count == 0)) begin
    `uvm_info(get_type_name(), $sformatf(" AWADDR comparisons: %0d passed", byte_data_cmp_verified_awaddr_count), UVM_LOW)
  end else if(byte_data_cmp_failed_awaddr_count > 0) begin
    `uvm_error("CHECK", $sformatf(" AWADDR: Verified=%0d Failed=%0d", 
              byte_data_cmp_verified_awaddr_count, byte_data_cmp_failed_awaddr_count))
  end
  
  if((byte_data_cmp_verified_rdata_count > 0) && (byte_data_cmp_failed_rdata_count == 0)) begin
    `uvm_info(get_type_name(), $sformatf(" RDATA comparisons: %0d passed", byte_data_cmp_verified_rdata_count), UVM_LOW)
  end else if(byte_data_cmp_failed_rdata_count > 0) begin
    `uvm_error("CHECK", $sformatf(" RDATA: Verified=%0d Failed=%0d", 
              byte_data_cmp_verified_rdata_count, byte_data_cmp_failed_rdata_count))
  end
endfunction : check_phase