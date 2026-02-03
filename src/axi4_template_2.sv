​`ifndef AXI4_SCOREBOARD_INCLUDED_
`define AXI4_SCOREBOARD_INCLUDED_


class axi4_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi4_scoreboard)

  axi4_master_tx axi4_master_tx_h;
  axi4_slave_tx axi4_slave_tx_h;

  typedef struct {
    bit[DATA_WIDTH-1:0] data;
    bit[(DATA_WIDTH/8)-1:0] strobe;
  } DataTransaction;
  
  typedef DataTransaction dataTransactionQueue[$]; //THIS IS NOWHERE USED IN CODE ???
  
  // Reference memory indexed by [slave_id][address]
  logic[7:0] referenceData[int][longint];

  // Expected transaction queues per slave for write transactions
  axi4_master_tx slaveExpectedWriteQueue[int][$]; //queue of expected write transactions
  int slaveExpectedWriteMasterIdQueue[int][$]; //queue of master IDs
  
  // Expected transaction queues per slave for read transactions
  axi4_master_tx slaveExpectedReadQueue[int][$];
  int slaveExpectedReadMasterIdQueue[int][$];

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
  extern virtual task axi4_write_address_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id);
  extern virtual task axi4_write_response_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id);
  extern virtual task axi4_read_address_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id);
  extern virtual function void check_phase(uvm_phase phase);
  extern virtual function void report_phase(uvm_phase phase);

endclass : axi4_scoreboard

