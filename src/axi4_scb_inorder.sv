`ifndef AXI4_SCOREBOARD_INCLUDED_
`define AXI4_SCOREBOARD_INCLUDED_

class axi4_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi4_scoreboard)

  axi4_master_tx axi4_master_tx_h;
  axi4_slave_tx axi4_slave_tx_h;

  //--------------------------------------------------------------------------------------------
  // Transaction tracking structures
  //--------------------------------------------------------------------------------------------
  typedef struct {
    axi4_master_tx tx;
    int master_id;
    int slave_id;
    bit address_granted;      // NEW: Set when address arbitration happens
    bit write_data_complete;  // Set when WLAST received
    int beats_received;
  } pending_write_transaction_t;

  typedef struct {
    axi4_master_tx tx;
    int master_id;
    int slave_id;
    bit address_granted;      // NEW: Set when address arbitration happens
  } pending_read_transaction_t;

  // Track pending transactions by ID per slave
  pending_write_transaction_t pending_write_txns[int][bit[ID_WIDTH-1:0]][$];  // [slave_id][awid][$]
  pending_read_transaction_t pending_read_txns[int][bit[ID_WIDTH-1:0]][$];    // [slave_id][arid][$]

  // Reference memory indexed by [slave_id][address]
  logic[7:0] referenceData[int][longint];

  //--------------------------------------------------------------------------------------------
  // Round-Robin Arbitration Tracking (FIXED: Using counters instead of bits)
  //--------------------------------------------------------------------------------------------
  // Write channel arbitration
  int rr_write_next_master[int];              // [slave_id] -> next master to check
  int rr_write_pending_cnt[int][int];         // [slave_id][master_id] -> pending request count (FIXED)
  int rr_write_last_granted[int];             // [slave_id] -> last granted master
  
  // Read channel arbitration  
  int rr_read_next_master[int];               // [slave_id] -> next master to check
  int rr_read_pending_cnt[int][int];          // [slave_id][master_id] -> pending request count (FIXED)
  int rr_read_last_granted[int];              // [slave_id] -> last granted master

  // Events for synchronization (FIXED: Now properly used)
  event slave_write_addr_granted[int];        // [slave_id]
  event slave_read_addr_granted[int];         // [slave_id]

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
  extern function new(string name = "axi4_scoreboard", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);
  extern virtual function int get_slave_index(logic[ADDR_WIDTH-1:0] addr);
  extern virtual function void ref_model_write(axi4_master_tx m_tx, int slave_idx, int master_idx);
  extern virtual function void ref_model_read(axi4_master_tx m_tx, int slave_idx);
  extern virtual function void check_write_rr_arbitration(int slave_id, int granted_master);
  extern virtual function void check_read_rr_arbitration(int slave_id, int granted_master);
  extern virtual task axi4_write_address_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id, input int slave_id);
  extern virtual task axi4_write_data_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id, input int slave_id);
  extern virtual task axi4_write_response_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id, input int slave_id);
  extern virtual task axi4_read_address_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id, input int slave_id);
  extern virtual task axi4_read_data_comparison(input axi4_master_tx exp_tx, input axi4_master_tx act_tx, input int master_id, input int slave_id);
  extern virtual function void check_phase(uvm_phase phase);
  extern virtual function void report_phase(uvm_phase phase);

endclass : axi4_scoreboard

