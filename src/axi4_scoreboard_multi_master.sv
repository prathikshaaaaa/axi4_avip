`ifndef AXI4_SCOREBOARD_APPROACH1_INCLUDED_
`define AXI4_SCOREBOARD_APPROACH1_INCLUDED_

class axi4_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi4_scoreboard)

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

  bit[ADDR_WIDTH-1:0] SLAVE_START_ADDR[];
  bit[ADDR_WIDTH-1:0] SLAVE_END_ADDR[];

  int nonExistantMemRead;

  axi4_env_config axi4_env_cfg_h;
  axi4_slave_agent_config axi4_slave_agent_cfg_h[];

  extern function new(string name = "axi4_scoreboard", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);
  extern virtual function int get_slave_index(logic[ADDR_WIDTH-1:0] addr);
  extern virtual function void ref_model_write(axi4_master_tx m_tx, int slave_idx, int master_idx);
  extern virtual function void ref_model_read(axi4_master_tx m_tx, int slave_idx);
  extern virtual task axi4_write_address_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id);
  extern virtual task axi4_read_address_comparison(input axi4_master_tx exp_tx, input axi4_slave_tx act_tx, input int master_id);
  extern virtual function void check_phase (uvm_phase phase);
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
  
  //arrays for masters
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
  
  //arrays for slaves
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

function void axi4_scoreboard::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase

// Function: get_slave_index
function int axi4_scoreboard::get_slave_index(logic[ADDR_WIDTH-1:0] addr);
  for(int i = 0; i < NO_OF_SLAVES; i++) begin
    if(addr >= SLAVE_START_ADDR[i] && addr <= SLAVE_END_ADDR[i]) begin
      return i;
    end
  end
  return -1;
endfunction : get_slave_index

// Function: ref_model_write
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

// Function: ref_model_read
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

task axi4_scoreboard::run_phase(uvm_phase phase);
  super.run_phase(phase);
  
  //master - Write Address Path
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

   // master - Read Address Path
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

endtask : run_phase

function void axi4_scoreboard::check_phase(uvm_phase phase);
  super.check_phase(phase);
endfunction : check_phase

function void axi4_scoreboard::report_phase(uvm_phase phase);
  super.report_phase(phase);
endfunction : report_phase

`endif