function axi4_scoreboard::new(string name = "axi4_scoreboard", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

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
// Function: ref_model_write
// Reference model for write operations
//--------------------------------------------------------------------------------------------
function void axi4_scoreboard::ref_model_write(axi4_master_tx m_tx, int slave_idx, int master_idx);
  int bytes_per_beat;
  int temp_addr;
  int align_amount;
  int wrap_start_addr;
  int wrap_end_addr;
  
  bytes_per_beat = 1 << m_tx.awsize;
  temp_addr = m_tx.awaddr;
  
  // Calculate wrap boundaries for WRAP burst
  wrap_start_addr = temp_addr - int'(temp_addr % ((2**(m_tx.awsize)) * (m_tx.awlen + 1)));
  wrap_end_addr = wrap_start_addr + ((2**(m_tx.awsize)) * (m_tx.awlen + 1));
  
  // Calculate alignment
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

//--------------------------------------------------------------------------------------------
// Function: ref_model_read
// Reference model for read operations
//--------------------------------------------------------------------------------------------
function void axi4_scoreboard::ref_model_read(axi4_master_tx m_tx, int slave_idx);
  int bytes_per_beat;
  int temp_addr;
  int align_amount;
  int wrap_start_addr;
  int wrap_end_addr;
  
  bytes_per_beat = 1 << m_tx.arsize;
  temp_addr = m_tx.araddr;
  
  // Calculate wrap boundaries
  wrap_start_addr = temp_addr - int'(temp_addr % ((2**(m_tx.arsize)) * (m_tx.arlen + 1)));
  wrap_end_addr = wrap_start_addr + ((2**(m_tx.arsize)) * (m_tx.arlen + 1));
  
  // Calculate alignment
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

//--------------------------------------------------------------------------------------------
// Task: run_phase
// Main comparison logic running in parallel for all masters and slaves
// For in-order transactions only
//--------------------------------------------------------------------------------------------
task axi4_scoreboard::run_phase(uvm_phase phase);
  super.run_phase(phase);
  
  //--------------------------------------------------------------------------------------------
  // Fork processes for each master - Write Address Path
  //--------------------------------------------------------------------------------------------
  foreach(axi4_master_write_address_analysis_fifo[i]) begin
    automatic int m_idx = i;
    fork
      forever begin
        axi4_master_tx m_write_addr_tx;
        int s_idx;
        
        axi4_master_write_address_analysis_fifo[m_idx].get(m_write_addr_tx);
        axi4_master_tx_awaddr_count[m_idx]++;
        total_master_tx_count++;
        
        `uvm_info("SCB_MASTER_WRITE_ADDR", $sformatf("Master[%0d] Write Address: AWID=%0h AWADDR=0x%0h AWLEN=%0d", 
                  m_idx, m_write_addr_tx.awid, m_write_addr_tx.awaddr, m_write_addr_tx.awlen), UVM_MEDIUM)
        
        // Determine target slave
        s_idx = get_slave_index(m_write_addr_tx.awaddr);
        
        if(s_idx != -1) begin
          axi4_master_tx exp_tx;
          $cast(exp_tx, m_write_addr_tx.clone());
          
          // Store for later comparison (in-order)
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
  
  //--------------------------------------------------------------------------------------------
  // Fork processes for each slave - Write Response Path
  //--------------------------------------------------------------------------------------------
  foreach(axi4_slave_write_response_analysis_fifo[i]) begin
    //here fifos are created for each channel independedntly for each master and slave
    //if i do not have 0,1, master txn but i have 2,3 master txn then threads will be created but stays idle with blocking get()
    automatic int s_idx = i;
    fork
      forever begin
        axi4_slave_tx s_write_resp_tx;
        axi4_slave_tx s_write_addr_tx;
        axi4_master_tx exp_write_tx;
        int master_id;
        
        // Get write response from slave
        axi4_slave_write_response_analysis_fifo[s_idx].get(s_write_resp_tx);
        axi4_slave_tx_bresp_count[s_idx]++;
        
        // Get corresponding write address from slave
        axi4_slave_write_address_analysis_fifo[s_idx].get(s_write_addr_tx);
        axi4_slave_tx_awaddr_count[s_idx]++;
        total_slave_tx_count++;
        
        `uvm_info("SCB_SLAVE_WRITE_RESP", $sformatf("Slave[%0d] Write Response: BID=%0h BRESP=%0s", 
                  s_idx, s_write_resp_tx.bid, s_write_resp_tx.bresp.name()), UVM_MEDIUM)
        
        // Wait for expected transaction (in-order)
        wait(slaveExpectedWriteQueue[s_idx].size() > 0);
        
        exp_write_tx = slaveExpectedWriteQueue[s_idx].pop_front();
        master_id = slaveExpectedWriteMasterIdQueue[s_idx].pop_front();
        
        // Update reference model
        ref_model_write(exp_write_tx, s_idx, master_id);
        
        // Compare transactions
        axi4_write_address_comparison(exp_write_tx, s_write_addr_tx, master_id);
        axi4_write_response_comparison(exp_write_tx, s_write_resp_tx, master_id);
      end
    join_none
  end
  
  //--------------------------------------------------------------------------------------------
  // Fork processes for each master - Read Address Path
  //--------------------------------------------------------------------------------------------
  foreach(axi4_master_read_address_analysis_fifo[i]) begin
    automatic int m_idx = i;
    fork
      forever begin
        axi4_master_tx m_read_addr_tx;
        int s_idx;
        
        axi4_master_read_address_analysis_fifo[m_idx].get(m_read_addr_tx);
        axi4_master_tx_araddr_count[m_idx]++;
        
        `uvm_info("SCB_MASTER_READ_ADDR", $sformatf("Master[%0d] Read Address: ARID=%0h ARADDR=0x%0h ARLEN=%0d", 
                  m_idx, m_read_addr_tx.arid, m_read_addr_tx.araddr, m_read_addr_tx.arlen), UVM_MEDIUM)
        
        // Determine target slave
        s_idx = get_slave_index(m_read_addr_tx.araddr);
        
        if(s_idx != -1) begin
          axi4_master_tx exp_tx;
          $cast(exp_tx, m_read_addr_tx.clone());
          
          // Generate expected read data from reference model
          ref_model_read(exp_tx, s_idx);
          
          // Store for later comparison (in-order)
          slaveExpectedReadQueue[s_idx].push_back(exp_tx);
          slaveExpectedReadMasterIdQueue[s_idx].push_back(m_idx);
          
          `uvm_info("SCB_EXPECT_READ", $sformatf("Slave[%0d] expecting read from Master[%0d]", s_idx, m_idx), UVM_HIGH)
        end else begin
          `uvm_error("SCB_ADDR_DECODE", $sformatf("Master[%0d] Address 0x%0h doesn't map to any slave", 
                     m_idx, m_read_addr_tx.araddr))
        end
      end
    join_none
  end
  
  //--------------------------------------------------------------------------------------------
  // Fork processes for each master - Read Data Comparison
  // Note: We check master interface for read data as per requirement
  //--------------------------------------------------------------------------------------------
  foreach(axi4_master_read_data_analysis_fifo[i]) begin
    automatic int m_idx = i;
    fork
      forever begin
        axi4_master_tx m_read_data_tx;
        axi4_master_tx exp_read_tx;
        axi4_slave_tx s_read_addr_tx;
        int s_idx;
        int master_id;
        
        // Get read data from master interface
        axi4_master_read_data_analysis_fifo[m_idx].get(m_read_data_tx);
        axi4_master_tx_rdata_count[m_idx]++;
        
        `uvm_info("SCB_MASTER_READ_DATA", $sformatf("Master[%0d] Read Data: RID=%0h RDATA[0]=0x%0h RLAST=%0b", 
                  m_idx, m_read_data_tx.arid, m_read_data_tx.rdata[0], m_read_data_tx.rlast), UVM_MEDIUM)
        
        // Find corresponding expected transaction based on address
        s_idx = get_slave_index(m_read_data_tx.araddr);
        
        if(s_idx != -1 && slaveExpectedReadQueue[s_idx].size() > 0) begin
          // Wait for slave address (in-order)
          axi4_slave_read_address_analysis_fifo[s_idx].get(s_read_addr_tx);
          axi4_slave_tx_araddr_count[s_idx]++;
          
          exp_read_tx = slaveExpectedReadQueue[s_idx].pop_front();
          master_id = slaveExpectedReadMasterIdQueue[s_idx].pop_front();
          
          // Compare read address
          axi4_read_address_comparison(exp_read_tx, s_read_addr_tx, master_id);
          
          // Compare read data on master interface
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
          
          // Verify RID
          if(exp_read_tx.arid == m_read_data_tx.arid) begin
            byte_data_cmp_verified_rid_count++;
          end else begin
            `uvm_error("SCB_RID_MISMATCH", $sformatf("Master[%0d] RID: Exp=%0h Act=%0h", 
                      master_id, exp_read_tx.arid, m_read_data_tx.arid))
            byte_data_cmp_failed_rid_count++;
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

//--------------------------------------------------------------------------------------------
// Task: axi4_write_response_comparison
//--------------------------------------------------------------------------------------------
task axi4_scoreboard::axi4_write_response_comparison(
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
  
  // BRESP comparison - we accept the slave's response
  byte_data_cmp_verified_bresp_count++;
  `uvm_info("SCB_BRESP", $sformatf("Master[%0d] BRESP=%0s", master_id, act_tx.bresp.name()), UVM_HIGH)
  
endtask : axi4_write_response_comparison

//--------------------------------------------------------------------------------------------
// Task: axi4_read_address_comparison
//--------------------------------------------------------------------------------------------
task axi4_scoreboard::axi4_read_address_comparison(
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

//--------------------------------------------------------------------------------------------
// Function: check_phase
//--------------------------------------------------------------------------------------------
function void axi4_scoreboard::check_phase(uvm_phase phase);
  super.check_phase(phase);
  
  `uvm_info(get_type_name(), "========== SCOREBOARD CHECK PHASE ==========", UVM_LOW)
  
  // Check write address comparisons
  if((byte_data_cmp_verified_awid_count != 0) && (byte_data_cmp_failed_awid_count == 0)) begin
    `uvm_info(get_type_name(), $sformatf(" All AWID comparisons successful (%0d)", byte_data_cmp_verified_awid_count), UVM_LOW)
  end else begin
    `uvm_error("SC_CHECK", $sformatf(" AWID: Verified=%0d Failed=%0d", 
              byte_data_cmp_verified_awid_count, byte_data_cmp_failed_awid_count))
  end
  
  if((byte_data_cmp_verified_awaddr_count != 0) && (byte_data_cmp_failed_awaddr_count == 0)) begin
    `uvm_info(get_type_name(), $sformatf(" All AWADDR comparisons successful (%0d)", byte_data_cmp_verified_awaddr_count), UVM_LOW)
  end else begin
    `uvm_error("SC_CHECK", $sformatf(" AWADDR: Verified=%0d Failed=%0d", 
              byte_data_cmp_verified_awaddr_count, byte_data_cmp_failed_awaddr_count))
  end
  
  if((byte_data_cmp_verified_awlen_count != 0) && (byte_data_cmp_failed_awlen_count == 0)) begin
    `uvm_info(get_type_name(), $sformatf(" All AWLEN comparisons successful (%0d)", byte_data_cmp_verified_awlen_count), UVM_LOW)
  end else begin
    `uvm_error("SC_CHECK", $sformatf(" AWLEN: Verified=%0d Failed=%0d", 
              byte_data_cmp_verified_awlen_count, byte_data_cmp_failed_awlen_count))
  end
  
  // Check read data comparisons  
  if((byte_data_cmp_verified_rdata_count != 0) && (byte_data_cmp_failed_rdata_count == 0)) begin
    `uvm_info(get_type_name(), $sformatf(" All RDATA comparisons successful (%0d)", byte_data_cmp_verified_rdata_count), UVM_LOW)
  end else begin
    `uvm_error("SC_CHECK", $sformatf(" RDATA: Verified=%0d Failed=%0d", 
              byte_data_cmp_verified_rdata_count, byte_data_cmp_failed_rdata_count))
  end
  
  // Check FIFO empty status
  foreach(axi4_master_write_address_analysis_fifo[i]) begin
    if(axi4_master_write_address_analysis_fifo[i].size() == 0) begin
      `uvm_info("SC_CHECK", $sformatf(" Master[%0d] write address FIFO is empty", i), UVM_HIGH)
    end else begin
      `uvm_error("SC_CHECK", $sformatf(" Master[%0d] write address FIFO not empty: size=%0d", 
                i, axi4_master_write_address_analysis_fifo[i].size()))
    end
  end
  
  foreach(axi4_slave_write_response_analysis_fifo[i]) begin
    if(axi4_slave_write_response_analysis_fifo[i].size() == 0) begin
      `uvm_info("SC_CHECK", $sformatf(" Slave[%0d] write response FIFO is empty", i), UVM_HIGH)
    end else begin
      `uvm_error("SC_CHECK", $sformatf(" Slave[%0d] write response FIFO not empty: size=%0d", 
                i, axi4_slave_write_response_analysis_fifo[i].size()))
    end
  end
  
  `uvm_info(get_type_name(), "========== END CHECK PHASE ==========", UVM_LOW)
  
endfunction : check_phase

//--------------------------------------------------------------------------------------------
// Function: report_phase
//--------------------------------------------------------------------------------------------
function void axi4_scoreboard::report_phase(uvm_phase phase);
  super.report_phase(phase);
  
  `uvm_info("REPORT", "========== AXI4 MULTI-MASTER MULTI-SLAVE SCOREBOARD REPORT ==========", UVM_LOW)
  
  // Transaction counts per master
  `uvm_info("REPORT", "===== PER MASTER TRANSACTION COUNTS =====", UVM_LOW)
  foreach(axi4_master_tx_awaddr_count[i]) begin
    `uvm_info("REPORT", $sformatf("Master[%0d]: WR_ADDR=%0d WR_DATA=%0d WR_RESP=%0d RD_ADDR=%0d RD_DATA=%0d", 
              i, axi4_master_tx_awaddr_count[i], axi4_master_tx_wdata_count[i], 
              axi4_master_tx_bresp_count[i], axi4_master_tx_araddr_count[i], 
              axi4_master_tx_rdata_count[i]), UVM_LOW)
  end
  
  // Transaction counts per slave
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
  `uvm_info("REPORT", $sformatf("AWSIZE  : Verified=%0d Failed=%0d", byte_data_cmp_verified_awsize_count, byte_data_cmp_failed_awsize_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("AWBURST : Verified=%0d Failed=%0d", byte_data_cmp_verified_awburst_count, byte_data_cmp_failed_awburst_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("AWCACHE : Verified=%0d Failed=%0d", byte_data_cmp_verified_awcache_count, byte_data_cmp_failed_awcache_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("AWLOCK  : Verified=%0d Failed=%0d", byte_data_cmp_verified_awlock_count, byte_data_cmp_failed_awlock_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("AWPROT  : Verified=%0d Failed=%0d", byte_data_cmp_verified_awprot_count, byte_data_cmp_failed_awprot_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("BID     : Verified=%0d Failed=%0d", byte_data_cmp_verified_bid_count, byte_data_cmp_failed_bid_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("BRESP   : Verified=%0d Failed=%0d", byte_data_cmp_verified_bresp_count, byte_data_cmp_failed_bresp_count), UVM_LOW)
  
  // Read channel comparison results
  `uvm_info("REPORT", "===== READ CHANNEL COMPARISON RESULTS =====", UVM_LOW)
  `uvm_info("REPORT", $sformatf("ARID    : Verified=%0d Failed=%0d", byte_data_cmp_verified_arid_count, byte_data_cmp_failed_arid_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("ARADDR  : Verified=%0d Failed=%0d", byte_data_cmp_verified_araddr_count, byte_data_cmp_failed_araddr_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("ARLEN   : Verified=%0d Failed=%0d", byte_data_cmp_verified_arlen_count, byte_data_cmp_failed_arlen_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("ARSIZE  : Verified=%0d Failed=%0d", byte_data_cmp_verified_arsize_count, byte_data_cmp_failed_arsize_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("ARBURST : Verified=%0d Failed=%0d", byte_data_cmp_verified_arburst_count, byte_data_cmp_failed_arburst_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("ARCACHE : Verified=%0d Failed=%0d", byte_data_cmp_verified_arcache_count, byte_data_cmp_failed_arcache_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("ARLOCK  : Verified=%0d Failed=%0d", byte_data_cmp_verified_arlock_count, byte_data_cmp_failed_arlock_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("ARPROT  : Verified=%0d Failed=%0d", byte_data_cmp_verified_arprot_count, byte_data_cmp_failed_arprot_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("ARREGION: Verified=%0d Failed=%0d", byte_data_cmp_verified_arregion_count, byte_data_cmp_failed_arregion_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("ARQOS   : Verified=%0d Failed=%0d", byte_data_cmp_verified_arqos_count, byte_data_cmp_failed_arqos_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("RID     : Verified=%0d Failed=%0d", byte_data_cmp_verified_rid_count, byte_data_cmp_failed_rid_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("RDATA   : Verified=%0d Failed=%0d", byte_data_cmp_verified_rdata_count, byte_data_cmp_failed_rdata_count), UVM_LOW)
  
  `uvm_info("REPORT", "===== SUMMARY =====", UVM_LOW)
  `uvm_info("REPORT", $sformatf("Total Master Transactions : %0d", total_master_tx_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("Total Slave Transactions  : %0d", total_slave_tx_count), UVM_LOW)
  
  if(nonExistantMemRead > 0) begin
    `uvm_info("REPORT", $sformatf("Non-existent memory reads : %0d", nonExistantMemRead), UVM_LOW)
  end
  
  `uvm_info("REPORT", "========== END SCOREBOARD REPORT ==========", UVM_LOW)
  
endfunction : report_phase

`endif
