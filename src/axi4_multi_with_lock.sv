`ifndef AXI4_SCOREBOARD_APPROACH1_WITH_LOCK_INCLUDED_
`define AXI4_SCOREBOARD_APPROACH1_WITH_LOCK_INCLUDED_

// APPROACH 1 WITH LOCKING MECHANISM
// This approach adds:
// 1. Master ID tracking to ensure read data reaches the correct master
// 2. Locking mechanism to track exclusive master-slave access

class axi4_scoreboard_approach1_with_lock extends uvm_scoreboard;
  `uvm_component_utils(axi4_scoreboard_approach1_with_lock)

  axi4_master_tx axi4_master_tx_h;
  axi4_slave_tx axi4_slave_tx_h;

  typedef struct {
    bit[DATA_WIDTH-1:0] data;
    bit[(DATA_WIDTH/8)-1:0] strobe;
  } DataTransaction;
  
  // Reference memory indexed by [slave_id][address]
  logic[7:0] referenceData[int][longint];

  // Expected transaction queues per slave for write transactions
  axi4_master_tx slaveExpectedWriteQueue[int][$];
  int slaveExpectedWriteMasterIdQueue[int][$];
  
  // Expected transaction queues per slave for read transactions
  axi4_master_tx slaveExpectedReadQueue[int][$];
  int slaveExpectedReadMasterIdQueue[int][$];

  // Track expected master for each read transaction ID per slave
  int expectedMasterForReadId[string];
  
  // Track read transactions waiting for data return
  typedef struct {
    int slave_idx;
    int master_idx;
    axi4_master_tx expected_tx;
    bit[ID_WIDTH-1:0] transaction_id;
  } read_tracker_t;
  
  read_tracker_t pendingReads[$];

  // ==================================================================================
  // LOCKING MECHANISM - NEW ADDITION
  // ==================================================================================
  
  // Lock state tracking
  typedef struct {
    bit is_locked;              // Is this slave locked?
    int locked_by_master;       // Which master holds the lock
    bit[ID_WIDTH-1:0] lock_id;  // Transaction ID that acquired the lock
    time lock_start_time;       // When was lock acquired
    int lock_transaction_count; // Number of transactions during lock
  } slave_lock_state_t;
  
  slave_lock_state_t slave_lock_state[int]; // Indexed by slave_id
  
  // Lock statistics
  int total_locks_acquired;
  int total_locks_released;
  int lock_violations_detected;
  int lock_verify_passed;
  int lock_verify_failed;
  
  // Lock tracking per master-slave pair
  typedef struct {
    int lock_count;
    time total_lock_duration;
    time max_lock_duration;
  } lock_stats_t;
  
  lock_stats_t lock_statistics[string]; // Key: "master_X_slave_Y"
  
  // ==================================================================================

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

  // Transaction counters per master/slave
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

  // Global transaction counters
  int total_master_tx_count = 0;
  int total_slave_tx_count = 0;
  
  // Comparison result counters
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
  int byte_data_cmp_verified_wuser_count;
  int byte_data_cmp_verified_bid_count;
  int byte_data_cmp_verified_bresp_count;
  int byte_data_cmp_verified_buser_count;
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
  int byte_data_cmp_verified_ruser_count;
  
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
  int byte_data_cmp_failed_wuser_count;
  int byte_data_cmp_failed_bid_count;
  int byte_data_cmp_failed_bresp_count;
  int byte_data_cmp_failed_buser_count;
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
  int byte_data_cmp_failed_ruser_count;

  // Master routing verification counters
  int master_routing_verified_count;
  int master_routing_failed_count;

  // Slave address configuration
  bit[ADDR_WIDTH-1:0] SLAVE_START_ADDR[];
  bit[ADDR_WIDTH-1:0] SLAVE_END_ADDR[];

  // Helper variables
  int nonExistantMemRead;
  
  // Environment configuration handle
  axi4_env_config axi4_env_cfg_h;
  axi4_slave_agent_config axi4_slave_agent_cfg_h[];

  extern function new(string name = "axi4_scoreboard_approach1_with_lock", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);
  extern virtual function int get_slave_index(logic[ADDR_WIDTH-1:0] addr);
  extern virtual function void ref_model_write(axi4_master_tx m_tx, int slave_idx, int master_idx);
  extern virtual function void ref_model_read(axi4_master_tx m_tx, int slave_idx);
  extern virtual task axi4_write_address_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id);
  extern virtual task axi4_write_response_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id);
  extern virtual task axi4_read_address_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id);
  extern virtual task axi4_read_data_master_routing_check(input axi4_master_tx act_tx, input int actual_master_idx);
  
  // NEW: Locking mechanism functions
  extern virtual function void handle_lock_acquisition(input int master_idx, input int slave_idx, input bit[ID_WIDTH-1:0] trans_id, input bit is_write);
  extern virtual function void handle_lock_release(input int slave_idx);
  extern virtual function bit check_lock_permission(input int master_idx, input int slave_idx);
  extern virtual function void verify_locked_access(input int master_idx, input int slave_idx, input bit[ID_WIDTH-1:0] trans_id);
  
  extern virtual function void check_phase(uvm_phase phase);
  extern virtual function void report_phase(uvm_phase phase);

endclass : axi4_scoreboard_approach1_with_lock

function axi4_scoreboard_approach1_with_lock::new(string name = "axi4_scoreboard_approach1_with_lock", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

function void axi4_scoreboard_approach1_with_lock::build_phase(uvm_phase phase);
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
    
    if(!uvm_config_db#(axi4_slave_agent_config)::get(this, "", $sformatf("axi4_slave_agent_config[%0d]", i), axi4_slave_agent_cfg_h[i])) begin
      `uvm_fatal("FATAL_SA_AGENT_CONFIG", $sformatf("Couldn't get axi4_slave_agent_config[%0d] from config_db", i))
    end
    
    SLAVE_START_ADDR[i] = axi4_slave_agent_cfg_h[i].min_address;
    SLAVE_END_ADDR[i] = axi4_slave_agent_cfg_h[i].max_address;
    
    // Initialize lock state for each slave
    slave_lock_state[i].is_locked = 0;
    slave_lock_state[i].locked_by_master = -1;
    slave_lock_state[i].lock_id = '0;
    slave_lock_state[i].lock_start_time = 0;
    slave_lock_state[i].lock_transaction_count = 0;
  end
  