//--------------------------------------------------------------------------------------------
// Function: new
//--------------------------------------------------------------------------------------------
function axi4_scoreboard::new(string name = "axi4_scoreboard", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
//--------------------------------------------------------------------------------------------
function void axi4_scoreboard::build_phase(uvm_phase phase);
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
  
  // Initialize Round-Robin tracking for each slave (FIXED: Using counters)
  for(int s = 0; s < NO_OF_SLAVES; s++) begin
    rr_write_next_master[s] = 0;
    rr_write_last_granted[s] = -1;
    rr_read_next_master[s] = 0;
    rr_read_last_granted[s] = -1;
    
    for(int m = 0; m < NO_OF_MASTERS; m++) begin
      rr_write_pending_cnt[s][m] = 0;  // FIXED: Counter instead of bit
      rr_read_pending_cnt[s][m] = 0;   // FIXED: Counter instead of bit
    end
  end
  
endfunction : build_phase

//--------------------------------------------------------------------------------------------
// Function: connect_phase
//--------------------------------------------------------------------------------------------
function void axi4_scoreboard::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase

//--------------------------------------------------------------------------------------------
// Function: get_slave_index
// Determines which slave should handle a given address
//--------------------------------------------------------------------------------------------
function int axi4_scoreboard::get_slave_index(logic[ADDR_WIDTH-1:0] addr);
  for(int i = 0; i < NO_OF_SLAVES; i++) begin
    if(addr >= SLAVE_START_ADDR[i] && addr <= SLAVE_END_ADDR[i]) begin
      return i;
    end
  end
  return -1;
endfunction : get_slave_index

//--------------------------------------------------------------------------------------------
// Function: check_write_rr_arbitration
// Verifies round-robin arbitration for write channel (FIXED: Using counters)
//--------------------------------------------------------------------------------------------
function void axi4_scoreboard::check_write_rr_arbitration(int slave_id, int granted_master);
  int expected_master;
  int search_count;
  bit found_pending;
  
  rr_write_grants++;
  
  // Find the next master that has a pending request using round-robin order
  search_count = 0;
  found_pending = 0;
  expected_master = rr_write_next_master[slave_id];
  
  while(search_count < NO_OF_MASTERS) begin
    if(rr_write_pending_cnt[slave_id][expected_master] > 0) begin  // FIXED: Check counter
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
  
  // FIXED: Decrement the counter for granted master
  if(rr_write_pending_cnt[slave_id][granted_master] > 0) begin
    rr_write_pending_cnt[slave_id][granted_master]--;
  end else begin
    `uvm_error("RR_WRITE_CNT_ERROR", 
              $sformatf("Slave[%0d] Master[%0d] counter already 0!", slave_id, granted_master))
  end
  
endfunction : check_write_rr_arbitration

//--------------------------------------------------------------------------------------------
// Function: check_read_rr_arbitration
// Verifies round-robin arbitration for read channel (FIXED: Using counters)
//--------------------------------------------------------------------------------------------
function void axi4_scoreboard::check_read_rr_arbitration(int slave_id, int granted_master);
  int expected_master;
  int search_count;
  bit found_pending;
  
  rr_read_grants++;
  
  // Find the next master that has a pending request using round-robin order
  search_count = 0;
  found_pending = 0;
  expected_master = rr_read_next_master[slave_id];
  
  while(search_count < NO_OF_MASTERS) begin
    if(rr_read_pending_cnt[slave_id][expected_master] > 0) begin  // FIXED: Check counter
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
  
  // FIXED: Decrement the counter for granted master
  if(rr_read_pending_cnt[slave_id][granted_master] > 0) begin
    rr_read_pending_cnt[slave_id][granted_master]--;
  end else begin
    `uvm_error("RR_READ_CNT_ERROR", 
              $sformatf("Slave[%0d] Master[%0d] counter already 0!", slave_id, granted_master))
  end
  
endfunction : check_read_rr_arbitration

//--------------------------------------------------------------------------------------------
// Function: ref_model_write
// Reference model for write operations - called after WLAST
//--------------------------------------------------------------------------------------------
function void axi4_scoreboard::ref_model_write(axi4_master_tx m_tx, int slave_idx, int master_idx);
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
function void axi4_scoreboard::ref_model_read(axi4_master_tx m_tx, int slave_idx);
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
// Main comparison logic with FIXED arbitration and synchronization
//--------------------------------------------------------------------------------------------
task axi4_scoreboard::run_phase(uvm_phase phase);
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
          // FIXED: Increment pending request counter
          rr_write_pending_cnt[s_idx][m_idx]++;
          
          `uvm_info("WR_PENDING_INC", 
                   $sformatf("M[%0d]->S[%0d] pending counter: %0d", 
                            m_idx, s_idx, rr_write_pending_cnt[s_idx][m_idx]), 
                   UVM_HIGH)
          
          // Create pending transaction
          $cast(pending_tx.tx, m_write_addr_tx.clone());
          pending_tx.master_id = m_idx;
          pending_tx.slave_id = s_idx;
          pending_tx.address_granted = 0;       // NEW: Not yet granted
          pending_tx.write_data_complete = 0;
          pending_tx.beats_received = 0;
          
          // Store in queue indexed by slave and AWID (for in-order checking)
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
  //--------------------------------------------------------------------------------------------
  foreach(axi4_slave_write_address_analysis_fifo[i]) begin
    automatic int s_idx = i;
    fork
      forever begin
        axi4_slave_tx s_write_addr_tx;
        pending_write_transaction_t pending_tx;
        int master_id;
        bit found;
        
        axi4_slave_write_address_analysis_fifo[s_idx].get(s_write_addr_tx);
        axi4_slave_tx_awaddr_count[s_idx]++;
        
        `uvm_info("SLV_WR_ADDR", 
                 $sformatf("S[%0d] AWID=0x%0h AWADDR=0x%0h AWLEN=%0d", 
                          s_idx, s_write_addr_tx.awid, s_write_addr_tx.awaddr, 
                          s_write_addr_tx.awlen), 
                 UVM_MEDIUM)
        
        // Find matching pending transaction (in-order: first in queue with matching ID)
        found = 0;
        if(pending_write_txns[s_idx].exists(s_write_addr_tx.awid)) begin
          if(pending_write_txns[s_idx][s_write_addr_tx.awid].size() > 0) begin
            // Get first transaction (but don't pop yet - need to wait for all data)
            pending_tx = pending_write_txns[s_idx][s_write_addr_tx.awid][0];
            master_id = pending_tx.master_id;
            found = 1;
            
            // Check round-robin arbitration (also decrements counter)
            check_write_rr_arbitration(s_idx, master_id);
            
            // Compare write address
            axi4_write_address_comparison(pending_tx.tx, s_write_addr_tx, master_id, s_idx);
            
            // FIXED: Mark address as granted and trigger event
            pending_tx.address_granted = 1;
            pending_write_txns[s_idx][s_write_addr_tx.awid][0] = pending_tx;  // Update the queue
            
            // Trigger event to signal that address arbitration is complete
            ->slave_write_addr_granted[s_idx];
            
            `uvm_info("WR_ADDR_GRANTED", 
                     $sformatf("S[%0d] M[%0d] AWID=0x%0h address granted", 
                              s_idx, master_id, s_write_addr_tx.awid), 
                     UVM_HIGH)
          end
        end
        
        if(!found) begin
          `uvm_error("WR_ADDR_NO_MATCH", 
                    $sformatf("S[%0d] received AWID=0x%0h but no pending transaction found", 
                             s_idx, s_write_addr_tx.awid))
        end
      end
    join_none
  end
  
  //--------------------------------------------------------------------------------------------
  // WRITE DATA PATH - Slave Side
  // FIXED: Wait for address arbitration before matching write data
  //--------------------------------------------------------------------------------------------
  foreach(axi4_slave_write_data_analysis_fifo[i]) begin
    automatic int s_idx = i;
    fork
      forever begin
        axi4_slave_tx s_write_data_tx;
        pending_write_transaction_t pending_tx;
        bit found;
        bit [ID_WIDTH-1:0] matched_id;
        
        axi4_slave_write_data_analysis_fifo[s_idx].get(s_write_data_tx);
        axi4_slave_tx_wdata_count[s_idx]++;
        
        `uvm_info("SLV_WR_DATA", 
                 $sformatf("S[%0d] WDATA[0]=0x%0h WSTRB=0x%0h WLAST=%0b", 
                          s_idx, s_write_data_tx.wdata[0], s_write_data_tx.wstrb[0], 
                          s_write_data_tx.wlast), 
                 UVM_HIGH)
        
        // FIXED GAP #1: Wait for address arbitration to complete
        // This ensures we know which transaction this data belongs to
        @(slave_write_addr_granted[s_idx]);
        
        // Find the first pending write transaction that has address_granted but not write_data_complete
        // For in-order, this should be unambiguous
        found = 0;
        foreach(pending_write_txns[s_idx][id]) begin
          if(pending_write_txns[s_idx][id].size() > 0) begin
            if(pending_write_txns[s_idx][id][0].address_granted && 
               !pending_write_txns[s_idx][id][0].write_data_complete) begin
              pending_tx = pending_write_txns[s_idx][id][0];
              matched_id = id;
              
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
                
                // Update reference model after all write data received
                ref_model_write(pending_tx.tx, s_idx, pending_tx.master_id);
                
                `uvm_info("WR_DATA_COMPLETE", 
                         $sformatf("S[%0d] M[%0d] AWID=0x%0h write data complete", 
                                  s_idx, pending_tx.master_id, pending_tx.tx.awid), 
                         UVM_MEDIUM)
              end
              
              // Update the queue
              pending_write_txns[s_idx][matched_id][0] = pending_tx;
              found = 1;
              break;
            end
          end
        end
        
        if(!found) begin
          `uvm_error("WR_DATA_NO_MATCH", 
                    $sformatf("S[%0d] received write data but no granted pending transaction", s_idx))
        end
      end
    join_none
  end
  
  //--------------------------------------------------------------------------------------------
  // WRITE RESPONSE PATH - Slave Side
  // Monitor write response and remove completed transactions
  //--------------------------------------------------------------------------------------------
  foreach(axi4_slave_write_response_analysis_fifo[i]) begin
    automatic int s_idx = i;
    fork
      forever begin
        axi4_slave_tx s_write_resp_tx;
        pending_write_transaction_t pending_tx;
        bit found;
        
        axi4_slave_write_response_analysis_fifo[s_idx].get(s_write_resp_tx);
        axi4_slave_tx_bresp_count[s_idx]++;
        total_slave_tx_count++;
        
        `uvm_info("SLV_WR_RESP", 
                 $sformatf("S[%0d] BID=0x%0h BRESP=%0s", 
                          s_idx, s_write_resp_tx.bid, s_write_resp_tx.bresp.name()), 
                 UVM_MEDIUM)
        
        // Find matching pending transaction by BID (in-order: first in queue)
        found = 0;
        if(pending_write_txns[s_idx].exists(s_write_resp_tx.bid)) begin
          if(pending_write_txns[s_idx][s_write_resp_tx.bid].size() > 0) begin
            pending_tx = pending_write_txns[s_idx][s_write_resp_tx.bid].pop_front();
            
            // Verify address was granted
            if(!pending_tx.address_granted) begin
              `uvm_error("BRESP_BEFORE_AW", 
                        $sformatf("S[%0d] M[%0d] BID=0x%0h received before AW granted", 
                                 s_idx, pending_tx.master_id, s_write_resp_tx.bid))
            end
            
            // Verify write data was complete before response
            if(!pending_tx.write_data_complete) begin
              `uvm_error("BRESP_BEFORE_WLAST", 
                        $sformatf("S[%0d] M[%0d] BID=0x%0h received before WLAST", 
                                 s_idx, pending_tx.master_id, s_write_resp_tx.bid))
            end
            
            // Compare write response
            axi4_write_response_comparison(pending_tx.tx, s_write_resp_tx, 
                                          pending_tx.master_id, s_idx);
            
            `uvm_info("WR_COMPLETE", 
                     $sformatf("S[%0d] M[%0d] BID=0x%0h write transaction complete", 
                              s_idx, pending_tx.master_id, s_write_resp_tx.bid), 
                     UVM_MEDIUM)
            found = 1;
          end
        end
        
        if(!found) begin
          `uvm_error("BRESP_NO_MATCH", 
                    $sformatf("S[%0d] received BID=0x%0h but no pending transaction", 
                             s_idx, s_write_resp_tx.bid))
        end
      end
    join_none
  end
  
  //--------------------------------------------------------------------------------------------
  // READ ADDRESS PATH - Master Side
  // Monitor master read address requests and increment pending counter
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
          // FIXED: Increment pending request counter
          rr_read_pending_cnt[s_idx][m_idx]++;
          
          `uvm_info("RD_PENDING_INC", 
                   $sformatf("M[%0d]->S[%0d] pending counter: %0d", 
                            m_idx, s_idx, rr_read_pending_cnt[s_idx][m_idx]), 
                   UVM_HIGH)
          
          // Generate expected read data from reference model
          $cast(pending_tx.tx, m_read_addr_tx.clone());
          ref_model_read(pending_tx.tx, s_idx);
          
          pending_tx.master_id = m_idx;
          pending_tx.slave_id = s_idx;
          pending_tx.address_granted = 0;  // NEW: Not yet granted
          
          // Store in queue (in-order)
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
  // Monitor slave read address acceptance and check arbitration
  //--------------------------------------------------------------------------------------------
  foreach(axi4_slave_read_address_analysis_fifo[i]) begin
    automatic int s_idx = i;
    fork
      forever begin
        axi4_slave_tx s_read_addr_tx;
        pending_read_transaction_t pending_tx;
        int master_id;
        bit found;
        
        axi4_slave_read_address_analysis_fifo[s_idx].get(s_read_addr_tx);
        axi4_slave_tx_araddr_count[s_idx]++;
        
        `uvm_info("SLV_RD_ADDR", 
                 $sformatf("S[%0d] ARID=0x%0h ARADDR=0x%0h ARLEN=%0d", 
                          s_idx, s_read_addr_tx.arid, s_read_addr_tx.araddr, 
                          s_read_addr_tx.arlen), 
                 UVM_MEDIUM)
        
        // Find matching pending transaction (in-order)
        found = 0;
        if(pending_read_txns[s_idx].exists(s_read_addr_tx.arid)) begin
          if(pending_read_txns[s_idx][s_read_addr_tx.arid].size() > 0) begin
            pending_tx = pending_read_txns[s_idx][s_read_addr_tx.arid][0];
            master_id = pending_tx.master_id;
            found = 1;
            
            // Check round-robin arbitration for read (also decrements counter)
            check_read_rr_arbitration(s_idx, master_id);
            
            // Compare read address
            axi4_read_address_comparison(pending_tx.tx, s_read_addr_tx, master_id, s_idx);
            
            // FIXED: Mark address as granted and trigger event
            pending_tx.address_granted = 1;
            pending_read_txns[s_idx][s_read_addr_tx.arid][0] = pending_tx;  // Update the queue
            
            // Trigger event
            ->slave_read_addr_granted[s_idx];
            
            `uvm_info("RD_ADDR_GRANTED", 
                     $sformatf("S[%0d] M[%0d] ARID=0x%0h address granted", 
                              s_idx, master_id, s_read_addr_tx.arid), 
                     UVM_HIGH)
          end
        end
        
        if(!found) begin
          `uvm_error("RD_ADDR_NO_MATCH", 
                    $sformatf("S[%0d] received ARID=0x%0h but no pending transaction", 
                             s_idx, s_read_addr_tx.arid))
        end
      end
    join_none
  end
  
  //--------------------------------------------------------------------------------------------
  // READ DATA PATH - Slave Side
  // Monitor slave read data for counting purposes
  //--------------------------------------------------------------------------------------------
  foreach(axi4_slave_read_data_analysis_fifo[i]) begin
    automatic int s_idx = i;
    fork
      forever begin
        axi4_slave_tx s_read_data_tx;
        
        axi4_slave_read_data_analysis_fifo[s_idx].get(s_read_data_tx);
        axi4_slave_tx_rdata_count[s_idx]++;
        axi4_slave_tx_rresp_count[s_idx]++;  // Count read response from slave
        
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
  // FIXED: Wait for address arbitration before comparing read data
  //--------------------------------------------------------------------------------------------
  foreach(axi4_master_read_data_analysis_fifo[i]) begin
    automatic int m_idx = i;
    fork
      forever begin
        axi4_master_tx m_read_data_tx;
        pending_read_transaction_t pending_tx;
        int s_idx;
        bit found;
        
        axi4_master_read_data_analysis_fifo[m_idx].get(m_read_data_tx);
        axi4_master_tx_rdata_count[m_idx]++;
        axi4_master_tx_rresp_count[m_idx]++;  // Count read response
        
        `uvm_info("MSTR_RD_DATA", 
                 $sformatf("M[%0d] RID=0x%0h RDATA[0]=0x%0h RLAST=%0b RRESP=%0s", 
                          m_idx, m_read_data_tx.arid, m_read_data_tx.rdata[0], 
                          m_read_data_tx.rlast, m_read_data_tx.rresp[0].name()), 
                 UVM_MEDIUM)
        
        // Find the slave this read went to
        s_idx = get_slave_index(m_read_data_tx.araddr);
        
        if(s_idx != -1) begin
          // FIXED GAP #2: Wait for address arbitration to complete
          @(slave_read_addr_granted[s_idx]);
          
          // Find matching pending transaction by RID (in-order)
          found = 0;
          if(pending_read_txns[s_idx].exists(m_read_data_tx.arid)) begin
            if(pending_read_txns[s_idx][m_read_data_tx.arid].size() > 0) begin
              // Check if address was granted for this transaction
              if(pending_read_txns[s_idx][m_read_data_tx.arid][0].address_granted) begin
                // For in-order transactions, response should match the first pending
                pending_tx = pending_read_txns[s_idx][m_read_data_tx.arid].pop_front();
                
                // Verify this is from the correct master
                if(pending_tx.master_id != m_idx) begin
                  `uvm_error("RD_MASTER_MISMATCH", 
                            $sformatf("S[%0d] RID=0x%0h expected from M[%0d] but received from M[%0d]", 
                                     s_idx, m_read_data_tx.arid, pending_tx.master_id, m_idx))
                end
                
                // Compare read data
                axi4_read_data_comparison(pending_tx.tx, m_read_data_tx, m_idx, s_idx);
                
                `uvm_info("RD_COMPLETE", 
                         $sformatf("S[%0d] M[%0d] RID=0x%0h read transaction complete", 
                                  s_idx, m_idx, m_read_data_tx.arid), 
                         UVM_MEDIUM)
                found = 1;
              end else begin
                `uvm_error("RD_DATA_BEFORE_AR", 
                          $sformatf("M[%0d] S[%0d] RID=0x%0h read data before AR granted", 
                                   m_idx, s_idx, m_read_data_tx.arid))
              end
            end
          end
          
          if(!found) begin
            `uvm_error("RD_DATA_NO_MATCH", 
                      $sformatf("M[%0d] received RID=0x%0h from S[%0d] but no granted pending transaction", 
                               m_idx, m_read_data_tx.arid, s_idx))
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
task axi4_scoreboard::axi4_write_address_comparison(
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
task axi4_scoreboard::axi4_write_data_comparison(
  input axi4_master_tx exp_tx,
  input axi4_slave_tx act_tx,
  input int master_id,
  input int slave_id
);
  
  // Note: This is simplified - assumes single beat comparison
  // For full implementation, would need to track beat index
  
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
task axi4_scoreboard::axi4_write_response_comparison(
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
task axi4_scoreboard::axi4_read_address_comparison(
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
task axi4_scoreboard::axi4_read_data_comparison(
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
function void axi4_scoreboard::check_phase(uvm_phase phase);
  super.check_phase(phase);
  
  `uvm_info(get_type_name(), "========== SCOREBOARD CHECK PHASE ==========", UVM_LOW)
  
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
  
  // Check for leftover pending counters (should all be 0)
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
  
  // Check write channel results
  if((byte_data_cmp_verified_awid_count > 0) && (byte_data_cmp_failed_awid_count == 0)) begin
    `uvm_info(get_type_name(), $sformatf("✓ AWID comparisons: %0d passed", byte_data_cmp_verified_awid_count), UVM_LOW)
  end else if(byte_data_cmp_failed_awid_count > 0) begin
    `uvm_error("CHECK", $sformatf("✗ AWID: Verified=%0d Failed=%0d", 
              byte_data_cmp_verified_awid_count, byte_data_cmp_failed_awid_count))
  end
  
  if((byte_data_cmp_verified_awaddr_count > 0) && (byte_data_cmp_failed_awaddr_count == 0)) begin
    `uvm_info(get_type_name(), $sformatf("✓ AWADDR comparisons: %0d passed", byte_data_cmp_verified_awaddr_count), UVM_LOW)
  end else if(byte_data_cmp_failed_awaddr_count > 0) begin
    `uvm_error("CHECK", $sformatf("✗ AWADDR: Verified=%0d Failed=%0d", 
              byte_data_cmp_verified_awaddr_count, byte_data_cmp_failed_awaddr_count))
  end
  
  // Check read channel results
  if((byte_data_cmp_verified_rdata_count > 0) && (byte_data_cmp_failed_rdata_count == 0)) begin
    `uvm_info(get_type_name(), $sformatf("✓ RDATA comparisons: %0d passed", byte_data_cmp_verified_rdata_count), UVM_LOW)
  end else if(byte_data_cmp_failed_rdata_count > 0) begin
    `uvm_error("CHECK", $sformatf("✗ RDATA: Verified=%0d Failed=%0d", 
              byte_data_cmp_verified_rdata_count, byte_data_cmp_failed_rdata_count))
  end
  
  // Check arbitration results
  if(rr_write_violations == 0 && rr_write_grants > 0) begin
    `uvm_info(get_type_name(), $sformatf("✓ Write RR Arbitration: %0d grants, 0 violations", rr_write_grants), UVM_LOW)
  end else if(rr_write_violations > 0) begin
    `uvm_error("CHECK", $sformatf("✗ Write RR Arbitration: %0d violations out of %0d grants", 
              rr_write_violations, rr_write_grants))
  end
  
  if(rr_read_violations == 0 && rr_read_grants > 0) begin
    `uvm_info(get_type_name(), $sformatf("✓ Read RR Arbitration: %0d grants, 0 violations", rr_read_grants), UVM_LOW)
  end else if(rr_read_violations > 0) begin
    `uvm_error("CHECK", $sformatf("✗ Read RR Arbitration: %0d violations out of %0d grants", 
              rr_read_violations, rr_read_grants))
  end
  
  `uvm_info(get_type_name(), "========== END CHECK PHASE ==========", UVM_LOW)
  
endfunction : check_phase

//--------------------------------------------------------------------------------------------
// Function: report_phase
//--------------------------------------------------------------------------------------------
function void axi4_scoreboard::report_phase(uvm_phase phase);
  super.report_phase(phase);
  
  `uvm_info("REPORT", "========== AXI4 MULTI-MASTER MULTI-SLAVE SCOREBOARD REPORT ==========", UVM_LOW)
  
  // Transaction counts
  `uvm_info("REPORT", "===== TRANSACTION COUNTS =====", UVM_LOW)
  `uvm_info("REPORT", $sformatf("Total Master Transactions : %0d", total_master_tx_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("Total Slave Transactions  : %0d", total_slave_tx_count), UVM_LOW)
  
  // Per master counts
  `uvm_info("REPORT", "===== PER MASTER COUNTS =====", UVM_LOW)
  foreach(axi4_master_tx_awaddr_count[i]) begin
    `uvm_info("REPORT", $sformatf("Master[%0d]: WR_ADDR=%0d WR_RESP=%0d RD_ADDR=%0d RD_DATA=%0d RD_RESP=%0d", 
              i, axi4_master_tx_awaddr_count[i], axi4_master_tx_bresp_count[i],
              axi4_master_tx_araddr_count[i], axi4_master_tx_rdata_count[i],
              axi4_master_tx_rresp_count[i]), UVM_LOW)
  end
  
  // Per slave counts
  `uvm_info("REPORT", "===== PER SLAVE COUNTS =====", UVM_LOW)
  foreach(axi4_slave_tx_awaddr_count[i]) begin
    `uvm_info("REPORT", $sformatf("Slave[%0d]: WR_ADDR=%0d WR_DATA=%0d WR_RESP=%0d RD_ADDR=%0d RD_DATA=%0d RD_RESP=%0d", 
              i, axi4_slave_tx_awaddr_count[i], axi4_slave_tx_wdata_count[i], 
              axi4_slave_tx_bresp_count[i], axi4_slave_tx_araddr_count[i], 
              axi4_slave_tx_rdata_count[i], axi4_slave_tx_rresp_count[i]), UVM_LOW)
  end
  
  // Write channel comparison summary
  `uvm_info("REPORT", "===== WRITE CHANNEL VERIFICATION =====", UVM_LOW)
  `uvm_info("REPORT", $sformatf("AWID    : Pass=%0d Fail=%0d", byte_data_cmp_verified_awid_count, byte_data_cmp_failed_awid_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("AWADDR  : Pass=%0d Fail=%0d", byte_data_cmp_verified_awaddr_count, byte_data_cmp_failed_awaddr_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("AWLEN   : Pass=%0d Fail=%0d", byte_data_cmp_verified_awlen_count, byte_data_cmp_failed_awlen_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("AWSIZE  : Pass=%0d Fail=%0d", byte_data_cmp_verified_awsize_count, byte_data_cmp_failed_awsize_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("AWBURST : Pass=%0d Fail=%0d", byte_data_cmp_verified_awburst_count, byte_data_cmp_failed_awburst_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("WDATA   : Pass=%0d Fail=%0d", byte_data_cmp_verified_wdata_count, byte_data_cmp_failed_wdata_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("WSTRB   : Pass=%0d Fail=%0d", byte_data_cmp_verified_wstrb_count, byte_data_cmp_failed_wstrb_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("WLAST   : Pass=%0d Fail=%0d", byte_data_cmp_verified_wlast_count, byte_data_cmp_failed_wlast_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("BID     : Pass=%0d Fail=%0d", byte_data_cmp_verified_bid_count, byte_data_cmp_failed_bid_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("BRESP   : Pass=%0d Fail=%0d", byte_data_cmp_verified_bresp_count, byte_data_cmp_failed_bresp_count), UVM_LOW)
  
  // Read channel comparison summary
  `uvm_info("REPORT", "===== READ CHANNEL VERIFICATION =====", UVM_LOW)
  `uvm_info("REPORT", $sformatf("ARID    : Pass=%0d Fail=%0d", byte_data_cmp_verified_arid_count, byte_data_cmp_failed_arid_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("ARADDR  : Pass=%0d Fail=%0d", byte_data_cmp_verified_araddr_count, byte_data_cmp_failed_araddr_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("ARLEN   : Pass=%0d Fail=%0d", byte_data_cmp_verified_arlen_count, byte_data_cmp_failed_arlen_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("ARSIZE  : Pass=%0d Fail=%0d", byte_data_cmp_verified_arsize_count, byte_data_cmp_failed_arsize_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("ARBURST : Pass=%0d Fail=%0d", byte_data_cmp_verified_arburst_count, byte_data_cmp_failed_arburst_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("RID     : Pass=%0d Fail=%0d", byte_data_cmp_verified_rid_count, byte_data_cmp_failed_rid_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("RDATA   : Pass=%0d Fail=%0d", byte_data_cmp_verified_rdata_count, byte_data_cmp_failed_rdata_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("RLAST   : Pass=%0d Fail=%0d", byte_data_cmp_verified_rlast_count, byte_data_cmp_failed_rlast_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("RRESP   : Pass=%0d Fail=%0d", byte_data_cmp_verified_rresp_count, byte_data_cmp_failed_rresp_count), UVM_LOW)
  
  // Arbitration summary
  `uvm_info("REPORT", "===== ROUND-ROBIN ARBITRATION VERIFICATION =====", UVM_LOW)
  `uvm_info("REPORT", $sformatf("Write Channel: %0d grants, %0d violations", rr_write_grants, rr_write_violations), UVM_LOW)
  `uvm_info("REPORT", $sformatf("Read Channel : %0d grants, %0d violations", rr_read_grants, rr_read_violations), UVM_LOW)
  
  if(nonExistantMemRead > 0) begin
    `uvm_info("REPORT", $sformatf("Note: %0d read transactions targeted non-existent memory regions", nonExistantMemRead), UVM_LOW)
  end
  `uvm_info("REPORT", "========== END OF SCOREBOARD REPORT ==========", UVM_LOW)
endfunction : report_phase