endfunction : build_phase

function void axi4_scoreboard_approach1_with_lock::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase

function int axi4_scoreboard_approach1_with_lock::get_slave_index(logic[ADDR_WIDTH-1:0] addr);
  for(int i = 0; i < NO_OF_SLAVES; i++) begin
    if(addr >= SLAVE_START_ADDR[i] && addr <= SLAVE_END_ADDR[i]) begin
      return i;
    end
  end
  return -1;
endfunction : get_slave_index

// ==================================================================================
// LOCKING MECHANISM FUNCTIONS
// ==================================================================================

// Handle lock acquisition when AWLOCK/ARLOCK is set
function void axi4_scoreboard_approach1_with_lock::handle_lock_acquisition(
  input int master_idx, 
  input int slave_idx, 
  input bit[ID_WIDTH-1:0] trans_id,
  input bit is_write
);
  string stat_key;
  time current_time;
  
  current_time = $time;
  stat_key = $sformatf("M%0d_S%0d", master_idx, slave_idx);
  
  if(slave_lock_state[slave_idx].is_locked) begin
    // Slave is already locked
    if(slave_lock_state[slave_idx].locked_by_master == master_idx) begin
      // Same master - this is allowed (nested lock or continued access)
      slave_lock_state[slave_idx].lock_transaction_count++;
      `uvm_info("LOCK_MECHANISM", 
                $sformatf("Master[%0d] continues locked access to Slave[%0d] (%s transaction, ID=%0h, count=%0d)",
                master_idx, slave_idx, is_write ? "WRITE" : "READ", trans_id, 
                slave_lock_state[slave_idx].lock_transaction_count), UVM_MEDIUM)
    end else begin
      // Different master trying to access locked slave - VIOLATION
      lock_violations_detected++;
      `uvm_error("LOCK_VIOLATION",
                $sformatf("Master[%0d] attempted to access Slave[%0d] which is locked by Master[%0d] (ID=%0h, %s)",
                master_idx, slave_idx, slave_lock_state[slave_idx].locked_by_master,
                trans_id, is_write ? "WRITE" : "READ"))
    end
  end else begin
    // Acquire new lock
    slave_lock_state[slave_idx].is_locked = 1;
    slave_lock_state[slave_idx].locked_by_master = master_idx;
    slave_lock_state[slave_idx].lock_id = trans_id;
    slave_lock_state[slave_idx].lock_start_time = current_time;
    slave_lock_state[slave_idx].lock_transaction_count = 1;
    
    total_locks_acquired++;
    
    // Initialize statistics if first time
    if(!lock_statistics.exists(stat_key)) begin
      lock_statistics[stat_key].lock_count = 0;
      lock_statistics[stat_key].total_lock_duration = 0;
      lock_statistics[stat_key].max_lock_duration = 0;
    end
    
    lock_statistics[stat_key].lock_count++;
    
    `uvm_info("LOCK_ACQUIRED",
              $sformatf("Master[%0d] acquired LOCK on Slave[%0d] (ID=%0h, %s, time=%0t)",
              master_idx, slave_idx, trans_id, is_write ? "WRITE" : "READ", current_time), UVM_MEDIUM)
  end
  
endfunction : handle_lock_acquisition

// Handle lock release (typically on last transaction or explicit unlock)
function void axi4_scoreboard_approach1_with_lock::handle_lock_release(input int slave_idx);
  string stat_key;
  time current_time, lock_duration;
  int master_idx;
  
  current_time = $time;
  
  if(slave_lock_state[slave_idx].is_locked) begin
    master_idx = slave_lock_state[slave_idx].locked_by_master;
    stat_key = $sformatf("M%0d_S%0d", master_idx, slave_idx);
    
    lock_duration = current_time - slave_lock_state[slave_idx].lock_start_time;
    
    // Update statistics
    if(lock_statistics.exists(stat_key)) begin
      lock_statistics[stat_key].total_lock_duration += lock_duration;
      if(lock_duration > lock_statistics[stat_key].max_lock_duration) begin
        lock_statistics[stat_key].max_lock_duration = lock_duration;
      end
    end
    
    `uvm_info("LOCK_RELEASED",
              $sformatf("Master[%0d] released LOCK on Slave[%0d] (duration=%0t, transactions=%0d)",
              master_idx, slave_idx, lock_duration, slave_lock_state[slave_idx].lock_transaction_count), UVM_MEDIUM)
    
    // Release the lock
    slave_lock_state[slave_idx].is_locked = 0;
    slave_lock_state[slave_idx].locked_by_master = -1;
    slave_lock_state[slave_idx].lock_id = '0;
    slave_lock_state[slave_idx].lock_transaction_count = 0;
    
    total_locks_released++;
  end else begin
    `uvm_warning("LOCK_RELEASE_WARNING",
                $sformatf("Attempted to release lock on Slave[%0d] which is not locked", slave_idx))
  end
  
endfunction : handle_lock_release

// Check if a master has permission to access a slave
function bit axi4_scoreboard_approach1_with_lock::check_lock_permission(
  input int master_idx, 
  input int slave_idx
);
  
  if(slave_lock_state[slave_idx].is_locked) begin
    if(slave_lock_state[slave_idx].locked_by_master == master_idx) begin
      return 1; // This master holds the lock
    end else begin
      return 0; // Different master holds the lock
    end
  end else begin
    return 1; // Slave is not locked, access allowed
  end
  
endfunction : check_lock_permission

// Verify that locked transactions are handled correctly
function void axi4_scoreboard_approach1_with_lock::verify_locked_access(
  input int master_idx, 
  input int slave_idx, 
  input bit[ID_WIDTH-1:0] trans_id
);
  
  if(slave_lock_state[slave_idx].is_locked) begin
    if(slave_lock_state[slave_idx].locked_by_master == master_idx) begin
      lock_verify_passed++;
      `uvm_info("LOCK_VERIFY_PASS",
                $sformatf("Master[%0d] correctly accessing locked Slave[%0d] (ID=%0h)",
                master_idx, slave_idx, trans_id), UVM_HIGH)
    end else begin
      lock_verify_failed++;
      `uvm_error("LOCK_VERIFY_FAIL",
                $sformatf("Master[%0d] accessing Slave[%0d] locked by Master[%0d] (ID=%0h)",
                master_idx, slave_idx, slave_lock_state[slave_idx].locked_by_master, trans_id))
    end
  end
  
endfunction : verify_locked_access

// ==================================================================================
// REST OF THE SCOREBOARD FUNCTIONS (ref_model_write, ref_model_read, etc.)
// ==================================================================================

function void axi4_scoreboard_approach1_with_lock::ref_model_write(axi4_master_tx m_tx, int slave_idx, int master_idx);
  int bytes_per_beat;
  int temp_addr;
  int align_amount;
  int wrap_start_addr;
  int wrap_end_addr;
  
  bytes_per_beat = 1 << m_tx.awsize;
  temp_addr = m_tx.awaddr;
  
  wrap_start_addr = temp_addr - int'(temp_addr % ((2**(m_tx.awsize)) * (m_tx.awlen + 1)));
  wrap_end_addr = wrap_start_addr + ((2**(m_tx.awsize)) * (m_tx.awlen + 1));
  
  if((m_tx.awaddr % (2**m_tx.awsize)) != 0) begin
    align_amount = m_tx.awaddr % (2**(m_tx.awsize));
  end else begin
    align_amount = 0;
  end
  
  foreach(m_tx.wdata[i]) begin
    int j;
    int local_align = (i == 0) ? align_amount : 0;
    
    case(m_tx.awburst)
      2'b00: begin // FIXED
        for(int k = 0; k < bytes_per_beat - local_align; k++) begin
          j = (temp_addr + k) % (DATA_WIDTH/8);
          if(m_tx.wstrb[i][j]) begin
            referenceData[slave_idx][temp_addr + k] = m_tx.wdata[i][8*j+7 -: 8];
            `uvm_info("REF_MODEL_WRITE", $sformatf("SLAVE=%0d MASTER=%0d ADDR=0x%0h DATA=0x%02h", 
                      slave_idx, master_idx, temp_addr + k, m_tx.wdata[i][8*j+7 -: 8]), UVM_HIGH)
          end
        end
      end
      
      2'b01: begin // INCR
        for(int k = 0; k < bytes_per_beat - local_align; k++) begin
          j = temp_addr % (DATA_WIDTH/8);
          if(m_tx.wstrb[i][j]) begin
            referenceData[slave_idx][temp_addr] = m_tx.wdata[i][8*j+7 -: 8];
            `uvm_info("REF_MODEL_WRITE", $sformatf("SLAVE=%0d MASTER=%0d ADDR=0x%0h DATA=0x%02h", 
                      slave_idx, master_idx, temp_addr, m_tx.wdata[i][8*j+7 -: 8]), UVM_HIGH)
          end
          temp_addr++;
        end
      end
      
      2'b10: begin // WRAP
        for(int k = 0; k < bytes_per_beat - local_align; k++) begin
          j = temp_addr % (DATA_WIDTH/8);
          if(m_tx.wstrb[i][j]) begin
            referenceData[slave_idx][temp_addr] = m_tx.wdata[i][8*j+7 -: 8];
            `uvm_info("REF_MODEL_WRITE", $sformatf("SLAVE=%0d MASTER=%0d ADDR=0x%0h DATA=0x%02h", 
                      slave_idx, master_idx, temp_addr, m_tx.wdata[i][8*j+7 -: 8]), UVM_HIGH)
          end
          temp_addr++;
          if(temp_addr == wrap_end_addr) temp_addr = wrap_start_addr;
        end
      end
    endcase
  end
  
endfunction : ref_model_write

function void axi4_scoreboard_approach1_with_lock::ref_model_read(axi4_master_tx m_tx, int slave_idx);
  int bytes_per_beat;
  int temp_addr;
  int align_amount;
  int wrap_start_addr;
  int wrap_end_addr;
  
  bytes_per_beat = 1 << m_tx.arsize;
  temp_addr = m_tx.araddr;
  
  wrap_start_addr = temp_addr - int'(temp_addr % ((2**(m_tx.arsize)) * (m_tx.arlen + 1)));
  wrap_end_addr = wrap_start_addr + ((2**(m_tx.arsize)) * (m_tx.arlen + 1));
  
  if((m_tx.araddr % (2**m_tx.arsize)) != 0) begin
    align_amount = m_tx.araddr % (2**(m_tx.arsize));
  end else begin
    align_amount = 0;
  end
  
  m_tx.rdata = new[m_tx.arlen + 1];
  
  foreach(m_tx.rdata[i]) begin
    int j;
    int local_align = (i == 0) ? align_amount : 0;
    m_tx.rdata[i] = '0;
    
    case(m_tx.arburst)
      2'b00: begin // FIXED
        for(int k = 0; k < bytes_per_beat - local_align; k++) begin
          j = (temp_addr + k) % (DATA_WIDTH/8);
          if(referenceData[slave_idx].exists(temp_addr + k)) begin
            m_tx.rdata[i][8*j+7 -: 8] = referenceData[slave_idx][temp_addr + k];
          end else begin
            m_tx.rdata[i][8*j+7 -: 8] = 8'h00;
          end
        end
      end
      
      2'b01: begin // INCR
        for(int k = 0; k < bytes_per_beat - local_align; k++) begin
          j = temp_addr % (DATA_WIDTH/8);
          if(referenceData[slave_idx].exists(temp_addr)) begin
            m_tx.rdata[i][8*j+7 -: 8] = referenceData[slave_idx][temp_addr];
          end else begin
            m_tx.rdata[i][8*j+7 -: 8] = 8'h00;
            nonExistantMemRead++;
          end
          temp_addr++;
        end
      end
      
      2'b10: begin // WRAP
        for(int k = 0; k < bytes_per_beat - local_align; k++) begin
          j = temp_addr % (DATA_WIDTH/8);
          if(referenceData[slave_idx].exists(temp_addr)) begin
            m_tx.rdata[i][8*j+7 -: 8] = referenceData[slave_idx][temp_addr];
          end else begin
            m_tx.rdata[i][8*j+7 -: 8] = 8'h00;
            nonExistantMemRead++;
          end
          temp_addr++;
          if(temp_addr == wrap_end_addr) temp_addr = wrap_start_addr;
        end
      end
    endcase
  end
  
endfunction : ref_model_read

task axi4_scoreboard_approach1_with_lock::axi4_read_data_master_routing_check(
  input axi4_master_tx act_tx,
  input int actual_master_idx
);
  string lookup_key;
  int expected_master_idx;
  bit found = 0;
  
  for(int i = 0; i < pendingReads.size(); i++) begin
    if(pendingReads[i].transaction_id == act_tx.arid) begin
      expected_master_idx = pendingReads[i].master_idx;
      found = 1;
      
      if(expected_master_idx == actual_master_idx) begin
        master_routing_verified_count++;
        `uvm_info("MASTER_ROUTING_CHECK", 
                  $sformatf("✓ Read data correctly routed: RID=%0h reached expected Master[%0d]", 
                  act_tx.arid, actual_master_idx), UVM_MEDIUM)
      end else begin
        master_routing_failed_count++;
        `uvm_error("MASTER_ROUTING_ERROR", 
                   $sformatf("✗ Read data routing error: RID=%0h expected Master[%0d] but reached Master[%0d]",
                   act_tx.arid, expected_master_idx, actual_master_idx))
      end
      
      if(act_tx.rlast) begin
        pendingReads.delete(i);
        `uvm_info("MASTER_ROUTING_CHECK", 
                  $sformatf("Read transaction RID=%0h completed and removed from tracking", act_tx.arid), UVM_HIGH)
      end
      break;
    end
  end
  
  if(!found) begin
    `uvm_warning("MASTER_ROUTING_WARN", 
                 $sformatf("No pending read transaction found for RID=%0h at Master[%0d]", 
                 act_tx.arid, actual_master_idx))
  end
  
endtask : axi4_read_data_master_routing_check

task axi4_scoreboard_approach1_with_lock::run_phase(uvm_phase phase);
  super.run_phase(phase);
  
  // Write Address Path with LOCK handling
  foreach(axi4_master_write_address_analysis_fifo[i]) begin
    automatic int m_idx = i;
    fork
      forever begin
        axi4_master_tx m_write_addr_tx;
        int s_idx;
        
        axi4_master_write_address_analysis_fifo[m_idx].get(m_write_addr_tx);
        axi4_master_tx_awaddr_count[m_idx]++;
        total_master_tx_count++;
        
        `uvm_info("SCB_MASTER_WRITE_ADDR", $sformatf("Master[%0d] Write Address: AWID=%0h AWADDR=0x%0h AWLEN=%0d AWLOCK=%0b", 
                  m_idx, m_write_addr_tx.awid, m_write_addr_tx.awaddr, m_write_addr_tx.awlen, m_write_addr_tx.awlock), UVM_MEDIUM)
        
        s_idx = get_slave_index(m_write_addr_tx.awaddr);
        
        if(s_idx != -1) begin
          axi4_master_tx exp_tx;
          $cast(exp_tx, m_write_addr_tx.clone());
          
          // Handle lock acquisition for write
          if(m_write_addr_tx.awlock == 1'b1) begin
            handle_lock_acquisition(m_idx, s_idx, m_write_addr_tx.awid, 1'b1); // 1 = write
          end else begin
            // Verify access permission if not acquiring lock
            verify_locked_access(m_idx, s_idx, m_write_addr_tx.awid);
          end
          
          slaveExpectedWriteQueue[s_idx].push_back(exp_tx);
          slaveExpectedWriteMasterIdQueue[s_idx].push_back(m_idx);
          
          `uvm_info("SCB_EXPECT_WRITE", $sformatf("Slave[%0d] expecting write from Master[%0d]", s_idx, m_idx), UVM_HIGH)
        end else begin
          `uvm_error("SCB_ADDR_DECODE", $sformatf("Master[%0d] Address 0x%0h doesn't map to any slave", 
                     m_idx, m_write_addr_tx.awaddr))
        end
      end
    join_none
  end
  
  // Write Response Path with LOCK release handling
  foreach(axi4_slave_write_response_analysis_fifo[i]) begin
    automatic int s_idx = i;
    fork
      forever begin
        axi4_slave_tx s_write_resp_tx;
        axi4_slave_tx s_write_addr_tx;
        axi4_master_tx exp_write_tx;
        int master_id;
        
        axi4_slave_write_response_analysis_fifo[s_idx].get(s_write_resp_tx);
        axi4_slave_tx_bresp_count[s_idx]++;
        
        axi4_slave_write_address_analysis_fifo[s_idx].get(s_write_addr_tx);
        axi4_slave_tx_awaddr_count[s_idx]++;
        total_slave_tx_count++;
        
        `uvm_info("SCB_SLAVE_WRITE_RESP", $sformatf("Slave[%0d] Write Response: BID=%0h BRESP=%0s", 
                  s_idx, s_write_resp_tx.bid, s_write_resp_tx.bresp.name()), UVM_MEDIUM)
        
        wait(slaveExpectedWriteQueue[s_idx].size() > 0);
        
        exp_write_tx = slaveExpectedWriteQueue[s_idx].pop_front();
        master_id = slaveExpectedWriteMasterIdQueue[s_idx].pop_front();
        
        ref_model_write(exp_write_tx, s_idx, master_id);
        
        axi4_write_address_comparison(exp_write_tx, s_write_addr_tx, master_id);
        axi4_write_response_comparison(exp_write_tx, s_write_resp_tx, master_id);
        
        // Release lock if this was a locked transaction and it's complete
        if(exp_write_tx.awlock == 1'b0 && slave_lock_state[s_idx].is_locked && 
           slave_lock_state[s_idx].locked_by_master == master_id) begin
          handle_lock_release(s_idx);
        end
      end
    join_none
  end
  
  // Read Address Path with LOCK handling
  foreach(axi4_master_read_address_analysis_fifo[i]) begin
    automatic int m_idx = i;
    fork
      forever begin
        axi4_master_tx m_read_addr_tx;
        int s_idx;
        
        axi4_master_read_address_analysis_fifo[m_idx].get(m_read_addr_tx);
        axi4_master_tx_araddr_count[m_idx]++;
        
        `uvm_info("SCB_MASTER_READ_ADDR", $sformatf("Master[%0d] Read Address: ARID=%0h ARADDR=0x%0h ARLEN=%0d ARLOCK=%0b", 
                  m_idx, m_read_addr_tx.arid, m_read_addr_tx.araddr, m_read_addr_tx.arlen, m_read_addr_tx.arlock), UVM_MEDIUM)
        
        s_idx = get_slave_index(m_read_addr_tx.araddr);
        
        if(s_idx != -1) begin
          axi4_master_tx exp_tx;
          read_tracker_t tracker;
          
          $cast(exp_tx, m_read_addr_tx.clone());
          
          // Handle lock acquisition for read
          if(m_read_addr_tx.arlock == 1'b1) begin
            handle_lock_acquisition(m_idx, s_idx, m_read_addr_tx.arid, 1'b0); // 0 = read
          end else begin
            // Verify access permission if not acquiring lock
            verify_locked_access(m_idx, s_idx, m_read_addr_tx.arid);
          end
          
          ref_model_read(exp_tx, s_idx);
          
          slaveExpectedReadQueue[s_idx].push_back(exp_tx);
          slaveExpectedReadMasterIdQueue[s_idx].push_back(m_idx);
          
          tracker.slave_idx = s_idx;
          tracker.master_idx = m_idx;
          tracker.expected_tx = exp_tx;
          tracker.transaction_id = m_read_addr_tx.arid;
          pendingReads.push_back(tracker);
          
          `uvm_info("SCB_EXPECT_READ", $sformatf("Slave[%0d] expecting read from Master[%0d], RID=%0h tracked", 
                    s_idx, m_idx, m_read_addr_tx.arid), UVM_HIGH)
        end else begin
          `uvm_error("SCB_ADDR_DECODE", $sformatf("Master[%0d] Address 0x%0h doesn't map to any slave", 
                     m_idx, m_read_addr_tx.araddr))
        end
      end
    join_none
  end
  
  // Read Data Comparison with LOCK release handling
  foreach(axi4_master_read_data_analysis_fifo[i]) begin
    automatic int m_idx = i;
    fork
      forever begin
        axi4_master_tx m_read_data_tx;
        axi4_master_tx exp_read_tx;
        axi4_slave_tx s_read_addr_tx;
        int s_idx;
        int master_id;
        
        axi4_master_read_data_analysis_fifo[m_idx].get(m_read_data_tx);
        axi4_master_tx_rdata_count[m_idx]++;
        
        `uvm_info("SCB_MASTER_READ_DATA", $sformatf("Master[%0d] Read Data: RID=%0h RDATA[0]=0x%0h RLAST=%0b", 
                  m_idx, m_read_data_tx.arid, m_read_data_tx.rdata[0], m_read_data_tx.rlast), UVM_MEDIUM)
        
        axi4_read_data_master_routing_check(m_read_data_tx, m_idx);
        
        s_idx = get_slave_index(m_read_data_tx.araddr);
        
        if(s_idx != -1 && slaveExpectedReadQueue[s_idx].size() > 0) begin
          axi4_slave_read_address_analysis_fifo[s_idx].get(s_read_addr_tx);
          axi4_slave_tx_araddr_count[s_idx]++;
          
          exp_read_tx = slaveExpectedReadQueue[s_idx].pop_front();
          master_id = slaveExpectedReadMasterIdQueue[s_idx].pop_front();
          
          axi4_read_address_comparison(exp_read_tx, s_read_addr_tx, master_id);
          
          foreach(m_read_data_tx.rdata[beat]) begin
            if(exp_read_tx.rdata[beat] !== m_read_data_tx.rdata[beat]) begin
              `uvm_error("SCB_RDATA_MISMATCH", 
                        $sformatf("Master[%0d] Read data mismatch at beat %0d: Exp=0x%0h Act=0x%0h",
                        master_id, beat, exp_read_tx.rdata[beat], m_read_data_tx.rdata[beat]))
              byte_data_cmp_failed_rdata_count++;
            end else begin
              `uvm_info("SCB_RDATA_MATCH",
                       $sformatf("Master[%0d] Read data match at beat %0d: 0x%0h",
                       master_id, beat, m_read_data_tx.rdata[beat]), UVM_HIGH)
              byte_data_cmp_verified_rdata_count++;
            end
          end
          
          if(exp_read_tx.arid == m_read_data_tx.arid) begin
            byte_data_cmp_verified_rid_count++;
          end else begin
            `uvm_error("SCB_RID_MISMATCH", $sformatf("Master[%0d] RID: Exp=%0h Act=%0h", 
                      master_id, exp_read_tx.arid, m_read_data_tx.arid))
            byte_data_cmp_failed_rid_count++;
          end
          
          // Release lock if RLAST and lock was acquired with ARLOCK=0
          if(m_read_data_tx.rlast && exp_read_tx.arlock == 1'b0 && 
             slave_lock_state[s_idx].is_locked && 
             slave_lock_state[s_idx].locked_by_master == master_id) begin
            handle_lock_release(s_idx);
          end
        end
      end
    join_none
  end
  
  wait fork;
  
endtask : run_phase

task axi4_scoreboard_approach1_with_lock::axi4_write_address_comparison(
  input axi4_master_tx exp_tx,
  input axi4_slave_tx act_tx,
  input int master_id
);
  
  `uvm_info("SCB_WRITE_ADDR_CMP", $sformatf("Comparing write address for Master[%0d]", master_id), UVM_HIGH)
  
  if(exp_tx.awid == act_tx.awid) begin
    byte_data_cmp_verified_awid_count++;
    `uvm_info("SCB_AWID_MATCH", $sformatf("Master[%0d] AWID Match: %0h", master_id, exp_tx.awid), UVM_HIGH)
  end else begin
    `uvm_error("SCB_AWID_MISMATCH", $sformatf("Master[%0d] AWID: Exp=%0h Act=%0h", master_id, exp_tx.awid, act_tx.awid))
    byte_data_cmp_failed_awid_count++;
  end
  
  if(exp_tx.awaddr == act_tx.awaddr) begin
    byte_data_cmp_verified_awaddr_count++;
    `uvm_info("SCB_AWADDR_MATCH", $sformatf("Master[%0d] AWADDR Match: 0x%0h", master_id, exp_tx.awaddr), UVM_HIGH)
  end else begin
    `uvm_error("SCB_AWADDR_MISMATCH", $sformatf("Master[%0d] AWADDR: Exp=0x%0h Act=0x%0h", master_id, exp_tx.awaddr, act_tx.awaddr))
    byte_data_cmp_failed_awaddr_count++;
  end
  
  if(exp_tx.awlen == act_tx.awlen) begin
    byte_data_cmp_verified_awlen_count++;
  end else begin
    `uvm_error("SCB_AWLEN_MISMATCH", $sformatf("Master[%0d] AWLEN: Exp=%0d Act=%0d", master_id, exp_tx.awlen, act_tx.awlen))
    byte_data_cmp_failed_awlen_count++;
  end
  
  if(exp_tx.awsize == act_tx.awsize) begin
    byte_data_cmp_verified_awsize_count++;
  end else begin
    `uvm_error("SCB_AWSIZE_MISMATCH", $sformatf("Master[%0d] AWSIZE: Exp=%0d Act=%0d", master_id, exp_tx.awsize, act_tx.awsize))
    byte_data_cmp_failed_awsize_count++;
  end
  
  if(exp_tx.awburst == act_tx.awburst) begin
    byte_data_cmp_verified_awburst_count++;
  end else begin
    `uvm_error("SCB_AWBURST_MISMATCH", $sformatf("Master[%0d] AWBURST: Exp=%0d Act=%0d", master_id, exp_tx.awburst, act_tx.awburst))
    byte_data_cmp_failed_awburst_count++;
  end
  
  if(exp_tx.awlock == act_tx.awlock) begin
    byte_data_cmp_verified_awlock_count++;
  end else begin
    `uvm_error("SCB_AWLOCK_MISMATCH", $sformatf("Master[%0d] AWLOCK: Exp=%0d Act=%0d", master_id, exp_tx.awlock, act_tx.awlock))
    byte_data_cmp_failed_awlock_count++;
  end
  
  if(exp_tx.awcache == act_tx.awcache) begin
    byte_data_cmp_verified_awcache_count++;
  end else begin
    `uvm_error("SCB_AWCACHE_MISMATCH", $sformatf("Master[%0d] AWCACHE: Exp=%0h Act=%0h", master_id, exp_tx.awcache, act_tx.awcache))
    byte_data_cmp_failed_awcache_count++;
  end
  
  if(exp_tx.awprot == act_tx.awprot) begin
    byte_data_cmp_verified_awprot_count++;
  end else begin
    `uvm_error("SCB_AWPROT_MISMATCH", $sformatf("Master[%0d] AWPROT: Exp=%0h Act=%0h", master_id, exp_tx.awprot, act_tx.awprot))
    byte_data_cmp_failed_awprot_count++;
  end
  
endtask : axi4_write_address_comparison

task axi4_scoreboard_approach1_with_lock::axi4_write_response_comparison(
  input axi4_master_tx exp_tx,
  input axi4_slave_tx act_tx,
  input int master_id
);
  
  `uvm_info("SCB_WRITE_RESP_CMP", $sformatf("Comparing write response for Master[%0d]", master_id), UVM_HIGH)
  
  if(exp_tx.awid == act_tx.bid) begin
    byte_data_cmp_verified_bid_count++;
    `uvm_info("SCB_BID_MATCH", $sformatf("Master[%0d] BID Match: %0h", master_id, act_tx.bid), UVM_HIGH)
  end else begin
    `uvm_error("SCB_BID_MISMATCH", $sformatf("Master[%0d] BID: Exp=%0h Act=%0h", master_id, exp_tx.awid, act_tx.bid))
    byte_data_cmp_failed_bid_count++;
  end
  
  byte_data_cmp_verified_bresp_count++;
  `uvm_info("SCB_BRESP", $sformatf("Master[%0d] BRESP=%0s", master_id, act_tx.bresp.name()), UVM_HIGH)
  
endtask : axi4_write_response_comparison

task axi4_scoreboard_approach1_with_lock::axi4_read_address_comparison(
  input axi4_master_tx exp_tx,
  input axi4_slave_tx act_tx,
  input int master_id
);
  
  `uvm_info("SCB_READ_ADDR_CMP", $sformatf("Comparing read address for Master[%0d]", master_id), UVM_HIGH)
  
  if(exp_tx.arid == act_tx.arid) begin
    byte_data_cmp_verified_arid_count++;
    `uvm_info("SCB_ARID_MATCH", $sformatf("Master[%0d] ARID Match: %0h", master_id, exp_tx.arid), UVM_HIGH)
  end else begin
    `uvm_error("SCB_ARID_MISMATCH", $sformatf("Master[%0d] ARID: Exp=%0h Act=%0h", master_id, exp_tx.arid, act_tx.arid))
    byte_data_cmp_failed_arid_count++;
  end
  
  if(exp_tx.araddr == act_tx.araddr) begin
    byte_data_cmp_verified_araddr_count++;
    `uvm_info("SCB_ARADDR_MATCH", $sformatf("Master[%0d] ARADDR Match: 0x%0h", master_id, exp_tx.araddr), UVM_HIGH)
  end else begin
    `uvm_error("SCB_ARADDR_MISMATCH", $sformatf("Master[%0d] ARADDR: Exp=0x%0h Act=0x%0h", master_id, exp_tx.araddr, act_tx.araddr))
    byte_data_cmp_failed_araddr_count++;
  end
  
  if(exp_tx.arlen == act_tx.arlen) begin
    byte_data_cmp_verified_arlen_count++;
  end else begin
    `uvm_error("SCB_ARLEN_MISMATCH", $sformatf("Master[%0d] ARLEN: Exp=%0d Act=%0d", master_id, exp_tx.arlen, act_tx.arlen))
    byte_data_cmp_failed_arlen_count++;
  end
  
  if(exp_tx.arsize == act_tx.arsize) begin
    byte_data_cmp_verified_arsize_count++;
  end else begin
    `uvm_error("SCB_ARSIZE_MISMATCH", $sformatf("Master[%0d] ARSIZE: Exp=%0d Act=%0d", master_id, exp_tx.arsize, act_tx.arsize))
    byte_data_cmp_failed_arsize_count++;
  end
  
  if(exp_tx.arburst == act_tx.arburst) begin
    byte_data_cmp_verified_arburst_count++;
  end else begin
    `uvm_error("SCB_ARBURST_MISMATCH", $sformatf("Master[%0d] ARBURST: Exp=%0d Act=%0d", master_id, exp_tx.arburst, act_tx.arburst))
    byte_data_cmp_failed_arburst_count++;
  end
  
  if(exp_tx.arlock == act_tx.arlock) begin
    byte_data_cmp_verified_arlock_count++;
  end else begin
    `uvm_error("SCB_ARLOCK_MISMATCH", $sformatf("Master[%0d] ARLOCK: Exp=%0d Act=%0d", master_id, exp_tx.arlock, act_tx.arlock))
    byte_data_cmp_failed_arlock_count++;
  end
  
  if(exp_tx.arcache == act_tx.arcache) begin
    byte_data_cmp_verified_arcache_count++;
  end else begin
    `uvm_error("SCB_ARCACHE_MISMATCH", $sformatf("Master[%0d] ARCACHE: Exp=%0h Act=%0h", master_id, exp_tx.arcache, act_tx.arcache))
    byte_data_cmp_failed_arcache_count++;
  end
  
  if(exp_tx.arprot == act_tx.arprot) begin
    byte_data_cmp_verified_arprot_count++;
  end else begin
    `uvm_error("SCB_ARPROT_MISMATCH", $sformatf("Master[%0d] ARPROT: Exp=%0h Act=%0h", master_id, exp_tx.arprot, act_tx.arprot))
    byte_data_cmp_failed_arprot_count++;
  end
  
  if(exp_tx.arregion == act_tx.arregion) begin
    byte_data_cmp_verified_arregion_count++;
  end else begin
    `uvm_error("SCB_ARREGION_MISMATCH", $sformatf("Master[%0d] ARREGION: Exp=%0h Act=%0h", master_id, exp_tx.arregion, act_tx.arregion))
    byte_data_cmp_failed_arregion_count++;
  end
  
  if(exp_tx.arqos == act_tx.arqos) begin
    byte_data_cmp_verified_arqos_count++;
  end else begin
    `uvm_error("SCB_ARQOS_MISMATCH", $sformatf("Master[%0d] ARQOS: Exp=%0h Act=%0h", master_id, exp_tx.arqos, act_tx.arqos))
    byte_data_cmp_failed_arqos_count++;
  end
  
endtask : axi4_read_address_comparison

function void axi4_scoreboard_approach1_with_lock::check_phase(uvm_phase phase);
  super.check_phase(phase);
  
  `uvm_info(get_type_name(), "========== SCOREBOARD CHECK PHASE ==========", UVM_LOW)
  
  // Write channel checks
  if((byte_data_cmp_verified_awid_count != 0) && (byte_data_cmp_failed_awid_count == 0)) begin
    `uvm_info(get_type_name(), $sformatf("✓ All AWID comparisons successful (%0d)", byte_data_cmp_verified_awid_count), UVM_LOW)
  end else begin
    `uvm_error("SC_CHECK", $sformatf("✗ AWID: Verified=%0d Failed=%0d", 
              byte_data_cmp_verified_awid_count, byte_data_cmp_failed_awid_count))
  end
  
  if((byte_data_cmp_verified_awaddr_count != 0) && (byte_data_cmp_failed_awaddr_count == 0)) begin
    `uvm_info(get_type_name(), $sformatf("✓ All AWADDR comparisons successful (%0d)", byte_data_cmp_verified_awaddr_count), UVM_LOW)
  end else begin
    `uvm_error("SC_CHECK", $sformatf("✗ AWADDR: Verified=%0d Failed=%0d", 
              byte_data_cmp_verified_awaddr_count, byte_data_cmp_failed_awaddr_count))
  end
  
  // Read channel checks
  if((byte_data_cmp_verified_rdata_count != 0) && (byte_data_cmp_failed_rdata_count == 0)) begin
    `uvm_info(get_type_name(), $sformatf("✓ All RDATA comparisons successful (%0d)", byte_data_cmp_verified_rdata_count), UVM_LOW)
  end else begin
    `uvm_error("SC_CHECK", $sformatf("✗ RDATA: Verified=%0d Failed=%0d", 
              byte_data_cmp_verified_rdata_count, byte_data_cmp_failed_rdata_count))
  end
  
  // Master routing checks
  if((master_routing_verified_count != 0) && (master_routing_failed_count == 0)) begin
    `uvm_info(get_type_name(), $sformatf("✓ All master routing checks successful (%0d)", master_routing_verified_count), UVM_LOW)
  end else begin
    `uvm_error("SC_CHECK", $sformatf("✗ MASTER ROUTING: Verified=%0d Failed=%0d", 
              master_routing_verified_count, master_routing_failed_count))
  end
  
  // LOCK mechanism checks
  if(lock_violations_detected == 0) begin
    `uvm_info(get_type_name(), "✓ No lock violations detected", UVM_LOW)
  end else begin
    `uvm_error("SC_CHECK", $sformatf("✗ LOCK VIOLATIONS: %0d detected", lock_violations_detected))
  end
  
  if(total_locks_acquired == total_locks_released) begin
    `uvm_info(get_type_name(), $sformatf("✓ All locks properly released (acquired=%0d, released=%0d)", 
              total_locks_acquired, total_locks_released), UVM_LOW)
  end else begin
    `uvm_error("SC_CHECK", $sformatf("✗ LOCK IMBALANCE: Acquired=%0d Released=%0d", 
              total_locks_acquired, total_locks_released))
  end
  
  // Check for any active locks at end
  foreach(slave_lock_state[i]) begin
    if(slave_lock_state[i].is_locked) begin
      `uvm_error("SC_CHECK", $sformatf("✗ Slave[%0d] still locked by Master[%0d] at end of simulation", 
                i, slave_lock_state[i].locked_by_master))
    end
  end
  
  // Check pending reads
  if(pendingReads.size() == 0) begin
    `uvm_info("SC_CHECK", "✓ All pending reads completed", UVM_LOW)
  end else begin
    `uvm_error("SC_CHECK", $sformatf("✗ Pending reads not completed: %0d transactions remaining", pendingReads.size()))
  end
  
  `uvm_info(get_type_name(), "========== END CHECK PHASE ==========", UVM_LOW)
  
endfunction : check_phase

function void axi4_scoreboard_approach1_with_lock::report_phase(uvm_phase phase);
  super.report_phase(phase);
  
  `uvm_info("REPORT", "========== AXI4 MULTI-MASTER MULTI-SLAVE SCOREBOARD REPORT ==========", UVM_LOW)
  
  // Per master transaction counts
  `uvm_info("REPORT", "===== PER MASTER TRANSACTION COUNTS =====", UVM_LOW)
  foreach(axi4_master_tx_awaddr_count[i]) begin
    `uvm_info("REPORT", $sformatf("Master[%0d]: WR_ADDR=%0d WR_DATA=%0d WR_RESP=%0d RD_ADDR=%0d RD_DATA=%0d", 
              i, axi4_master_tx_awaddr_count[i], axi4_master_tx_wdata_count[i], 
              axi4_master_tx_bresp_count[i], axi4_master_tx_araddr_count[i], 
              axi4_master_tx_rdata_count[i]), UVM_LOW)
  end
  
  // Per slave transaction counts
  `uvm_info("REPORT", "===== PER SLAVE TRANSACTION COUNTS =====", UVM_LOW)
  foreach(axi4_slave_tx_awaddr_count[i]) begin
    `uvm_info("REPORT", $sformatf("Slave[%0d]: WR_ADDR=%0d WR_DATA=%0d WR_RESP=%0d RD_ADDR=%0d RD_DATA=%0d", 
              i, axi4_slave_tx_awaddr_count[i], axi4_slave_tx_wdata_count[i], 
              axi4_slave_tx_bresp_count[i], axi4_slave_tx_araddr_count[i], 
              axi4_slave_tx_rdata_count[i]), UVM_LOW)
  end
  
  // Write channel comparison results
  `uvm_info("REPORT", "===== WRITE CHANNEL COMPARISON RESULTS =====", UVM_LOW)
  `uvm_info("REPORT", $sformatf("AWID    : Verified=%0d Failed=%0d", byte_data_cmp_verified_awid_count, byte_data_cmp_failed_awid_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("AWADDR  : Verified=%0d Failed=%0d", byte_data_cmp_verified_awaddr_count, byte_data_cmp_failed_awaddr_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("AWLEN   : Verified=%0d Failed=%0d", byte_data_cmp_verified_awlen_count, byte_data_cmp_failed_awlen_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("AWLOCK  : Verified=%0d Failed=%0d", byte_data_cmp_verified_awlock_count, byte_data_cmp_failed_awlock_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("BID     : Verified=%0d Failed=%0d", byte_data_cmp_verified_bid_count, byte_data_cmp_failed_bid_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("BRESP   : Verified=%0d Failed=%0d", byte_data_cmp_verified_bresp_count, byte_data_cmp_failed_bresp_count), UVM_LOW)
  
  // Read channel comparison results
  `uvm_info("REPORT", "===== READ CHANNEL COMPARISON RESULTS =====", UVM_LOW)
  `uvm_info("REPORT", $sformatf("ARID    : Verified=%0d Failed=%0d", byte_data_cmp_verified_arid_count, byte_data_cmp_failed_arid_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("ARADDR  : Verified=%0d Failed=%0d", byte_data_cmp_verified_araddr_count, byte_data_cmp_failed_araddr_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("ARLEN   : Verified=%0d Failed=%0d", byte_data_cmp_verified_arlen_count, byte_data_cmp_failed_arlen_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("ARLOCK  : Verified=%0d Failed=%0d", byte_data_cmp_verified_arlock_count, byte_data_cmp_failed_arlock_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("RID     : Verified=%0d Failed=%0d", byte_data_cmp_verified_rid_count, byte_data_cmp_failed_rid_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("RDATA   : Verified=%0d Failed=%0d", byte_data_cmp_verified_rdata_count, byte_data_cmp_failed_rdata_count), UVM_LOW)
  
  // Master routing results
  `uvm_info("REPORT", "===== MASTER ROUTING VERIFICATION =====", UVM_LOW)
  `uvm_info("REPORT", $sformatf("Routing : Verified=%0d Failed=%0d", master_routing_verified_count, master_routing_failed_count), UVM_LOW)
  
  // LOCK mechanism results
  `uvm_info("REPORT", "===== LOCK MECHANISM VERIFICATION =====", UVM_LOW)
  `uvm_info("REPORT", $sformatf("Total Locks Acquired  : %0d", total_locks_acquired), UVM_LOW)
  `uvm_info("REPORT", $sformatf("Total Locks Released  : %0d", total_locks_released), UVM_LOW)
  `uvm_info("REPORT", $sformatf("Lock Violations       : %0d", lock_violations_detected), UVM_LOW)
  `uvm_info("REPORT", $sformatf("Lock Verify Passed    : %0d", lock_verify_passed), UVM_LOW)
  `uvm_info("REPORT", $sformatf("Lock Verify Failed    : %0d", lock_verify_failed), UVM_LOW)
  
  // Per master-slave lock statistics
  if(lock_statistics.size() > 0) begin
    `uvm_info("REPORT", "===== LOCK STATISTICS PER MASTER-SLAVE PAIR =====", UVM_LOW)
    foreach(lock_statistics[key]) begin
      time avg_duration;
      if(lock_statistics[key].lock_count > 0) begin
        avg_duration = lock_statistics[key].total_lock_duration / lock_statistics[key].lock_count;
      end else begin
        avg_duration = 0;
      end
      `uvm_info("REPORT", $sformatf("%s: Count=%0d, AvgDuration=%0t, MaxDuration=%0t", 
                key, lock_statistics[key].lock_count, avg_duration, 
                lock_statistics[key].max_lock_duration), UVM_LOW)
    end
  end
  
  `uvm_info("REPORT", "===== SUMMARY =====", UVM_LOW)
  `uvm_info("REPORT", $sformatf("Total Master Transactions : %0d", total_master_tx_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("Total Slave Transactions  : %0d", total_slave_tx_count), UVM_LOW)
  
  if(nonExistantMemRead > 0) begin
    `uvm_info("REPORT", $sformatf("Non-existent memory reads : %0d", nonExistantMemRead), UVM_LOW)
  end
  
  `uvm_info("REPORT", "========== END SCOREBOARD REPORT ==========", UVM_LOW)
  
endfunction : report_phase

`endif